#!/bin/bash
set -e
aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin 533267392153.dkr.ecr.us-east-2.amazonaws.com
docker-compose -f ../../docker-compose.yml build backend
docker tag devops-project_backend:latest 533267392153.dkr.ecr.us-east-2.amazonaws.com/devops-project:latest
docker push 533267392153.dkr.ecr.us-east-2.amazonaws.com/devops-project:latest
