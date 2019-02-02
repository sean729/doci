#!/usr/bin/env bash
echo "Begin docker CI/CD locally"

docker volume create --name=mavenrepo || exit -1
docker build -t doci-maven:latest doci-maven/
docker-compose -f docker-ci.yml run --rm maven clean test || exit -1
docker-compose -f docker-ci.yml run --rm maven clean package || exit -1
docker-compose build || exit -1
docker-compose up -d || exit -1

echo "The container has been deployed"
