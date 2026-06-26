#!/usr/bin/env bash
#
# refresh-loops.sh — runs inside the Coolify container.
# Downloads NOAA/NESDIS animated satellite loops, shrinks each to an
# email-friendly ~1 MB GIF, and publishes it at a STABLE path so the bulletin
# can always embed e.g. https://cdn.gia-usa.com/loops/mexpac-latest.gif
#
# Why: NESDIS loops are 11-28 MB (too heavy for email). We re-host an optimized
# copy on our own CDN. Only US-gov (public-domain) sources are used here.
#
# Requires: curl, ffmpeg, gifsicle. The Dockerfile installs these for Coolify.
#
# Manual VPS cron example (every 30 min):
#   */30 * * * * OUT_DIR=/var/www/cdn/loops /var/www/gia-cdn/refresh-loops.sh >> /var/log/gia-loops.log 2>&1

set -euo pipefail

OUT_DIR="${OUT_DIR:-/usr/share/nginx/html/loops}"   # served at https://cdn.gia-usa.com/loops/
WIDTH="${WIDTH:-440}"                        # output width in px
FPS="${FPS:-5}"                              # output frame rate
LOSSY="${LOSSY:-100}"                        # gifsicle lossy level (higher = smaller)
COLORS="${COLORS:-64}"                       # palette colors (fewer = smaller)
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# name | source loop URL  (US-gov public-domain only)
# mexpac = GOES-East "mex" sector, Mexico-centered (covers the Pacific coast ports:
#          Vallarta, Cabo, Acapulco, Mazatlan, Manzanillo) — the right view for this book.
# caribbean = GOES-East "car" sector (Cancun/Cozumel, Florida, Bahamas).
LOOPS=(
  "mexpac|https://cdn.star.nesdis.noaa.gov/GOES19/ABI/SECTOR/mex/GEOCOLOR/GOES19-MEX-GEOCOLOR-1000x1000.gif"
  "caribbean|https://cdn.star.nesdis.noaa.gov/GOES19/ABI/SECTOR/car/GEOCOLOR/GOES19-CAR-GEOCOLOR-1000x1000.gif"
)

mkdir -p "$OUT_DIR"

for entry in "${LOOPS[@]}"; do
  name="${entry%%|*}"
  url="${entry#*|}"
  src="$TMP/$name-src.gif"
  pal="$TMP/$name-pal.png"
  opt="$TMP/$name.gif"

  echo "[$(date -u +%FT%TZ)] $name: downloading"
  if ! curl -fsSL --max-time 120 -o "$src" "$url"; then
    echo "  ! download failed, keeping previous $name-latest.gif"; continue
  fi

  # 1) re-encode at lower fps + width with a good palette (ffmpeg)
  ffmpeg -y -loglevel error -i "$src" \
    -vf "fps=${FPS},scale=${WIDTH}:-1:flags=lanczos,palettegen=max_colors=${COLORS}" "$pal"
  ffmpeg -y -loglevel error -i "$src" -i "$pal" \
    -lavfi "fps=${FPS},scale=${WIDTH}:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=3" "$opt"

  # 2) squeeze further (gifsicle)
  gifsicle -O3 --lossy="${LOSSY}" "$opt" -o "$opt.min" 2>/dev/null || cp "$opt" "$opt.min"

  size=$(stat -c%s "$opt.min" 2>/dev/null || stat -f%z "$opt.min")
  # 3) publish atomically to the stable path
  mv "$opt.min" "$OUT_DIR/$name-latest.gif"
  echo "  -> published $OUT_DIR/$name-latest.gif ($((size/1024)) KB)"
done

echo "[$(date -u +%FT%TZ)] done."
