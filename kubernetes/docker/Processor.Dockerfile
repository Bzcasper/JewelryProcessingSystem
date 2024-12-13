# docker/Processor.Dockerfile
FROM python:3.9-slim

WORKDIR /app

COPY requirements-processor.txt .
RUN pip install --no-cache-dir -r requirements-processor.txt

COPY src/processor .
COPY config/processor_config.yaml .

CMD ["python", "main.py"]
