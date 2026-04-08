# Python image to use.
FROM python:3.12-slim

# ENV PYTHONUNBUFFERED True is used to ensure that Python's standard output (stdout) and error (stderr) streams are sent directly to the container logs (and thus to Google Cloud Logging/Knative logs) without being buffered
ENV PYTHONUNBUFFERED=True

# Set the working directory to /app
WORKDIR /app

# Allow Python to find modules in subdirectories
ENV PYTHONPATH=/app

# copy the requirements file used for dependencies
COPY requirements.txt .

# Install any needed packages specified in requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the working directory contents into the container at /app
COPY . .

# Run app.py when the container launches
# ENTRYPOINT ["python", "main.py"]
# ENTRYPOINT ["python", "apps.backend.main:app"]
CMD ["uvicorn", "apps.backend.main:app", "--host", "0.0.0.0", "--port", "8080"]
# CMD ["uvicorn", "apps.backend.main_backup:app", "--host", "0.0.0.0", "--port", "8080"]

# Test locally: Run docker build -t test-app . 
# and then docker run -p 8080:8080 test-app
# If it crashes locally, the traceback will tell you if it's still a missing file or a code error.