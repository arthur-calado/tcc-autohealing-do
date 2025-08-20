#cloud-config
package_update: true
package_upgrade: true
packages:
  - docker.io
  - python3
  - python3-pip
write_files:
  - path: /opt/app/Dockerfile
    permissions: '0644'
    content: |
      FROM python:3.11-slim
      WORKDIR /app
      COPY app.py /app/app.py
      RUN pip install --no-cache-dir flask psycopg2-binary gunicorn
      EXPOSE 8080
      ENV FLASK_ENV=production
      CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:8080", "app:app"]
  - path: /opt/app/app.py
    permissions: '0644'
    content: |
      from flask import Flask, jsonify
      import os, socket, time
      import psycopg2

      app = Flask(__name__)
      BOOT_TS = time.time()

      DB_HOST = os.getenv("DB_HOST", "${db_host}")
      DB_USER = os.getenv("DB_USER", "tcc")
      DB_PASS = os.getenv("DB_PASS", "tccpass")
      DB_NAME = os.getenv("DB_NAME", "tccdb")

      def db_ok():
          try:
              conn = psycopg2.connect(
                  host=DB_HOST, user=DB_USER, password=DB_PASS, dbname=DB_NAME, connect_timeout=2
              )
              conn.close()
              return True
          except Exception:
              return False

      @app.get("/")
      def index():
          return jsonify({
              "service": "tcc-web",
              "host": socket.gethostname(),
              "db_reachable": db_ok()
          })

      @app.get("/health")
      def health():
          # readiness: app up + db reachability
          return (jsonify({"status": "ok"}), 200) if db_ok() else (jsonify({"status": "degraded"}), 503)

      @app.get("/metrics")
      def metrics():
          return f"uptime_seconds {int(time.time()-BOOT_TS)}\n", 200, {"Content-Type": "text/plain"}

  - path: /etc/systemd/system/tcc-app.service
    permissions: '0644'
    content: |
      [Unit]
      Description=TCC App via Docker
      After=docker.service
      Requires=docker.service
      StartLimitIntervalSec=0

      [Service]
      Restart=always
      RestartSec=3
      ExecStartPre=/usr/bin/docker build -t tcc-app:latest /opt/app
      ExecStart=/usr/bin/docker run --rm --name tcc-app -p 8080:8080 \
        -e DB_HOST=${db_host} -e DB_USER=tcc -e DB_PASS=tccpass -e DB_NAME=tccdb \
        tcc-app:latest
      ExecStop=/usr/bin/docker stop tcc-app

      [Install]
      WantedBy=multi-user.target

  - path: /usr/local/bin/tcc-simulate-failure.sh
    permissions: '0755'
    content: |
      #!/usr/bin/env bash
      systemctl stop tcc-app
      sleep 20
      systemctl start tcc-app

runcmd:
  - systemctl daemon-reload
  - systemctl enable --now docker
  - systemctl enable --now tcc-app
