FROM openjdk:21-jre-slim
VOLUME /tmp
COPY target/user-app.jar .
ENTRYPOINT [ "java", "-jar", "user-app.jar" ]
