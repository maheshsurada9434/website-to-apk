#!/usr/bin/env bash
# Downloads a website's pages, scripts, styles and images into a folder so the app works offline.
# Usage: fetch-site.sh <url> <out-dir>     Exit code 0 = a usable copy with index.html.
set -uo pipefail
URL="${1%/}"; OUT="$2"
rm -rf "$OUT" && mkdir -p "$OUT"
HOST=$(echo "$URL" | sed -E 's#https?://([^/]+).*#\1#')
wget -q -e robots=off --timeout=30 --tries=2 -r -l 3 -p -E -k -np -nH \
  --domains="$HOST" -U "Mozilla/5.0 (Linux; Android 14) WebsiteToApk" -P "$OUT" "$URL/" || true
# Some hosts send index without the .html name
[ -f "$OUT/index.html" ] || { f=$(ls "$OUT"/*.html 2>/dev/null | head -1); [ -n "$f" ] && cp "$f" "$OUT/index.html"; }
if [ ! -s "$OUT/index.html" ] || [ "$(wc -c < "$OUT/index.html")" -lt 400 ]; then echo "fetch: no usable index.html"; exit 1; fi
# Server-side pages (PHP, WordPress, logins) can't run offline
if grep -qiE 'wp-content|wp-json|\.php|action="/|login' "$OUT/index.html"; then echo "fetch: site needs a server"; exit 2; fi
echo "fetch: $(find "$OUT" -type f | wc -l) files, $(du -sh "$OUT" | cut -f1)"
