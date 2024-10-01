FROM openjdk:17-jre-slim
VOLUME /tmp
COPY target/user-service.jar .
COPY target/order-service.jar .
RUN java -jar service-app.jar
RUN java -jar order-app.jar

RUN apt install nodejs npm nginx
COPY devapp-web/dist/frontend /usr/share/nginx/html
RUN npm install
RUN npm run build --prod

EXPOSE 80

# TODO Should be completed, it just gives the big picture