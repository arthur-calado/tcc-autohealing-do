from flask import Flask, jsonify
import os, socket, time
import psycopg2
app = Flask(__name__)
BOOT_TS = time.time()
def db_ok():
    try:
        conn = psycopg2.connect(
            host=os.getenv("DB_HOST","localhost"),
            user=os.getenv("DB_USER","tcc"),
            password=os.getenv("DB_PASS","tccpass"),
            dbname=os.getenv("DB_NAME","tccdb"),
            connect_timeout=2
        ); conn.close(); return True
    except Exception: return False

@app.get("/")
def index(): return jsonify({"service":"tcc-web","host":socket.gethostname(),"db_reachable":db_ok()})
@app.get("/health")
def health(): return (jsonify({"status":"ok"}),200) if db_ok() else (jsonify({"status":"degraded"}),503)
@app.get("/metrics")
def metrics(): return f"uptime_seconds {int(time.time()-BOOT_TS)}\n",200,{"Content-Type":"text/plain"}
