FROM python:3.12.12-slim-bookworm
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1
WORKDIR /app
COPY app/app.py /app/app.py
USER 10001:10001
EXPOSE 5000
CMD ["python", "/app/app.py"]
