# SciDaily Backend

## Run

```bash
cd backend
uvicorn main:app --reload
```

## Docker

```bash
cd backend
docker build -t scidaily-api .
docker run -p 8000:8000 scidaily-api
```

## Endpoints

- `GET /api/v1/news/daily`
- `GET /api/v1/news/{news_id}`
- `GET /api/v1/categories`

## Pipeline Placeholders

- `pipeline/fetch_rss.py`
- `pipeline/summarize_with_llm.py`
- `pipeline/schedule_job.py`
