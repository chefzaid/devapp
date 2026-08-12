FROM eclipse-temurin:25-jre-alpine
VOLUME /tmp
COPY target/user-app.jar .
ENTRYPOINT [ "java", "-jar", "user-app.jar" ]
