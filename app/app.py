from flask import Flask, jsonify
import os
import socket
import time
import psycopg2
from prometheus_flask_exporter import PrometheusMetrics

app = Flask(__name__)
metrics = PrometheusMetrics(app) # Agrupa métricas padrão
BOOT_TS = time.time()

# Métrica customizada para a conectividade com o banco
db_health = metrics.info('app_db_health', 'Status of the database connection')

def db_ok():
    try:
        conn = psycopg2.connect(
            host=os.getenv("DB_HOST","localhost"),
            user=os.getenv("DB_USER","tcc"),
            password=os.getenv("DB_PASS","tccpass"),
            dbname=os.getenv("DB_NAME","tccdb"),
            connect_timeout=2
        ); conn.close()
        return True
    except Exception: return False

@app.get("/")
def index():
    return jsonify({
        "service":"tcc-web",
        "host":socket.gethostname(),
        "db_reachable":db_ok()
    })

@app.get("/health")
def health():
    is_db_ok = db_ok()
    # Atualiza a métrica customizada que o Prometheus vai ler
    db_health.info({'status': 'ok' if is_db_ok else 'degraded'})

    if is_db_ok:
        return (jsonify({"status":"ok"}),200)
    else:
        return (jsonify({"status":"degraded"}),503)

# O endpoint /metrics é gerenciado automaticamente pela biblioteca PrometheusMetrics
# A rota customizada abaixo não é mais necessária, mas você pode adicionar métricas manuais se quiser
# @app.get("/metrics")
# def metrics(): return f"uptime_seconds {int(time.time()-BOOT_TS)}\n",200,{"Content-Type":"text/plain"}