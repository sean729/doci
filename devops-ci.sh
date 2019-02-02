#!/bin/bash
# SCRIPTNAME: devops-ci.sh
# AUTHOR:     Sean Peterson
# MODifIED:   2019-02-01
# COMMENT:    trigger CI and handle results
#             upload images to docker hub
#             deploy containers based on images
# CHANGES:    Initial version with header
# VERSION:    0.23

# PREREQS
# host must have package jq

# CONTROLS
set -o errexit
#set -o xtrace


# VARIABLES

nameImage="doci-app" # SAMPLE doci-app:1.0.0

docker pull sean729/$nameImage:latest 

verImage=$(docker image inspect $nameImage:latest | jq .[0] | jq .RepoTags[0] | sed "s/\"//g")
lenImage=${#verImage}
curVer=${verImage:$[lenImage-5]:$lenImage}

echo "Image current version tag is: ${curVer}"


Maj=${curVer:0:1}
Min=${curVer:2:1}
Rel=${curVer:4:1}


echo "Starting values for numbers Maj Min Rel: ${Maj} ${Min} ${Rel}"

function _incrVersion () { # Base 10 version counter

	if [[ "${3}" == 9 ]];
	then nRel="0"
		if [[ "${2}" == 9 ]];
		then nMin="0"
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

echo "Next version is: ${nextVer}"



# 1. generate doci-base image shall be commented out, not part of script CD


# 2. start doci-builder containers CD

#start container for CI, call/trigger Maven script to build Spring app (docker in docker??) 
docker run -d --name maven doci-builder:latest
docker exec -it maven 'cd /home/rauccapu/maven/repo/devops-docker && git pull origin master'
docker exec -it maven 'cd /home/rauccapu/maven/repo/devops-docker && mvn clean test && mvn clean package && mvn '

# 3. run containers based on image doci-app (java 1.8, springboot) for CD
# cd /root/images/doci-app && docker build -t doci-app .

docker run -d --name sprboot1 doci-app:latest
docker run -d --name sprboot2 doci-app:latest
docker run -d --name sprboot3 doci-app:latest

# 3.1 get each IP address
IPA1=(docker inspect sprboot1 | jq .[0].NetworkSettings.Networks.devopsdocker_default.IPAddress | sed "s/\"//g")
IPA2=(docker inspect sprboot2 | jq .[0].NetworkSettings.Networks.devopsdocker_default.IPAddress | sed "s/\"//g")
IPA3=(docker inspect sprboot3 | jq .[0].NetworkSettings.Networks.devopsdocker_default.IPAddress | sed "s/\"//g")


# 4. update the IP Addresses in /root/images/doci-lbal/hosts-apptier.conf
sed -i "s/sprboot1/$IPA1/" /root/images/doci-lbal/default-nginx.conf
sed -i "s/sprboot2/$IPA2/" /root/images/doci-lbal/default-nginx.conf
sed -i "s/sprboot3/$IPA3/" /root/images/doci-lbal/default-nginx.conf


# 4.1 New image doci-lbal and start container for ngnx load balancer in CD
cd /root/images/doci-lbal && docker build -t doci-lbal:${nextVer} .
docker run -d --name nginx doci-lbal:latest


# 5. generate doci-db image IS NOT part of script CD
docker run -d --name mariadb doci-db:latest


# Final state updates
Ver=${nextVer}

echo "Next version number in var \$Ver is: ${Ver}"


