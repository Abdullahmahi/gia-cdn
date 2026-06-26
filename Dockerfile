# gia-cdn — serves optimized satellite loops AND refreshes them on a schedule.
# Deploy on Coolify (Dockerfile build). Coolify assigns the domain + HTTPS.
FROM nginx:alpine

RUN apk add --no-cache bash ffmpeg gifsicle curl coreutils

COPY refresh-loops.sh /usr/local/bin/refresh-loops.sh
COPY entrypoint.sh /entrypoint.sh
COPY nginx-loops.conf /etc/nginx/conf.d/default.conf
RUN chmod +x /usr/local/bin/refresh-loops.sh /entrypoint.sh

ENV OUT_DIR=/usr/share/nginx/html/loops
EXPOSE 80
CMD ["/entrypoint.sh"]
