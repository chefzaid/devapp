FROM eclipse-temurin:21-jre-alpine
VOLUME /tmp
COPY target/order-app.jar .
ENTRYPOINT [ "java", "-jar", "order-app.jar" ]
