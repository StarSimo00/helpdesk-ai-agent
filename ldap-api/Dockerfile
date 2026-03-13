FROM python:3.12-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    iputils-ping gcc libpq-dev \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir \
    flask flask-cors ldap3 psycopg2-binary flasgger \
    qdrant-client fastembed

COPY app.py /app/app.py

ENV PYTHONUNBUFFERED=1
EXPOSE 5000
CMD ["python", "app.py"]
