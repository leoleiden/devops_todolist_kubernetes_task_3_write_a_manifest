Instructions for Deploying and Testing Django ToDo App in Kubernetes
This document provides step-by-step instructions for deploying and testing the Django ToDo application in a Kubernetes cluster.

1. Prerequisites
Docker Desktop or Docker Engine installed.

kubectl installed and access to a Kubernetes cluster (e.g., Minikube, Docker Desktop Kubernetes, or a remote cluster).

A Docker Hub account.

Forked and cloned Django ToDo App repository.

2. Application and Docker Image Preparation
Update requirements.txt:
Ensure that the requirements.txt file in your project's root directory includes gunicorn:

# requirements.txt
#... other dependencies...
gunicorn==21.2.0

Add Liveness and Readiness Endpoints:
Open the api/views.py and api/urls.py files in your Django project and add the following code:

api/views.py:

#... (existing code)...
from django.http import HttpResponse
from rest_framework.decorators import api_view

@api_view()
def liveness_check(request):
    return HttpResponse('ok', status=200)

@api_view()
def readiness_check(request):
    # In a production environment, this might include additional checks,
    # such as database connectivity.
    return HttpResponse('ok', status=200)

api/urls.py:

from django.urls import include, path
from rest_framework.routers import DefaultRouter

from api import views

router = DefaultRouter()
router.register(r"users", views.UserViewSet)
router.register(r"todolists", views.TodoListViewSet)
router.register(r"todos", views.TodoViewSet)

app_name = "api"
urlpatterns = [
    path("", include(router.urls)),
    path('health/liveness/', views.liveness_check, name='liveness_check'),
    path('health/readiness/', views.readiness_check, name='readiness_check'),
]

Create src/entrypoint.sh:
Create a file named entrypoint.sh in the src folder of your project with the following content:

#!/bin/sh

echo "Applying database migrations..."
python manage.py migrate --noinput

echo "Starting Gunicorn server..."
exec gunicorn --bind 0.0.0.0:8000 todolist.wsgi:application

Update Dockerfile:
Update the Dockerfile in the src folder of your project with the following content:

# Dockerfile
FROM python:3.10-slim-buster
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1
WORKDIR /app
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt
COPY . /app/

# Copy the entrypoint script and make it executable
COPY ./entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Use the entrypoint as the main command for the container
ENTRYPOINT ["/app/entrypoint.sh"]

EXPOSE 8000

Build and Push Docker Image:
Replace {yourname} with your Docker Hub username. Make sure to execute the docker build command from the root of your project, specifying the src folder.

docker login
docker build -t {yourname}/todoapp:3.0.0 src # Note the 'src' at the end
docker push {yourname}/todoapp:3.0.0

Important: Ensure that todolist is the name of your main Django project (the folder containing settings.py and wsgi.py). If the name is different, change todolist.wsgi:application in entrypoint.sh accordingly.

3. Create Kubernetes Manifests
All Kubernetes manifests should be located in the .infrastructure folder at the root of your repository.

Create .infrastructure folder:

mkdir .infrastructure

Create namespace.yml:
Create a file named .infrastructure/namespace.yml with the following content:

#.infrastructure/namespace.yml
apiVersion: v1
kind: Namespace
metadata:
  name: todoapp

Create busybox.yml:
Create a file named .infrastructure/busybox.yml with the following content:

#.infrastructure/busybox.yml
apiVersion: v1
kind: Pod
metadata:
  name: busybox-curl-test
  namespace: todoapp
spec:
    containers:
    - name: busybox-curl
      image: ikulyk404/busyboxplus:curl
      command: ["sh", "-c", "while true; do sleep 3600; done"]
    restartPolicy: Never

Update todoapp-pod.yml:
Update the file .infrastructure/todoapp-pod.yml with the following content. Replace {yourname} with your Docker Hub username.

#.infrastructure/todoapp-pod.yml
apiVersion: v1
kind: Pod
metadata:
  name: todoapp-pod
  namespace: todoapp
  labels:
    app: todoapp
spec:
  containers:
  - name: todoapp-container
    image: {yourname}/todoapp:3.0.0
    ports:
    - containerPort: 8000
    env:
    - name: DJANGO_SETTINGS_MODULE
      value: todolist.settings
    - name: SECRET_KEY
      value: "your-super-secret-key-for-production" # In production, use Kubernetes Secrets
    - name: DEBUG
      value: "False"
    - name: ALLOWED_HOSTS
      value: "*" # Changed from "localhost,127.0.0.1" to "*" for Kubernetes compatibility

    livenessProbe:
      httpGet:
        path: /api/health/liveness/
        port: 8000
      initialDelaySeconds: 15
      periodSeconds: 10
      timeoutSeconds: 5
      failureThreshold: 3

    readinessProbe:
      httpGet:
        path: /api/health/readiness/
        port: 8000
      initialDelaySeconds: 5
      periodSeconds: 5
      timeoutSeconds: 3
      failureThreshold: 3

4. Apply Kubernetes Manifests
Apply the manifests to your Kubernetes cluster in the following sequence:

Apply the Namespace:

kubectl apply -f .infrastructure/namespace.yml

Verify that the namespace is created:

kubectl get namespaces

Apply the ToDo App Pod:

kubectl apply -f .infrastructure/todoapp-pod.yml

Check the Pod status (wait for Running and Ready status):

kubectl get pods -n todoapp

If the Pod does not start, check the logs:

kubectl logs todoapp-pod -n todoapp
kubectl describe pod todoapp-pod -n todoapp

Apply the busyboxplus:curl Pod:

kubectl apply -f .infrastructure/busybox.yml

Check the Pod status:

kubectl get pods -n todoapp

5. Test the Application
5.1. Testing with kubectl port-forward
This method allows you to access your application running in Kubernetes through a local port on your machine.

Port Forwarding:
Open a new terminal and run the command:

kubectl port-forward pod/todoapp-pod 8000:8000 -n todoapp

This command forwards local port 8000 to port 8000 of the todoapp-pod container in the todoapp namespace. It will run until you stop it (Ctrl+C).

Access the Application:
Open your web browser and navigate to:

Main Page: http://localhost:8000/

API: http://localhost:8000/api/

Liveness Probe: http://localhost:8000/api/health/liveness/ (should return ok)

Readiness Probe: http://localhost:8000/api/health/readiness/ (should return ok)

Verify that the application is working correctly; you should be able to browse pages, interact with the UI, and the API.

Stop Port Forwarding:
Return to the terminal where you ran port-forward and press Ctrl+C.

5.2. Testing with the busyboxplus:curl Container
This testing method allows you to verify network interaction with the Django ToDo Pod from within the Kubernetes cluster, simulating requests from other services.

Execute curl commands in the busybox-curl-test Pod:

# Check the main page (should return HTML)
kubectl exec -it busybox-curl-test -n todoapp -- curl http://todoapp-pod:8000/

# Check the API (should return JSON or the API HTML page)
kubectl exec -it busybox-curl-test -n todoapp -- curl http://todoapp-pod:8000/api/

# Check Liveness Probe (should return 'ok')
kubectl exec -it busybox-curl-test -n todoapp -- curl http://todoapp-pod:8000/api/health/liveness/

# Check Readiness Probe (should return 'ok')
kubectl exec -it busybox-curl-test -n todoapp -- curl http://todoapp-pod:8000/api/health/readiness/

Note: The Pod name (todoapp-pod) is used as the host because in this simple case, Pods can communicate using Pod names. In a real scenario with a Deployment and Service, the Service name (http://<service-name>:<port>/) should be used.

6. Cleanup (Optional)
After completing the testing, you can delete the created Kubernetes resources:

kubectl delete -f .infrastructure/todoapp-pod.yml -n todoapp
kubectl delete -f .infrastructure/busybox.yml -n todoapp
kubectl delete -f .infrastructure/namespace.yml
