FROM python:3.11-slim
WORKDIR /app
COPY app.py /app/app.py
# Adicionamos a nova dependência aqui
RUN pip install --no-cache-dir flask psycopg2-binary gunicorn prometheus-flask-exporter
EXPOSE 8080
CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:8080", "app:app"]