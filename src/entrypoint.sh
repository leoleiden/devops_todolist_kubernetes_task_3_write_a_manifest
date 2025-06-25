#!/bin/sh

echo "Applying database migrations..."
python manage.py migrate --noinput

echo "Starting Gunicorn server..."
# 'exec' замінює поточний процес на gunicorn, дозволяючи Docker коректно обробляти сигнали.
exec gunicorn --bind 0.0.0.0:8000 todolist.wsgi:application