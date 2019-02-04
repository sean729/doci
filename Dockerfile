FROM doci-base:1.0.3

RUN \
	apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* 
	
RUN mkdir -p /opt/devops

COPY ./target/*.jar /opt/devops/app.jar

RUN ls -l /opt/devops

WORKDIR /opt/devops

CMD ["java","-jar","app.jar"]
