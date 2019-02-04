#!/bin/bash

# SCRIPTNAME: devops-ci.sh
# AUTHOR:     Sean Peterson
# MODifIED:   2019-02-02
# COMMENT:    trigger CI and handle results
#             upload images to docker hub
#             deploy containers based on images
# CHANGES:    Fixed version tag on images
# VERSION:    0.2.5

# PREREQS
# host must have package jq

# CONTROLS
set -o errexit
#set -o xtrace


# VARIABLES

nameImage="doci-app" # SAMPLE doci-app:1.0.0
autoScale="3"
#docker pull sean729/$nameImage:latest 

verImage=$(docker image inspect $nameImage:latest | jq .[0] | jq .RepoTags[0] | sed "s/\"//g")
lenImage=${#verImage}
curVer=${verImage:$[lenImage-5]:$lenImage}

echo "Current production $nameImage image is: ${curVer}"

Maj=${curVer:0:1}
Min=${curVer:2:1}
Rel=${curVer:4:1}


#echo "Starting values for numbers Maj Min Rel: ${Maj} ${Min} ${Rel}"

function _incrVersion () { # Base 10 version counter

	if [[ "${3}" == 9 ]]; then 
		nRel="0"
		if [[ "${2}" == 9 ]]; then 
			nMin="0"
			nMaj=$[$1+1]
		else nMin=$[$2+1]
			nMaj=$1
		fi
	else nRel=$[$3+1]
		nMin=$2
		nMaj=$1
	fi

	nVer="${nMaj}.${nMin}.${nRel}"
	echo ${nVer}

}


nextVer=$(_incrVersion $Maj $Min $Rel)

echo "Staging deployment of next version: ${nextVer}"



# 1. generate doci-base image shall be commented out, not part of script CD


echo 2. start building image doci-app via maven container for CI/CD
docker-compose -f docker-ci.yml run --rm maven clean test || exit -1
echo 2.1 Completed Maven test

docker-compose -f docker-ci.yml run --rm maven clean package || exit -1
echo 2.2 Completed compiling Maven package

docker-compose build || exit -1
echo 2.3 Successfuly built image doci-app latest

docker image tag doci-app:latest doci-app:${newVer}
echo 2.4 Tagged doci-app (${newVer})

docker-compose down 
echo 2.5 Stopped containers based on doci-app version ${curVer}


# manage old containers

R=$autoScale

while [ "$R" -ne 0 ]; 
do 
	docker container rename doci_app_${R} doci_app_$[R}-${curVer}; 
	R=$[R-1]; 
done

echo 3. run containers based on image doci-app for CD
docker-compose up -d  || Failure=1

echo 3.1 Scaling up doci_app version ${newVer} to $autoScale containers
docker-compose scale app=3

echo 3.1 get IP address of each sprboot container and update load balance config file (nginx)

R=$autoScale
while [ "$R" -ne 0 ]; 
do 
	export "IPA$R"=$(docker container inspect "doci_app_${R}" | jq .[0].NetworkSettings.Networks.doci_default.IPAddress | sed "s/\"//g"); 
	if [[ $IPA$R -eq null ]]; then 
		# roll-back step: terminate script 
		echo Rolling back deployment at step 3.1 - Failed to obtain IP address of container doci_app_${R}; 
		Failure=1; 
	else 
		test=0
		test=$(curl http://$IPA$R:8080/)
		if [[ $test -ne "Aplicación de laboratorio v2" ]]; then 
			Failure=1
		fi
	fi
	echo update the IP $IPA$R in /root/images/doci-lbal/hosts-apptier.conf
	sed -i "/sprboot$R/!{q10}; s/sprboot$R/$IPA$R/" ./doci-lbal/default-nginx.conf || rc=$?; 

	if [[ ${rc} -ne 0 ]]; then
		# roll-back step: terminate script 
		echo Halted deployment at step 3 - Unable to update nginx config for load balancing
		Failure=1;
	fi 
	R=$[R-1]; 
done 

if [[ $Failure -eq 1 ]]; then 
	docker-compose down 
	docker image tag doci-app:${curVer} doci-app:latest 
	docker-compose up -d 
	echo Rolled back at section 3 and halted further deployment.
	exit -3
fi


echo 4. NGINX - 


echo 4.1 generate new doci-lbal image 

cd ./doci-lbal && docker build -t doci-lbal:${nextVer} . || rc=$?; 

	if [[ ${rc} -ne 0 ]]; then
		# roll-back step: terminate script 
		echo Failed to generate new doci-lbal image (4.1)
		exit -4;
	fi 

echo 4.2 start container for ngnx load balancer in CD

docker container rename nginx-${curVer}; 
docker stop nginx-${curVer};

docker run -d --name nginx doci-lbal:${nextVer} || rc=$?; 

	if [[ ${rc} -ne 0 ]]; then
		# roll-back step: 
		echo Rolling back and restarting previous version load balancer nginx-${curVer}
		docker container start nginx-${curVer};
		exit;
	fi 


echo 5. MARIADB - generate doci-db image IS NOT part of script CD, but needed for version sync

cd ./doci-db && docker build -t doci-db:${nextVer} . || rc=$?; 

	if [[ ${rc} -ne 0 ]]; then
		# roll-back step: terminate script 
		echo Failed to generate new doci-db image (5)
		exit -5;
	fi 

docker container rename mariadb-${curVer}; 
docker stop mariadb-${curVer};

docker run -d --name mariadb doci-db:${nextVer} || rc=$?; 

	if [[ ${rc} -ne 0 ]]; then
		# roll-back step: 
		echo restarting previous version mariadb-${curVer}
		docker container start mariadb-${curVer};
		exit;
	fi
	

echo 6. final state updates

echo 6.1 upload new doci-app image to Docker Hub account

docker tag doci-app:${nextVer} sean729/doci-app:${nextVer}
docker push sean729/doci-app:${nextVer}
docker tag doci-app:latest sean729/doci-app:latest
docker push sean729/doci-app:latest

echo 6.2 upload new doci-lbal image to Docker Hub account

docker tag doci-lbal:${nextVer} sean729/doci-lbal:${nextVer}
docker push sean729/doci-lbal:${nextVer}
docker tag doci-lbal:latest sean729/doci-lbal:latest
docker push sean729/doci-lbal:latest

echo 6.3 upload new doci-db image to Docker Hub account

docker tag doci-db:${nextVer} sean729/doci-db:${nextVer}
docker push sean729/doci-db:${nextVer}
docker tag doci-db:latest sean729/doci-db:latest
docker push sean729/doci-db:latest

Ver=${nextVer}

echo "Next version number in var \$Ver is: ${Ver}"

