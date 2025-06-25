# Dockerfile
FROM python:3.10-slim-buster
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1
WORKDIR /app
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt
COPY . /app/

# Скопіюйте скрипт entrypoint та зробіть його виконуваним
COPY ./entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Використовуйте entrypoint як основну команду контейнера
ENTRYPOINT ["/app/entrypoint.sh"]

EXPOSE 8000
# CMD більше не потрібен, оскільки gunicorn запускається через entrypoint.sh
# Якщо ви залишите CMD, він буде переданий як аргумент до entrypoint.sh, що не є бажаним.