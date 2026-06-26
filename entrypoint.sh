#!/bin/sh
# Generate the loops once on boot, then refresh every 30 min via cron, and serve via nginx.
set -e

OUT_DIR="${OUT_DIR:-/usr/share/nginx/html/loops}"
mkdir -p "$OUT_DIR"

echo "[entrypoint] initial loop generation..."
OUT_DIR="$OUT_DIR" /usr/local/bin/refresh-loops.sh || echo "[entrypoint] initial run failed (will retry on schedule)"

# refresh every 30 minutes
echo "*/30 * * * * OUT_DIR=$OUT_DIR /usr/local/bin/refresh-loops.sh >> /var/log/loops.log 2>&1" > /etc/crontabs/root
crond                       # busybox cron daemon (background)

echo "[entrypoint] serving on :80"
exec nginx -g 'daemon off;'
