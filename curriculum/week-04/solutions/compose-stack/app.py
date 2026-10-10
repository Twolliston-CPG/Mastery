"""Week 4 demo app: separate liveness and readiness endpoints."""
from __future__ import annotations

import logging
import os
import signal
import sys

import psycopg2
from flask import Flask, jsonify

logging.basicConfig(
    level=logging.INFO,
    format='{"ts":"%(asctime)s","level":"%(levelname)s","msg":"%(message)s"}',
    stream=sys.stdout,
)
log = logging.getLogger("app")
app = Flask(__name__)


@app.get("/health")
def health():
    """Liveness: is THIS PROCESS alive? Never check dependencies here --
    a database blip would otherwise restart every replica at once (BF-44)."""
    return jsonify(status="ok", pid=os.getpid()), 200


@app.get("/ready")
def ready():
    """Readiness: can we serve traffic? Dependency checks belong HERE --
    failing takes us out of rotation without a restart."""
    try:
        conn = psycopg2.connect(os.environ["DATABASE_URL"], connect_timeout=2)
        conn.close()
        return jsonify(status="ready"), 200
    except Exception as exc:                      # noqa: BLE001 - report any failure
        log.warning("readiness check failed: %s", exc)
        return jsonify(status="not-ready", error=str(exc)), 503


@app.get("/")
def index():
    return jsonify(app="week04-demo", pid=os.getpid(), host=os.uname().nodename)


def _term(signum, frame):  # noqa: ARG001
    log.info("SIGTERM received; shutting down gracefully")
    sys.exit(0)


signal.signal(signal.SIGTERM, _term)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "8080")))
