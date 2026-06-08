from __future__ import annotations

import os
from pathlib import Path
from typing import Dict, List, Optional

import requests


MODE_TITLES: Dict[str, str] = {
    "paper": "论文速读",
    "topic": "选题建议",
    "experiment": "实验设计",
    "compare": "文献对比",
    "reproduce": "复现计划",
    "meeting": "组会汇报",
    "review": "审稿式提问",
    "qa": "科研问答",
}

MODE_TASKS: Dict[str, str] = {
    "paper": "输入可能是论文标题、DOI、PDF 链接或摘要。请生成研究问题、核心方法、数据与实验、主要结论、局限风险、对我的科研日报启发。",
    "topic": "输入是研究方向。请生成可做课题、创新点、数据需求、难度评估、预期产出。",
    "experiment": "输入是研究目标或实验假设。请生成实验方案、变量、对照组、评估指标、失败风险。",
    "compare": "输入是多篇论文或多个方法。请对比方法路线、数据集、指标、优点、缺点、适用条件。",
    "reproduce": "输入是论文或想法。请拆成复现目标、环境依赖、数据准备、执行步骤、评估方式、风险排查。",
    "meeting": "输入是本周记录。请生成本周进展、主要问题、下周计划、需要导师拍板的事项、可展示材料。",
    "review": "输入是论文想法、实验结论或草稿。请模拟 reviewer，指出实验漏洞、baseline 缺失、证据不足、泛化风险和必须补的实验。",
    "qa": "输入是自由科研问题。请围绕方法、指标、实验设计或论文写作给出直接回答、判断依据和下一步动作。",
}


class AiProviderError(RuntimeError):
    pass


class AiConfig:
    def __init__(self, api_key: str, base_url: str, model: str, timeout_seconds: int) -> None:
        self.api_key = api_key
        self.base_url = base_url
        self.model = model
        self.timeout_seconds = timeout_seconds


def ai_mode_title(mode: str) -> str:
    if mode not in MODE_TITLES:
        raise ValueError("不支持的 AI 工作台类型。")
    return MODE_TITLES[mode]


def generate_workbench_answer(mode: str, prompt: str, history: Optional[List[Dict[str, str]]] = None) -> str:
    title = ai_mode_title(mode)
    cfg = load_ai_config()
    payload = build_chat_payload(mode, title, prompt, cfg.model, history or [])
    return call_chat_completions(cfg, payload)


def load_ai_config() -> AiConfig:
    load_dotenv_file()

    timeout_seconds = int(os.getenv("AI_TIMEOUT_SECONDS", "60"))
    if os.getenv("DEEPSEEK_API_KEY", "").strip():
        return AiConfig(
            api_key=os.getenv("DEEPSEEK_API_KEY", "").strip(),
            base_url=os.getenv("DEEPSEEK_BASE_URL", "https://api.deepseek.com/v1").strip(),
            model=os.getenv("DEEPSEEK_MODEL", os.getenv("AI_MODEL", "deepseek-chat")).strip(),
            timeout_seconds=timeout_seconds,
        )
    if os.getenv("OPENAI_API_KEY", "").strip():
        return AiConfig(
            api_key=os.getenv("OPENAI_API_KEY", "").strip(),
            base_url=os.getenv("OPENAI_BASE_URL", os.getenv("AI_BASE_URL", "https://api.openai.com/v1")).strip(),
            model=os.getenv("OPENAI_MODEL", os.getenv("AI_MODEL", "gpt-4o-mini")).strip(),
            timeout_seconds=timeout_seconds,
        )
    if os.getenv("DASHSCOPE_API_KEY", "").strip():
        return AiConfig(
            api_key=os.getenv("DASHSCOPE_API_KEY", "").strip(),
            base_url=os.getenv("DASHSCOPE_BASE_URL", "https://dashscope.aliyuncs.com/compatible-mode/v1").strip(),
            model=os.getenv("DASHSCOPE_MODEL", os.getenv("AI_MODEL", "qwen-plus")).strip(),
            timeout_seconds=timeout_seconds,
        )
    if os.getenv("MOONSHOT_API_KEY", "").strip():
        return AiConfig(
            api_key=os.getenv("MOONSHOT_API_KEY", "").strip(),
            base_url=os.getenv("MOONSHOT_BASE_URL", "https://api.moonshot.cn/v1").strip(),
            model=os.getenv("MOONSHOT_MODEL", os.getenv("AI_MODEL", "moonshot-v1-8k")).strip(),
            timeout_seconds=timeout_seconds,
        )
    if os.getenv("SILICONFLOW_API_KEY", "").strip():
        return AiConfig(
            api_key=os.getenv("SILICONFLOW_API_KEY", "").strip(),
            base_url=os.getenv("SILICONFLOW_BASE_URL", "https://api.siliconflow.cn/v1").strip(),
            model=os.getenv("SILICONFLOW_MODEL", os.getenv("AI_MODEL", "")).strip(),
            timeout_seconds=timeout_seconds,
        )
    if os.getenv("AI_API_KEY", "").strip():
        return AiConfig(
            api_key=os.getenv("AI_API_KEY", "").strip(),
            base_url=os.getenv("AI_BASE_URL", "https://api.deepseek.com/v1").strip(),
            model=os.getenv("AI_MODEL", "deepseek-chat").strip(),
            timeout_seconds=timeout_seconds,
        )
    raise ValueError("未配置 AI Key。请在后端环境变量或 backend/.env 中设置 DEEPSEEK_API_KEY、OPENAI_API_KEY、DASHSCOPE_API_KEY、MOONSHOT_API_KEY、SILICONFLOW_API_KEY 或 AI_API_KEY。")


def load_dotenv_file() -> None:
    env_path = Path(__file__).resolve().parents[2] / ".env"
    if not env_path.exists():
        return
    for line in env_path.read_text(encoding="utf-8").splitlines():
        text = line.strip()
        if not text or text.startswith("#") or "=" not in text:
            continue
        key, value = text.split("=", 1)
        key = key.strip().lstrip("\ufeff")
        value = value.strip().strip('"').strip("'")
        if key and key not in os.environ:
            os.environ[key] = value


def build_chat_payload(
    mode: str,
    title: str,
    prompt: str,
    model: str,
    history: List[Dict[str, str]],
) -> Dict[str, object]:
    if not model:
        raise ValueError("未配置 AI_MODEL。SiliconFlow 等服务需要显式设置模型名。")
    user_input = prompt.strip() or "请根据当前科研场景给出一份可执行建议。"
    system_prompt = (
        "你是科研日报 APP 的科研工作台助手。请用中文回答，面向本科生/研究生科研记录场景。"
        "回答要具体、可执行、结构清晰，不要编造不存在的论文事实、DOI、实验数据或引用。"
        "如果输入信息不足，请明确写出需要补充的信息，并给出基于现有信息的下一步。"
        f"当前对话模式是「{title}」：{MODE_TASKS[mode]}"
        "请延续上下文回答用户最新问题。输出不要写客套话。"
    )
    messages: List[Dict[str, str]] = [{"role": "system", "content": system_prompt}]
    messages.extend(sanitize_history(history))
    messages.append({
        "role": "user",
        "content": f"用户最新输入：\n{user_input}\n\n请直接生成可以复制到科研日报或组会材料里的内容。"
    })
    return {
        "model": model,
        "messages": messages,
        "temperature": float(os.getenv("AI_TEMPERATURE", "0.4")),
    }


def sanitize_history(history: List[Dict[str, str]]) -> List[Dict[str, str]]:
    items: List[Dict[str, str]] = []
    for item in history[-12:]:
        role = item.get("role", "user")
        content = item.get("content", "").strip()
        if not content:
            continue
        items.append({
            "role": "assistant" if role == "assistant" else "user",
            "content": content[:4000],
        })
    return items


def call_chat_completions(cfg: AiConfig, payload: Dict[str, object]) -> str:
    url = normalize_chat_url(cfg.base_url)
    headers = {
        "Authorization": f"Bearer {cfg.api_key}",
        "Content-Type": "application/json",
    }
    try:
        response = requests.post(url, headers=headers, json=payload, timeout=cfg.timeout_seconds)
    except requests.Timeout as exc:
        raise AiProviderError("AI 服务响应超时，请稍后重试。") from exc
    except requests.RequestException as exc:
        raise AiProviderError("AI 服务连接失败，请检查网络、代理或 AI_BASE_URL。") from exc

    if response.status_code in (401, 403):
        raise AiProviderError("AI 服务鉴权失败，请检查 Key 是否正确。")
    if response.status_code < 200 or response.status_code >= 300:
        raise AiProviderError(format_provider_error(response))

    try:
        data = response.json()
    except ValueError as exc:
        raise AiProviderError("AI 服务返回格式异常。") from exc
    try:
        content = data["choices"][0]["message"]["content"]
    except (KeyError, IndexError, TypeError) as exc:
        raise AiProviderError("AI 服务返回格式异常。") from exc
    text = str(content).strip()
    if not text:
        raise AiProviderError("AI 服务返回了空内容。")
    return text


def normalize_chat_url(base_url: str) -> str:
    value = base_url.strip().rstrip("/")
    if value.endswith("/chat/completions"):
        return value
    return f"{value}/chat/completions"


def format_provider_error(response: requests.Response) -> str:
    message = ""
    try:
        data = response.json()
        error = data.get("error")
        if isinstance(error, dict):
            message = str(error.get("message", ""))
        elif isinstance(data.get("message"), str):
            message = data["message"]
    except ValueError:
        message = response.text
    message = " ".join(message.split())[:180]
    if message:
        return f"AI 服务请求失败：{response.status_code}，{message}"
    return f"AI 服务请求失败：{response.status_code}"
