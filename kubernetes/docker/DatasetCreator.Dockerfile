# docker/DatasetCreator.Dockerfile
FROM python:3.9-slim

WORKDIR /app

COPY requirements-dataset.txt .
RUN pip install --no-cache-dir -r requirements-dataset.txt

COPY src/dataset_creator .
COPY config/dataset_config.yaml .

CMD ["python", "main.py"]