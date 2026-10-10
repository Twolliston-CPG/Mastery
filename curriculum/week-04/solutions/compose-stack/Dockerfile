# syntax=docker/dockerfile:1.7
# Multi-stage. Final image runs non-root with a read-only root filesystem.

FROM python:3.12-slim AS builder
WORKDIR /app
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

FROM python:3.12-slim

# Numeric UID matters: Kubernetes runAsNonRoot cannot verify a username.
RUN groupadd -r app --gid 10001 && \
    useradd  -r -g app --uid 10001 --no-log-init --create-home app

COPY --from=builder --chown=app:app /opt/venv /opt/venv

ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=8080

WORKDIR /app
COPY --chown=app:app app.py .

USER 10001:10001
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD ["python", "-c", "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8080/health').status==200 else 1)"]

# Exec form: gunicorn is PID 1 and receives SIGTERM directly.
ENTRYPOINT ["gunicorn"]
CMD ["--bind", "0.0.0.0:8080", "--workers", "2", "--access-logfile", "-", \
     "--error-logfile", "-", "--graceful-timeout", "30", "app:app"]
