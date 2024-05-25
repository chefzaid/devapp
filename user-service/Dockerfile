FROM openjdk:17-jre-slim
VOLUME /tmp
COPY target/user-service.jar app.jar
ENTRYPOINT ["java","-jar","/app.jar"]