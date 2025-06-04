FROM openjdk:21-jre-slim
VOLUME /tmp
COPY target/order-app.jar .
ENTRYPOINT [ "java", "-jar", "order-app.jar" ]
