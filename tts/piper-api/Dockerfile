FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app
RUN pip install --no-cache-dir "piper-tts[http]==1.8.0"

COPY gateway.py /app/gateway.py
COPY start-piper.sh /app/start-piper.sh
RUN chmod 0555 /app/start-piper.sh

EXPOSE 8080 5000
CMD ["python", "/app/gateway.py"]
