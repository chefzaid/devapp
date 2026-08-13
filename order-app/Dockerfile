FROM eclipse-temurin:25-jre-alpine
RUN addgroup -S -g 10001 app && adduser -S -D -H -u 10001 -G app app
WORKDIR /app
VOLUME /tmp
COPY --chown=10001:10001 target/order-app.jar .
USER 10001:10001
ENTRYPOINT [ "java", "-jar", "order-app.jar" ]
