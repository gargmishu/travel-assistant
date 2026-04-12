#!/bin/sh
docker build -t test-app .
# docker build --no-cache -t test-app .

# # Access the app at http://localhost:5000
# docker run -p 5000:8080 test-app


# Access the app at http://localhost:080:808
docker run -p 8080:8080 test-app