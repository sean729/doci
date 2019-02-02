# Location ./doci-maven (+15 MB)

FROM doci-base:latest

RUN \
  echo exit 0 > /usr/sbin/policy-rc.d && \
  apt-get update && \
  mkdir /usr/lib/mvn

RUN apt-get install -y ca-certificates git openjdk-8-jre wget    && \
  apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
  find /usr/share/ca-certificates/mozilla/ -name "*.crt" -exec keytool -import -trustcacerts \
  -keystore /etc/ssl/certs/java/cacerts -storepass changeit -noprompt \
  -file {} -alias {} \; && \
  keytool -list -keystore /etc/ssl/certs/java/cacerts --storepass changeit

ENV MAVEN_VERSION 3.5.2
ENV MAVEN_HOME /usr/lib/mvn
ENV PATH $MAVEN_HOME/bin:$PATH

RUN wget http://archive.apache.org/dist/maven/maven-3/$MAVEN_VERSION/binaries/apache-maven-$MAVEN_VERSION-bin.tar.gz && \
  tar -zxvf apache-maven-$MAVEN_VERSION-bin.tar.gz && \
  rm apache-maven-$MAVEN_VERSION-bin.tar.gz   && \
  mv apache-maven-$MAVEN_VERSION /usr/lib/mvn && \
  ls -l /usr/lib/mvn
  
RUN git config --global user.email "sean729@gmail.com"
RUN git config --global user.name "Sean Peterson"
RUN mkdir -p /usr/src/app

WORKDIR /usr/src/app

COPY entrypoint.sh /

RUN chmod +x /entrypoint.sh && ls -l /

ENTRYPOINT ["/entrypoint.sh"]
