# gia-cdn — self-hosted animated loops on Hetzner

Goal: serve email-friendly **animated** satellite loops at stable URLs like
`https://cdn.gia-usa.com/loops/mexpac-latest.gif`, so the bulletin shows real motion
without the 11-28 MB raw NOAA files. A cron job keeps them fresh; editions just
embed the stable URL.

```
NOAA/NESDIS loop (11-28 MB)  ->  refresh-loops.sh (ffmpeg+gifsicle, ~1 MB)  ->  /var/www/cdn/loops/<name>-latest.gif  ->  cdn.gia-usa.com  ->  embedded in the bulletin
```

Loops configured today (US-gov, public domain):
- `mexpac-latest.gif` — GOES-East "mex" sector, Mexico-centered (Pacific coast ports: Vallarta, Cabo, Acapulco, Mazatlán, Manzanillo).
- `caribbean-latest.gif` — GOES-East, Caribbean (Cancún/Cozumel, Florida, Bahamas).

(Outlook **desktop** shows only the first frame of any GIF — an Outlook limitation.
Apple Mail, Gmail, and webmail animate normally.)

---

## Deploy with Coolify (recommended)

Coolify handles the domain, HTTPS, and reverse proxy automatically. The container
here both **serves** the loops and **refreshes** them every 30 min (built-in cron),
so there's nothing else to schedule.

1. **DNS:** add an A record `cdn.gia-usa.com -> <your server IP>` (the box Coolify runs on).
2. In Coolify: **New Resource -> Application**. Source = this `gia-cdn/` folder
   (push it to a Git repo Coolify can read, or use a private repo / "Dockerfile" deploy).
   Set **Build Pack = Dockerfile**.
3. Set the **Domain** to `https://cdn.gia-usa.com` and **Port = 80`. Coolify issues
   the TLS cert automatically.
4. **Deploy.** On boot the container generates `mexpac-latest.gif` + `caribbean-latest.gif`
   and serves them; cron refreshes every 30 min.
5. **Verify:** open `https://cdn.gia-usa.com/loops/mexpac-latest.gif` — it should load
   and animate. (`https://cdn.gia-usa.com/` returns `gia-cdn ok`.)

Tuning (size/quality) is set via env vars in Coolify (WIDTH/FPS/LOSSY/COLORS, see below);
no rebuild needed for source-URL or schedule changes beyond a redeploy.

Files used by this deploy: `Dockerfile`, `entrypoint.sh`, `nginx-loops.conf`, `refresh-loops.sh`.

---

## Alternative: manual nginx on the VPS

### 1. DNS
Add an **A record**: `cdn.gia-usa.com  ->  <your Hetzner IP>` (at Network Solutions / Web.com).

### 2. Install tools
```bash
sudo apt-get update && sudo apt-get install -y nginx ffmpeg gifsicle curl certbot python3-certbot-nginx
```

### 3. Web root + script
```bash
sudo mkdir -p /var/www/cdn/loops /var/www/gia-cdn
sudo cp refresh-loops.sh /var/www/gia-cdn/ && sudo chmod +x /var/www/gia-cdn/refresh-loops.sh
```

### 4. nginx server block  (`/etc/nginx/sites-available/cdn.gia-usa.com`)
```nginx
server {
    server_name cdn.gia-usa.com;
    root /var/www/cdn;
    location /loops/ {
        add_header Cache-Control "public, max-age=900";   # 15 min
        add_header Access-Control-Allow-Origin "*";
        try_files $uri =404;
    }
}
```
```bash
sudo ln -s /etc/nginx/sites-available/cdn.gia-usa.com /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
sudo certbot --nginx -d cdn.gia-usa.com         # TLS (https)
```

### 5. First run + cron
```bash
sudo /var/www/gia-cdn/refresh-loops.sh           # generates the first GIFs
ls -lh /var/www/cdn/loops/                        # confirm ~1 MB files
# then schedule every 30 min:
( crontab -l 2>/dev/null; echo "*/30 * * * * /var/www/gia-cdn/refresh-loops.sh >> /var/log/gia-loops.log 2>&1" ) | crontab -
```

### 6. Verify from anywhere
```
https://cdn.gia-usa.com/loops/mexpac-latest.gif
https://cdn.gia-usa.com/loops/caribbean-latest.gif
```
Both should load and animate, each ~1 MB.

---

## Tuning size/quality
Env vars override defaults (in the cron line or shell):
- `WIDTH` (default 440) — output width in px
- `FPS` (default 5) — frame rate
- `LOSSY` (default 100) — higher = smaller/grainier
- `COLORS` (default 64) — palette size; fewer = smaller
Target ~1 MB per loop. Example (smaller): `WIDTH=400 FPS=4 LOSSY=120 /var/www/gia-cdn/refresh-loops.sh`

## Adding / changing regions
Edit the `LOOPS=(...)` array in `refresh-loops.sh`. Use **US-gov** sources only
(noaa.gov / star.nesdis.noaa.gov). To find a sector's loop URL, the pattern is
`https://cdn.star.nesdis.noaa.gov/<GOES18|GOES19>/ABI/SECTOR/<sector>/GEOCOLOR/<GOESxx>-<SECTOR>-GEOCOLOR-<size>.gif`.

---

## Once it's live
Tell me the loops are serving and I'll switch the bulletin plates (and the 10 AM
task) from the static still to the hosted loop URL, so every edition animates.
