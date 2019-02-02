FROM java:8-alpine

RUN mkdir -p /opt/devops
COPY ./target/*.jar /opt/devops/app.jar

WORKDIR /opt/devops

CMD ["java","-jar","app.jar"]
