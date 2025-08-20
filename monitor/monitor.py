#!/usr/bin/env python3
import requests
import subprocess
import time
import os
import sys
import json
from datetime import datetime

# Config
HEALTH_URL = os.getenv("HEALTH_URL", "http://127.0.0.1/health")  # defina com o lb_ip
TERRAFORM_DIR = os.getenv("TERRAFORM_DIR", os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "terraform")))
WEB_COUNT = int(os.getenv("WEB_COUNT", "2"))
CHECK_INTERVAL = float(os.getenv("CHECK_INTERVAL", "5"))   # segundos
UNHEALTHY_THRESHOLD = int(os.getenv("UNHEALTHY_THRESHOLD", "3"))  # leituras consecutivas
LOG_FILE = os.getenv("LOG_FILE", "monitor.log")

state = {
    "consecutive_fail": 0,
    "last_healthy_ts": None,
    "failure_start_ts": None,
    "recovery_ts": None
}

def log(msg, data=None):
    line = f"{datetime.utcnow().isoformat()}Z | {msg}"
    if data is not None:
        line += " | " + json.dumps(data)
    print(line)
    with open(LOG_FILE, "a") as f:
        f.write(line + "\n")

def is_healthy():
    try:
        r = requests.get(HEALTH_URL, timeout=3)
        return r.status_code == 200
    except Exception:
        return False

def terraform_replace_all_web():
    # Força recriação de TODOS os droplets web (simplificação para TCC)
    replace_args = []
    for i in range(WEB_COUNT):
        replace_args.extend(["-replace", f"digitalocean_droplet.web[{i}]"])
    cmd = ["terraform", "apply", "-auto-approve"] + replace_args
    log("Executing terraform replacement", {"cmd": " ".join(cmd)})
    proc = subprocess.run(cmd, cwd=TERRAFORM_DIR, capture_output=True, text=True)
    log("Terraform stdout", {"out": proc.stdout[-1000:]})
    if proc.returncode != 0:
        log("Terraform failed", {"code": proc.returncode, "err": proc.stderr[-2000:]})
    else:
        log("Terraform success")

def main():
    log("Monitor started", {"health_url": HEALTH_URL, "tf_dir": TERRAFORM_DIR, "web_count": WEB_COUNT})
    while True:
        ok = is_healthy()
        now = time.time()
        if ok:
            if state["consecutive_fail"] >= UNHEALTHY_THRESHOLD and state["failure_start_ts"] is not None:
                state["recovery_ts"] = now
                mttd = state["failure_start_ts"] - (state["last_healthy_ts"] or state["failure_start_ts"])
                mttr = state["recovery_ts"] - state["failure_start_ts"]
                log("SERVICE RECOVERED", {"MTTD_sec_est": round(mttd,2), "MTTR_sec": round(mttr,2)})
                state["failure_start_ts"] = None
                state["recovery_ts"] = None
            state["consecutive_fail"] = 0
            state["last_healthy_ts"] = now
        else:
            state["consecutive_fail"] += 1
            if state["consecutive_fail"] == UNHEALTHY_THRESHOLD:
                state["failure_start_ts"] = now
                log("SERVICE DOWN DETECTED", {"consecutive_fail": state["consecutive_fail"]})
                terraform_replace_all_web()
        time.sleep(CHECK_INTERVAL)

if __name__ == "__main__":
    if "http" not in os.getenv("HEALTH_URL",""):
        print("Configure HEALTH_URL (ex.: http://<lb_ip>/health)")
        sys.exit(1)
    main()
