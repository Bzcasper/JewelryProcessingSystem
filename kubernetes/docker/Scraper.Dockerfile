# docker/Scraper.Dockerfile
FROM python:3.9-slim

WORKDIR /app

COPY requirements-scraper.txt .
RUN pip install --no-cache-dir -r requirements-scraper.txt

COPY src/scraper .
COPY config/scraper_config.yaml .

CMD ["python", "main.py"]