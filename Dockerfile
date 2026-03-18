# Use an official Python runtime as a parent image
# This tells Google Cloud to start with a clean environment that has Python 3.10
FROM python:3.10-slim

# Set the working directory in the container
WORKDIR /app

# Copy the requirements file into the container
COPY requirements.txt .

# Install any needed packages specified in requirements.txt
# Using --no-cache-dir makes the container slightly smaller
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of your application's code (app.py, models, pkl files, credentials.json) 
# into the container at /app
COPY . .

# Tell Cloud Run how to start the Gunicorn production server.
# Gunicorn is a standard Python WSGI server suitable for production.
# It binds to the port specified by the PORT environment variable (set automatically by Cloud Run).
# --workers 1 --threads 8: Basic configuration for handling requests. Adjust if needed.
# --timeout 0: Disables Gunicorn's request timeout (Cloud Run handles timeouts).
# app:app : Tells Gunicorn to run the Flask application object named 'app' inside the file named 'app.py'.
CMD exec gunicorn --bind :$PORT --workers 1 --threads 8 --timeout 0 app:app
