#!/usr/bin/env bash

newVer="1.0.3"

echo Begin docker CI/CD locally for version ${newVer}

docker volume create --name=mavenrepo || exit -1
echo Created volume mavenrepo 

docker build -t doci-maven:${newVer} doci-maven/ 
echo 1. Created image doci-maven v ${newVer} 

#docker build -t doci-maven:latest doci-maven/
docker-compose -f docker-ci.yml run --rm maven clean test || exit -1
echo 2. Completed Maven test

docker-compose -f docker-ci.yml run --rm maven clean package || exit -1
echo 3. Completed Maven package

docker-compose build || exit -1
docker image tag doci-app:latest doci-app:${newVer}
echo 4. Successfuly built image doci-app (latest)

docker-compose up -d  || exit -1
echo 5. Running container based on doci-app version ${newVer}

#docker-compose scale app=3
#echo Begin 

echo "The containers based on ${newVer} were deployed and scaled"
docker ps doci_app
