FROM ghcr.io/astral-sh/uv:latest AS uv
FROM python:3.14-slim
COPY --from=uv /uv /uvx /bin/
WORKDIR /app
ENV UV_PROJECT_ENVIRONMENT=/opt/venv UV_PYTHON_DOWNLOADS=never PATH="/opt/venv/bin:$PATH" PYTHONUNBUFFERED=1
COPY pyproject.toml uv.lock ./
RUN uv sync --locked --no-dev --no-install-project
COPY . .
EXPOSE 8000
CMD ["gunicorn", "config.wsgi:application", "--bind", "0.0.0.0:8000"]