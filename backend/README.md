# SciDaily Backend

## 1) API (原有功能)

```bash
cd backend
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Endpoints:
- `GET /api/v1/news/daily`
- `GET /api/v1/news/{news_id}`
- `GET /api/v1/categories`

## 2) 轻量科研日报系统（无LLM）

### 安装依赖

```bash
cd backend
pip install -r requirements.txt
```

### 配置

编辑 `config/research_daily.example.yaml`：
- `source.arxiv_categories`：arXiv分类
- `source.extra_rss`：其它RSS
- `filter.keywords`：关键词
- `schedule.hour/minute`：定时任务时间
- `push.email/wecom/telegram`：推送渠道

可用环境变量覆盖密钥：
- `RESEARCH_DAILY_SMTP_PASSWORD`
- `RESEARCH_DAILY_WECOM_WEBHOOK`
- `RESEARCH_DAILY_TELEGRAM_TOKEN`
- `RESEARCH_DAILY_TELEGRAM_CHAT_ID`

### 运行一次（推荐先 dry-run）

```bash
cd backend
python -m research_daily.cli --config config/research_daily.example.yaml run-once --dry-run
```

输出：
- `outputs/YYYY-MM-DD/daily_YYYY_MM_DD.md`
- `outputs/YYYY-MM-DD/daily_YYYY_MM_DD.html`
- `data/research_daily.db`

### 开启每天定时任务（默认 08:00）

```bash
cd backend
python -m research_daily.cli --config config/research_daily.example.yaml schedule
```

## 3) 兼容入口

- `pipeline/fetch_rss.py`：执行一次 dry-run 报告生成
- `pipeline/schedule_job.py`：启动定时调度
- `pipeline/summarize_with_llm.py`：无LLM摘要截断工具（遗留兼容）

## 4) Docker

```bash
cd backend
docker build -t scidaily-api .
docker run -p 8000:8000 scidaily-api
```
