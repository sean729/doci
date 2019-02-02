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
docker pull sean729/$nameImage:latest 

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


# 2. start container with doci-builder image to generate new doci-app image for Ci/CD

#start container for CI, call/trigger Maven script to build Spring app (docker in docker??) 
docker run -d --name maven doci-builder:latest
docker exec -it maven 'cd /home/rauccapu/maven/repo/devops-docker && git pull origin master'
docker exec -it maven 'cd /home/rauccapu/maven/repo/devops-docker && mvn clean test && mvn clean package && mvn '


# 3. run containers based on image doci-app (java 1.8, springboot) for CD
# cd /root/images/doci-app && docker build -t doci-app .

R=$autoScale

while [ "$R" -ne 0 ]; 
do 
	docker stop sprboot$R || exit -1;
	docker container rename sprboot${R} sprboot$[R}-${curVer}; 
	docker run -d --name sprboot$R doci-app:${nextVer} || rc=$?; 

	if [[ ${rc} -ne 0 ]]; then
		# roll-back step: restart last version 
		O=$autoScale; 
		while [ "$O" -ne 0 ]; 
		do
			docker container stop sprboot${O}
			docker container start sprboot${O}-${curVer};
			if [[ "$O" == "$R" ]]; then
				O="0"
			else 
				O=$[O-1];
			fi
		done
		exit -3;
	fi 
	R=$[R-1]; 
done

# 3.1 get IP address of each sprboot container and update load balance config file (nginx)

R=$autoScale
while [ "$R" -ne 0 ]; 
do 
	export "IPA$R"=$(docker container inspect "sprboot$R" | jq .[0].NetworkSettings.Networks.doci_default.IPAddress | sed "s/\"//g"); 
	if [[ $IPA$R -eq null ]]; then 
		# roll-back step: terminate script 
		echo Halted deployment at step 3.1 - Failed to obtain IP address of container sprboot$R; 
		exit -1; 
	fi
	R=$[R-1]; 
done 


# 4. NGINX - update the IP Addresses in /root/images/doci-lbal/hosts-apptier.conf

R=$autoScale
while [ "$R" -ne 0 ]; 
do
	sed -i "/sprboot$R/!{q10}; s/sprboot$R/$IPA$R/" ./doci-lbal/default-nginx.conf || rc=$?; 

	if [[ ${rc} -ne 0 ]]; then
		# roll-back step: terminate script 
		echo Halted deployment at step 4 - Unable to update nginx config for load balancing
		exit;
	fi 
	R=$[R-1]; 
done

# 4.1 generate new doci-lbal image 

cd ./doci-lbal && docker build -t doci-lbal:${nextVer} . || rc=$?; 

	if [[ ${rc} -ne 0 ]]; then
		# roll-back step: terminate script 
		echo Failed to generate new doci-lbal image (4.1)
		exit -4;
	fi 

# 4.2 start container for ngnx load balancer in CD

docker container rename nginx-${curVer}; 
docker stop nginx-${curVer};

docker run -d --name nginx doci-lbal:${nextVer} || rc=$?; 

	if [[ ${rc} -ne 0 ]]; then
		# roll-back step: 
		echo restarted previous version load balancer nginx-${curVer}
		docker container start nginx-${curVer};
		exit;
	fi 


# 5. MARIADB - generate doci-db image IS NOT part of script CD, but needed for version sync

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
	

# 6. final state updates

# 6.1 upload new doci-app image to Docker Hub account

docker tag doci-app:${nextVer} sean729/doci-app:${nextVer}
docker push sean729/doci-app:${nextVer}
docker tag doci-app:latest sean729/doci-app:latest
docker push sean729/doci-app:latest

# 6.2 upload new doci-lbal image to Docker Hub account

docker tag doci-lbal:${nextVer} sean729/doci-lbal:${nextVer}
docker push sean729/doci-lbal:${nextVer}
docker tag doci-lbal:latest sean729/doci-lbal:latest
docker push sean729/doci-lbal:latest

# 6.3 upload new doci-db image to Docker Hub account

docker tag doci-db:${nextVer} sean729/doci-db:${nextVer}
docker push sean729/doci-db:${nextVer}
docker tag doci-db:latest sean729/doci-db:latest
docker push sean729/doci-db:latest

Ver=${nextVer}

echo "Next version number in var \$Ver is: ${Ver}"

