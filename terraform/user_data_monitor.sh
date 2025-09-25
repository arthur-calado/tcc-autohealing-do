#!/bin/bash
# Usamos 'set -e' para garantir que o script pare imediatamente se qualquer comando falhar
set -e

# --- 1. INSTALAÇÃO DE DEPENDÊNCIAS ---
# Espera a inicialização da rede e do apt
sleep 10
apt-get update
apt-get install -y docker.io docker-compose git

# --- 2. CRIAÇÃO DOS FICHEIROS DE CONFIGURAÇÃO ---
# Cria o diretório para os nossos ficheiros
mkdir -p /opt/monitoring

# Cria o ficheiro de configuração do Prometheus
cat <<'EOF' > /opt/monitoring/prometheus.yml
global:
  scrape_interval: 15s
alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']
rule_files:
  - /etc/prometheus/rules.yml
scrape_configs:
  - job_name: 'tcc-web'
    digitalocean_sd_configs:
      - port: 8080
    relabel_configs:
      - source_labels: [__meta_digitalocean_tags]
        regex: '.*,tcc-autohealing-web,.*'
        action: keep
      - source_labels: [__meta_digitalocean_private_ip]
        target_label: __address__
        replacement: '${1}:8080'
EOF

# Cria o ficheiro de regras do Prometheus
cat <<'EOF' > /opt/monitoring/rules.yml
groups:
  - name: TCCAlerts
    rules:
      - alert: TccWebAppDown
        expr: up{job="tcc-web"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Aplicação TCC Web está offline em {{ $labels.instance }}"
EOF

# Cria o ficheiro de configuração do Alertmanager
cat <<'EOF' > /opt/monitoring/alertmanager.yml
route:
  receiver: 'webhook-healer'
  group_wait: 10s
  group_interval: 1m
  repeat_interval: 5m
receivers:
  - name: 'webhook-healer'
    webhook_configs:
      - url: 'http://healer:5001/webhook'
EOF

# Cria o script Python do Auto-Healer
cat <<'EOF' > /opt/monitoring/healer.py
from flask import Flask, request, jsonify
import subprocess
import os
import logging
import threading

app = Flask(__name__)
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

TERRAFORM_DIR = "/terraform_project/terraform"
WEB_COUNT = int(os.getenv("WEB_COUNT", "2"))
HEALING_IN_PROGRESS = threading.Lock()

def trigger_terraform_recreation():
    if not HEALING_IN_PROGRESS.acquire(blocking=False):
        app.logger.warning("Processo de auto-healing já em andamento. A ignorar novo pedido.")
        return
    try:
        app.logger.info("A iniciar a recriação dos droplets web via Terraform.")
        replace_args = []
        for i in range(WEB_COUNT):
            replace_args.extend(["-replace", f"digitalocean_droplet.web[{i}]"])
        cmd = ["terraform", "apply", "-auto-approve"] + replace_args
        env = os.environ.copy()
        proc = subprocess.run(
            cmd, cwd=TERRAFORM_DIR, capture_output=True,
            text=True, check=True, env=env
        )
        app.logger.info(f"Terraform executado com sucesso: {proc.stdout}")
    except subprocess.CalledProcessError as e:
        app.logger.error(f"Falha na execução do Terraform: {e.stderr}")
    except Exception as e:
        app.logger.error(f"Ocorreu um erro inesperado: {e}")
    finally:
        HEALING_IN_PROGRESS.release()

@app.route('/webhook', methods=['POST'])
def webhook():
    data = request.json
    app.logger.info(f"Webhook recebido: status={data.get('status')}")
    if data.get('status') == 'firing':
        threading.Thread(target=trigger_terraform_recreation).start()
    return jsonify({"status": "received"}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001)
EOF

# Cria o ficheiro do Docker Compose
cat <<'EOF' > /opt/monitoring/docker-compose.yml
version: '3.7'
services:
  prometheus:
    image: prom/prometheus:v2.51.2
    volumes:
      - /opt/monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
      - /opt/monitoring/rules.yml:/etc/prometheus/rules.yml
    ports:
      - '9090:9090'
    command: '--config.file=/etc/prometheus/prometheus.yml'
  
  alertmanager:
    image: prom/alertmanager:v0.27.0
    volumes:
      - /opt/monitoring/alertmanager.yml:/etc/alertmanager/config.yml
    ports:
      - '9093:9093'
    command: '--config.file=/etc/alertmanager/config.yml'

  healer:
    image: python:3.11-slim
    volumes:
      - /opt/monitoring/healer.py:/app/healer.py
      - /opt/terraform_project:/terraform_project
    working_dir: /app
    environment:
      - DO_TOKEN=${DO_TOKEN}
    command: sh -c "pip install flask && python healer.py"
EOF

# --- 3. EXECUÇÃO DOS SERVIÇOS ---
# Clona o seu projeto do GitHub
git clone https://github.com/arthur-calado/tcc-autohealing-do/tree/inserting-prometheus /opt/terraform_project

# Inicia os serviços do Docker em background
systemctl enable --now docker
docker-compose -f /opt/monitoring/docker-compose.yml up -d