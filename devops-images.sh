#!/bin/bash
# SCRIPTNAME: devops-images.sh
# AUTHOR:     Sean Peterson
# MODifIED:   2019-02-01
# COMMENT:    generate images via dockerfile based on Ubuntu
# CHANGES:    Final version 
# VERSION:    0.4

# PREREQS
# docker-ce (18.09.1), docker-compose (1.8.0-2)
# On Kiyoshi-2, Debian 9 Host/Node (running under VirtualBox 5.2.12 for Windows) w/ 1 GB memory
# Directory structure under /root


# 1. generate doci-base image not part of script CD pipeline
cd /root/images/doci-base && docker build -t doci-base .


# 2. generate doci-builder image (java 1.8, Maven/springboot) IS NOT part of script CD pipeline
cd /root/images/doci-builder && docker build -t doci-builder .


# 3. generate doci-app image (java 1.8, Maven/springboot) IS part of script CD pipeline
cd /root/images/doci-app && docker build -t doci-app:1.0.1 .


# 4. generate doci-lbal image for ngnx load balancer IS NOT part of script CD pipeline
cd /root/images/doci-lbal && docker build -t doci-lbal .


# 5. generate doci-db image IS NOT part of script CD pipeline
cd /root/images/doci-db && docker build -t doci-db:latest .
