FROM maven:3.9.16-amazoncorretto-25-alpine@sha256:8df9a1dbc464977482f726f28a8a1985dcef4e4e68bdda1ae0330711bcb3a192 AS build
WORKDIR /workspace

COPY pom.xml ./
COPY devapp-common/pom.xml devapp-common/pom.xml
COPY user-app/pom.xml user-app/pom.xml
COPY order-app/pom.xml order-app/pom.xml
RUN mvn -B -pl order-app -am dependency:go-offline -DskipTests

COPY devapp-common/src devapp-common/src
COPY order-app/src order-app/src
RUN mvn -B -pl order-app -am package -DskipTests

FROM amazoncorretto:25-alpine@sha256:dc20d7066848919d19d2a7b5f1f4e2a48f8e32fc7328a5ae683d579bafa2f818
RUN addgroup -S -g 10001 app && adduser -S -D -H -u 10001 -G app app
WORKDIR /app
COPY --from=build --chown=10001:10001 /workspace/order-app/target/order-app.jar ./order-app.jar
USER 10001:10001
EXPOSE 8081
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75.0", "-jar", "order-app.jar"]
