FROM openjdk:11.0.1-jre-slim-stretch
EXPOSE 8080
ARG JAR=hello-observability.jar
COPY target/$JAR /app.jar
COPY opentelemetry-javaagent.jar /opentelemetry-javaagent.jar
ENTRYPOINT ["java","-jar","/app.jar"]
RUN mkdir -p /etc/agent-config
RUN mkdir -p /etc/agent
RUN mkdir -p /tmp/hello-observability
RUN mkdir -p /tmp/access_log

