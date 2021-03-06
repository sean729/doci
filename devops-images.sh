#!/bin/bash
# SCRIPTNAME: devops-images.sh
# AUTHOR:     Sean Peterson
# MODifIED:   2019-02-01
# COMMENT:    generate images via dockerfile based on Ubuntu
# CHANGES:    relativized paths 
# VERSION:    0.6

# PREREQS
# docker-ce (18.09.1), docker-compose (1.8.0-2)
# On Kiyoshi-2, Debian 9 Host/Node (running under VirtualBox 5.2.12 for Windows) w/ 1 GB memory
# Directory structure under /root

newVer="1.0.3"

# 1. generate doci-base image not part of script CD pipeline
cd ./doci-base && docker build -t doci-base:${newVer} .


# 2. generate doci-builder image (java 1.8, Maven/springboot) IS NOT part of script CD pipeline
#cd ./doci-builder && docker build -t doci-builder .


# 3. generate doci-app image (java 1.8, Maven/springboot) IS part of script CD pipeline
#cd ./doci-app && docker build -t doci-app:1.0.1 .


# 4. generate doci-lbal image for ngnx load balancer IS NOT part of script CD pipeline
cd ./doci-lbal && docker build -t doci-lbal:${newVer} .


# 5. generate doci-db image IS NOT part of script CD pipeline
cd ./doci-db && docker build -t doci-db:${newVer} .
