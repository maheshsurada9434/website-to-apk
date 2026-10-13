#!/usr/bin/env bash
# Builds one app: scripts/build-app.sh <app-folder-name>   Output: dist/<name>.apk
# Modes (app.json "mode"):
#   offline  bundle a copy of the website inside the app (works without internet)
#   online   open the live website (always up to date, needs internet)
#   auto     try offline; if the site needs a server (PHP, WordPress, logins), use online
set -euo pipefail
cd "$(dirname "$0")/.."
APP="$1"; DIR="apps/$APP"
[ -f "$DIR/app.json" ] || { echo "No $DIR/app.json"; exit 1; }
j() { node -p "const c=require('./$DIR/app.json'); c['$1'] ?? '${2:-}'"; }
NAME=$(j name); ID=$(j id); URL=$(j url); VERSION=$(j version 1.0.0); MODE=$(j mode auto)
PULL=$(j pullToRefresh true); ORIENT=$(j orientation any); BG=$(j backgroundColor '#ffffff')
VERSION_CODE=${VERSION_CODE:-1}
echo "== $NAME $VERSION ($VERSION_CODE) $ID from $URL, mode $MODE"

[ -d node_modules ] || npm install --no-audit --no-fund
python3 -c "import PIL" 2>/dev/null || python3 -m pip install --quiet --break-system-packages pillow 2>/dev/null || python3 -m pip install --quiet pillow
rm -rf www android assets
python3 scripts/make-assets.py "$DIR"
ACCENT=$(node -p "require('./assets/colors.json').accent"); ICONBG=$(node -p "require('./assets/colors.json').iconBackground")

USED=online
if [ "$MODE" != "online" ]; then
  if bash scripts/fetch-site.sh "$URL" www; then USED=offline
  elif [ "$MODE" = "offline" ]; then echo "Could not make an offline copy of $URL"; exit 1
  else echo "== Falling back to online mode"; fi
fi
if [ "$USED" = online ]; then
  rm -rf www && mkdir -p www
  sed -e "s#__URL__#$URL#g" -e "s#__NAME__#$NAME#g" -e "s#__BG__#$BG#g" -e "s#__ACCENT__#$ACCENT#g" templates/offline.html > www/offline.html
  printf '<!doctype html><meta http-equiv="refresh" content="0;url=%s">' "$URL" > www/index.html
fi
echo "== Mode used: $USED"

HOST=$(echo "$URL" | sed -E 's#https?://([^/]+).*#\1#')
node -e '
const [id, name, url, host, used, bg, ver] = process.argv.slice(1);
const c = { appId: id, appName: name, webDir: "www", backgroundColor: bg,
  android: { allowMixedContent: false, webContentsDebuggingEnabled: false, appendUserAgent: "WebsiteToApk/" + ver },
  plugins: { SplashScreen: { launchShowDuration: 900, backgroundColor: bg, showSpinner: false } } };
if (used === "online") c.server = { url, allowNavigation: [host, "*." + host], errorPath: "offline.html", androidScheme: "https" };
require("fs").writeFileSync("capacitor.config.json", JSON.stringify(c, null, 2));
' "$ID" "$NAME" "$URL" "$HOST" "$USED" "$BG" "$VERSION"

npx cap add android
npx @capacitor/assets generate --android --iconBackgroundColor "$ICONBG" --iconBackgroundColorDark "$ICONBG" \
  --splashBackgroundColor "$BG" --splashBackgroundColorDark "$BG"
PKG_DIR="android/app/src/main/java/$(echo "$ID" | tr . /)"; mkdir -p "$PKG_DIR"
[ "$USED" = online ] && [ "$PULL" = true ] && P=true || P=false
sed -e "s/__PACKAGE__/$ID/" -e "s/__ACCENT__/$ACCENT/" -e "s/__PULL__/$P/" native/MainActivity.java > "$PKG_DIR/MainActivity.java"
mkdir -p ~/.android && cp ci/debug.keystore ~/.android/debug.keystore

python3 - "$VERSION" "$VERSION_CODE" "$NAME" "$ORIENT" <<'PY'
import re, sys, os
name, code, app, orient = sys.argv[1:5]
p = 'android/app/build.gradle'; s = open(p).read()
s = re.sub(r'versionCode\s+\d+', f'versionCode {code}', s)
s = re.sub(r'versionName\s+"[^"]*"', f'versionName "{name}"', s)
if 'swiperefreshlayout' not in s:
    s = s.replace('dependencies {', 'dependencies {\n    implementation "androidx.swiperefreshlayout:swiperefreshlayout:1.1.0"', 1)
open(p, 'w').write(s)
if orient in ('portrait', 'landscape'):
    m = 'android/app/src/main/AndroidManifest.xml'; x = open(m).read()
    if 'screenOrientation' not in x:
        x = x.replace('<activity', f'<activity\n            android:screenOrientation="{orient}"', 1)
    open(m, 'w').write(x)
PY

npx cap sync android
SIGN=0; [ -n "${ANDROID_KEYSTORE_BASE64:-}" ] && SIGN=1
( cd android && chmod +x gradlew && if [ $SIGN = 1 ]; then ./gradlew --no-daemon assembleRelease bundleRelease; else ./gradlew --no-daemon assembleDebug; fi )
mkdir -p dist
if [ $SIGN = 1 ]; then
  KS="${RUNNER_TEMP:-/tmp}/release.jks"; echo "$ANDROID_KEYSTORE_BASE64" | base64 -d > "$KS"
  export KSP="$ANDROID_KEYSTORE_PASSWORD" KP="${ANDROID_KEY_PASSWORD:-$ANDROID_KEYSTORE_PASSWORD}"
  BT=$(ls -d "$ANDROID_HOME"/build-tools/* | sort -V | tail -1)
  "$BT/zipalign" -p -f 4 android/app/build/outputs/apk/release/app-release-unsigned.apk /tmp/aligned.apk
  "$BT/apksigner" sign --ks "$KS" --ks-key-alias "$ANDROID_KEY_ALIAS" --ks-pass env:KSP --key-pass env:KP --out "dist/$APP.apk" /tmp/aligned.apk
  jarsigner -sigalg SHA256withRSA -digestalg SHA-256 -keystore "$KS" -storepass "$KSP" -keypass "$KP" -signedjar "dist/$APP.aab" android/app/build/outputs/bundle/release/app-release.aab "$ANDROID_KEY_ALIAS"
  rm -f "$KS"
else
  cp android/app/build/outputs/apk/debug/app-debug.apk "dist/$APP.apk"
fi
cp assets/icon-only.png "dist/$APP-icon.png"
{ echo "app: $NAME ($ID)"; echo "site: $URL"; echo "mode: $USED"; echo "version: $VERSION ($VERSION_CODE)"; echo "signed: $([ $SIGN = 1 ] && echo yes || echo no)";
  grep -E "minSdkVersion|targetSdkVersion" android/variables.gradle; } > "dist/$APP-info.txt"
cat "dist/$APP-info.txt"
