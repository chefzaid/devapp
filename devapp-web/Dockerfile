FROM node:18 as build
WORKDIR /app
COPY . .
RUN npm install
RUN npm run build --prod

FROM nginx:alpine
EXPOSE 80
COPY --from=build /app/dist/devapp-web /usr/share/nginx/html
