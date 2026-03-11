FROM python:3.12-alpine

WORKDIR /app

# Install system dependencies
RUN apk add --no-cache \
    iputils \
    bash \
    gcc \
    musl-dev \
    libffi-dev \
    postgresql-dev

# Install python dependencies
RUN pip install --no-cache-dir \
    flask \
    flask-cors \
    ldap3 \
    psycopg2-binary \
    flasgger

# Copy application
COPY app.py /app/app.py

# Environment safety
ENV PYTHONUNBUFFERED=1

# Expose API port
EXPOSE 5000

# Start API
CMD ["python", "app.py"]
