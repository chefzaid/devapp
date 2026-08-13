FROM node:24-alpine as build
WORKDIR /app
COPY . .
RUN CYPRESS_INSTALL_BINARY=0 PUPPETEER_SKIP_DOWNLOAD=true npm ci
RUN npm run build-prod

FROM nginxinc/nginx-unprivileged:1.29-alpine
EXPOSE 8080
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist/devapp-web/browser /usr/share/nginx/html
