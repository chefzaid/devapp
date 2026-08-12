FROM eclipse-temurin:25-jre-alpine
VOLUME /tmp
COPY target/order-app.jar .
ENTRYPOINT [ "java", "-jar", "order-app.jar" ]
