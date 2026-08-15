FROM node:24.19.0-alpine@sha256:2a49bdf71e9fd965a58c1703fd9ddd205b34e5782b692a72dd1d248abb0beb43 AS build
WORKDIR /workspace
COPY package.json package-lock.json ./
RUN npm install --global npm@12.0.2
RUN npm ci --ignore-scripts
COPY angular.json tsconfig.json tsconfig.app.json tsconfig.spec.json .browserslistrc ./
COPY src ./src
RUN npm run build-prod

FROM nginxinc/nginx-unprivileged:1.30.4-alpine@sha256:bc69cfff69f75aef06daeda8dea70de95fa9ad97a03fe134cd4e5e6789d51124
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build --chown=101:101 /workspace/dist/devapp-web/browser /usr/share/nginx/html
EXPOSE 8080
