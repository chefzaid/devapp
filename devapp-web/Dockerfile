FROM nginxinc/nginx-unprivileged@sha256:0c79d56aee561a1d81c63f00eee5fb5fe29279560cdc55e91425133104c7fbe6
EXPOSE 8080
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --chown=101:101 dist/devapp-web/browser /usr/share/nginx/html
