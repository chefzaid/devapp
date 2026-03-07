FROM node:24-alpine as build
WORKDIR /app
COPY . .
RUN npm ci
RUN npm run build-prod

FROM nginx:alpine
EXPOSE 80
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist/devapp-web/browser /usr/share/nginx/html
