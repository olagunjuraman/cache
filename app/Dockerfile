FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8080

ENV PORT 8080
ENV PYTHONUNBUFFERED TRUE

CMD exec gunicorn --bind :$PORT --workers 1 --threads 8 --timeout 0 main:app