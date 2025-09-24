#!/bin/bash
#cloud-config
package_update: true
package_upgrade: true
packages:
  - docker.io
  - docker-compose

write_files:
  # 1. Configuração do Prometheus
  - path: /opt/monitoring/prometheus.yml
    permissions: '0644'
    content: |
      global:
        scrape_interval: 15s
      alerting:
        alertmanagers:
          - static_configs:
              - targets: ['localhost:9093']
      rule_files:
        - /etc/prometheus/rules.yml
      scrape_configs:
        - job_name: 'tcc-web'
          # Usa a integração nativa da DigitalOcean para achar os droplets
          digitalocean_sd_configs:
            - port: 8080
          relabel_configs:
            # Mantém apenas droplets com a tag 'tcc-autohealing-web'
            - source_labels: [__meta_digitalocean_tags]
              regex: '.*,tcc-autohealing-web,.*'
              action: keep
            # Usa o IP privado para o scrape
            - source_labels: [__meta_digitalocean_private_ip]
              target_label: __address__
              replacement: '${1}:8080'

  # 2. Regras de Alerta do Prometheus
  - path: /opt/monitoring/rules.yml
    permissions: '0644'
    content: |
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

  # 3. Configuração do Alertmanager
  - path: /opt/monitoring/alertmanager.yml
    permissions: '0644'
    content: |
      route:
        receiver: 'webhook-healer'
      receivers:
        - name: 'webhook-healer'
          webhook_configs:
            - url: 'http://localhost:5001/webhook'

  # 4. Script Python do Auto-Healer
  - path: /opt/monitoring/healer.py
    permissions: '0644'
    content: |
      from flask import Flask, request, jsonify
      import subprocess
      import os
      import logging
      import threading

      app = Flask(__name__)
      logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

      TERRAFORM_DIR = "/terraform_project"
      WEB_COUNT = int(os.getenv("WEB_COUNT", "2"))
      HEALING_IN_PROGRESS = threading.Lock()

      def trigger_terraform_recreation():
          if not HEALING_IN_PROGRESS.acquire(blocking=False):
              app.logger.warning("Healing process already in progress. Skipping trigger.")
              return

          try:
              app.logger.info("Iniciando a recriação dos droplets web via Terraform.")
              replace_args = []
              for i in range(WEB_COUNT):
                  replace_args.extend(["-replace", f"digitalocean_droplet.web[{i}]"])

              cmd = ["terraform", "apply", "-auto-approve"] + replace_args

              # As credenciais da DO devem ser passadas como variáveis de ambiente
              env = os.environ.copy()

              proc = subprocess.run(
                  cmd, cwd=TERRAFORM_DIR, capture_output=True,
                  text=True, check=True, env=env
              )
              app.logger.info(f"Terraform executado com sucesso: {proc.stdout}")
          except subprocess.CalledProcessError as e:
              app.logger.error(f"Falha na execução do Terraform: {e.stderr}")
          finally:
              HEALING_IN_PROGRESS.release()

      @app.route('/webhook', methods=['POST'])
      def webhook():
          data = request.json
          app.logger.info(f"Webhook recebido: status={data.get('status')}")

          if data.get('status') == 'firing':
              # Inicia o processo de healing em uma thread separada para não bloquear a resposta
              threading.Thread(target=trigger_terraform_recreation).start()

          return jsonify({"status": "received"}), 200

      if __name__ == '__main__':
          app.run(host='0.0.0.0', port=5001)

  # 5. Docker Compose para orquestrar tudo
  - path: /opt/monitoring/docker-compose.yml
    permissions: '0644'
    content: |
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
            # Montamos o diretório do projeto Terraform que será clonado
            - /opt/terraform_project:/terraform_project
          working_dir: /app
          ports:
            - '5001:5001'
          environment:
            # Passa o token da DO para o container do Healer
            - DO_TOKEN=${DO_TOKEN}
          command: sh -c "pip install flask && python healer.py"

runcmd:
  # Clona seu projeto para que o Healer possa rodar o Terraform
  - apt-get install -y git
  # !! IMPORTANTE: Troque pela URL do SEU repositório (pode ser necessário usar SSH keys)
  - git clone https://github.com/arthur-calado/tcc-autohealing-do/tree/inserting-prometheus /opt/terraform_project

  # Inicia os serviços
  - systemctl enable --now docker
  - docker-compose -f /opt/monitoring/docker-compose.yml up -d