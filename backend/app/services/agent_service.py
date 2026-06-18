from __future__ import annotations

import time
from concurrent.futures import ThreadPoolExecutor, wait
from dataclasses import dataclass
from typing import List, Optional

from app.schemas import AgentSession
from app.services.ai_service import AiProviderError, call_chat_completions, load_ai_config
from app.storage import AppStore


@dataclass(frozen=True)
class ResearchRole:
    key: str
    name: str
    round_number: int
    context_note: str
    system_prompt: str


ROUND_ONE_ROLES: List[ResearchRole] = [
    ResearchRole(
        key="mentor",
        name="导师",
        round_number=1,
        context_note="基于初始问题",
        system_prompt=(
            "你是一位科研导师，请用中文给出方向判断。重点回答：这个问题是否值得继续做、研究问题如何收窄、"
            "最应该优先验证什么、哪些地方需要和导师确认。语气像真实组会里的导师，直接、具体、克制。"
        ),
    ),
    ResearchRole(
        key="reviewer",
        name="评审老师",
        round_number=1,
        context_note="基于初始问题",
        system_prompt=(
            "你是一位严格但建设性的论文评审。请指出实验漏洞、baseline 缺失、证据不足、评价指标风险和可能被追问的问题。"
            "不要泛泛而谈，要给出可执行的补强建议。"
        ),
    ),
    ResearchRole(
        key="experiment",
        name="实验设计",
        round_number=1,
        context_note="基于初始问题",
        system_prompt=(
            "你负责实验方案设计。请给出变量、对照组、实验步骤、评估指标、失败风险和最小可行验证路径。"
            "如果信息不足，请明确哪些条件需要补充。"
        ),
    ),
    ResearchRole(
        key="literature",
        name="文献整理",
        round_number=1,
        context_note="基于初始问题",
        system_prompt=(
            "你负责文献视角。请指出需要补充的研究背景、相近方法、对比维度、检索关键词和阅读顺序。"
            "不要编造具体论文题名、DOI 或实验数据。"
        ),
    ),
]

ROUND_TWO_ROLES: List[ResearchRole] = [
    ResearchRole(
        key="review_followup",
        name="评审补充",
        round_number=2,
        context_note="已参考前一轮意见",
        system_prompt=(
            "你是一位论文评审，请阅读前一轮组会意见，补充最关键的 3 到 5 个风险点和对应补救实验。"
            "避免重复前文，重点做交叉修正。"
        ),
    ),
    ResearchRole(
        key="editor",
        name="写作编辑",
        round_number=2,
        context_note="已参考前一轮意见",
        system_prompt=(
            "你负责把组会讨论整理成科研日报或组会汇报表达。请输出：标题建议、摘要、正文结构、标签建议、发布前检查。"
            "表达要自然，适合科研日报社区。"
        ),
    ),
]

COORDINATOR_ROLE = ResearchRole(
    key="coordinator",
    name="主持总结",
    round_number=3,
    context_note="综合已完成意见",
    system_prompt=(
        "你是本次多角色组会的主持人。请综合已经完成的意见，给用户一个清晰结论。"
        "不要使用 Agent、模型、线程、超时等工程词。"
        "如果有人本轮暂未完成，请用用户能理解的方式轻描淡写说明，例如："
        "“有部分视角暂时还在整理，先基于已完成意见给出结论。”"
        "输出结构：总体判断、最值得做的一步、需要补强的证据、下一篇日报可以怎么写。"
    ),
)


class AgentCoordinator:
    def __init__(self, store: AppStore) -> None:
        self.store = store
        self.executor = ThreadPoolExecutor(max_workers=8)

    def start_session(self, session: AgentSession) -> None:
        self.executor.submit(self._run_session, session.id)

    def continue_session(self, session_id: str) -> None:
        self.executor.submit(self._run_followup, session_id)

    def _run_session(self, session_id: str) -> None:
        try:
            if not self.store.update_agent_session_status(
                session_id,
                "running",
                current_round=1,
                memory_version=1,
                expected_status="running",
            ):
                return
            round_one_context = self._snapshot_context(session_id, version=1, max_round=0, created_by="round_one")
            round_one_futures = []
            for role in ROUND_ONE_ROLES:
                future = self.executor.submit(self._run_role, session_id, role, round_one_context, 1)
                future.research_role = role
                round_one_futures.append(future)
            done, not_done = wait(round_one_futures, timeout=90)
            self._mark_unfinished(session_id, not_done, 1)

            if not self.store.update_agent_session_status(
                session_id,
                "running",
                current_round=2,
                memory_version=2,
                expected_memory_version=1,
                expected_status="running",
            ):
                return
            round_two_context = self._snapshot_context(session_id, version=2, max_round=1, created_by="round_two")
            round_two_futures = []
            for role in ROUND_TWO_ROLES:
                future = self.executor.submit(self._run_role, session_id, role, round_two_context, 2)
                future.research_role = role
                round_two_futures.append(future)
            done_two, not_done_two = wait(round_two_futures, timeout=90)
            self._mark_unfinished(session_id, not_done_two, 2)

            if not self.store.update_agent_session_status(
                session_id,
                "running",
                current_round=3,
                memory_version=3,
                expected_memory_version=2,
                expected_status="running",
            ):
                return
            round_three_context = self._snapshot_context(session_id, version=3, max_round=2, created_by="coordinator")
            self._run_role(session_id, COORDINATOR_ROLE, round_three_context, 3)

            self._finish_session(
                session_id,
                current_round=3,
                memory_version=4,
                expected_memory_version=3,
                min_context_version=1,
            )
        except Exception as exc:
            self.store.create_agent_message(
                session_id=session_id,
                agent_key="system",
                agent_name="系统提示",
                role="system",
                round_number=3,
                context_version=3,
                content=f"本次组会整理时遇到问题：{exc}",
                status="error",
            )
            self.store.update_agent_session_status(session_id, "failed", current_round=3)

    def _run_followup(self, session_id: str) -> None:
        try:
            session = self.store.get_agent_session_for_system(session_id)
            start_round = max(1, session.current_round)
            base_version = max(1, session.memory_version)
            if not self.store.update_agent_session_status(
                session_id,
                "running",
                current_round=start_round,
                memory_version=base_version,
                expected_memory_version=base_version,
                expected_status="running",
            ):
                return
            followup_context = self._snapshot_context(
                session_id,
                version=base_version,
                max_round=start_round,
                created_by="followup",
            )
            futures = []
            for role in ROUND_ONE_ROLES:
                future = self.executor.submit(self._run_role, session_id, role, followup_context, base_version, start_round)
                future.research_role = role
                futures.append(future)
            done, not_done = wait(futures, timeout=90)
            self._mark_unfinished(session_id, not_done, base_version)

            summary_version = base_version + 1
            summary_round = start_round + 1
            if not self.store.update_agent_session_status(
                session_id,
                "running",
                current_round=summary_round,
                memory_version=summary_version,
                expected_memory_version=base_version,
                expected_status="running",
            ):
                return
            summary_context = self._snapshot_context(
                session_id,
                version=summary_version,
                max_round=summary_round,
                created_by="followup_summary",
            )
            self._run_role(session_id, COORDINATOR_ROLE, summary_context, summary_version, summary_round)
            self._finish_session(
                session_id,
                summary_round,
                summary_version + 1,
                expected_memory_version=summary_version,
                min_context_version=base_version,
            )
        except Exception as exc:
            self.store.create_agent_message(
                session_id=session_id,
                agent_key="system",
                agent_name="系统提示",
                role="system",
                round_number=0,
                context_version=0,
                content=f"本次追问整理时遇到问题：{exc}",
                status="error",
            )
            self.store.update_agent_session_status(session_id, "failed")

    def _finish_session(
        self,
        session_id: str,
        current_round: int,
        memory_version: int,
        expected_memory_version: Optional[int],
        min_context_version: int,
    ) -> None:
        messages = self.store.list_agent_messages_for_session(session_id)
        failed = [
            item for item in messages
            if item.status in ["timeout", "error"] and item.role in ["assistant", "agent", "coordinator"]
            and item.context_version_started >= min_context_version
        ]
        unfinished = [
            item for item in messages
            if item.status in ["pending", "running"] and item.role in ["assistant", "agent", "coordinator"]
            and item.context_version_started >= min_context_version
        ]
        self.store.update_agent_session_status(
            session_id,
            "partial" if failed or unfinished else "completed",
            current_round=current_round,
            memory_version=memory_version,
            expected_memory_version=expected_memory_version,
        )

    def _run_role(
        self,
        session_id: str,
        role: ResearchRole,
        context: str,
        context_version: int,
        round_number: Optional[int] = None,
    ) -> None:
        message_round = round_number if round_number is not None else role.round_number
        try:
            message = self.store.create_agent_message(
                session_id=session_id,
                agent_key=role.key,
                agent_name=role.name,
                role="coordinator" if role.key == "coordinator" else "agent",
                round_number=message_round,
                context_version=context_version,
                content="",
                status="pending",
                expected_memory_version=context_version,
            )
        except ValueError:
            return
        self.store.mark_agent_message_running(message.id)
        try:
            answer = self._ask_role(role, self._build_context(context, role, context_version), context_version)
            self.store.complete_agent_message(message.id, answer, "done")
        except AiProviderError as exc:
            self.store.complete_agent_message(message.id, self._friendly_failure(role, str(exc)), "error")
        except Exception as exc:
            self.store.complete_agent_message(message.id, self._friendly_failure(role, str(exc)), "error")

    def _mark_unfinished(self, session_id: str, futures, context_version: int) -> None:
        role_keys: List[str] = []
        for future in futures:
            if future.done():
                continue
            role = getattr(future, "research_role", None)
            if isinstance(role, ResearchRole):
                role_keys.append(role.key)
            # The running HTTP request cannot be forcibly stopped safely, but late writes are ignored.
            time.sleep(0)
        self.store.mark_unfinished_agent_messages(session_id, role_keys, context_version=context_version)

    def _ask_role(self, role: ResearchRole, context: str, context_version: int) -> str:
        cfg = load_ai_config()
        length_rule = (
            "请精确简洁：总字数控制在 180 到 280 字，最多 4 个短段落或 4 条要点。"
            if role.key == "coordinator"
            else "请精确简洁：总字数控制在 120 到 220 字，最多 3 条要点。"
        )
        context_note = role.context_note if context_version <= 1 else "已参考本次组会前文和最新追问"
        payload = {
            "model": cfg.model,
            "messages": [
                {
                    "role": "system",
                    "content": (
                        f"{role.system_prompt}\n"
                        f"当前发言位置：{context_note}。\n"
                        f"{length_rule}"
                        "直接给可执行判断，不写客套话，不复述用户问题，不展开背景科普。"
                    ),
                },
                {
                    "role": "user",
                    "content": context,
                },
            ],
            "temperature": 0.45,
        }
        return call_chat_completions(cfg, payload)

    def _snapshot_context(self, session_id: str, version: int, max_round: int, created_by: str) -> str:
        return self.store.snapshot_agent_context(session_id, version, max_round, created_by)

    def _build_context(self, base_context: str, role: ResearchRole, context_version: int) -> str:
        if role.round_number <= 1 and context_version <= 1:
            return (
                f"{base_context}\n\n"
                "请先给出你的独立判断，不需要等待其他角色。"
            )
        if role.key != "coordinator" and context_version > 1:
            return (
                f"{base_context}\n\n"
                "请在前文基础上回应用户最新追问，优先补充新增判断，避免重复已经说过的内容。"
            )
        return (
            f"{base_context}\n\n"
            f"请以“{role.context_note}”为前提继续补充。"
        )

    def _friendly_failure(self, role: ResearchRole, detail: str) -> str:
        compact = " ".join(detail.split())[:120]
        if role.key == "coordinator":
            return "主持总结暂时没有整理完成，请稍后刷新；前面已经完成的意见可以先作为本次讨论依据。"
        if compact:
            return f"{role.name}这一轮暂时没有整理完成，可以先参考其他已完成意见。原因：{compact}"
        return f"{role.name}这一轮暂时没有整理完成，可以先参考其他已完成意见。"
