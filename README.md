# Website to APK

Turn any website into an Android app. Add one small file, push, and GitHub builds the APK. No Android Studio needed.

**Apps in this repo**

| App | Website | Download |
|---|---|---|
| Puzzle Quest | navajowhite-heron-188716.hostingersite.com | [Latest APK](../../releases) |

## Add a new app
Create `apps/<short-name>/app.json`:

```json
{
  "name": "My App",
  "id": "com.yourname.myapp",
  "url": "https://example.com",
  "version": "1.0.0",
  "mode": "auto",
  "pullToRefresh": true,
  "orientation": "any",
  "themeColor": "#0e1230",
  "backgroundColor": "#0e1230"
}
```

Optionally add `apps/<short-name>/icon.png` (1024×1024). Without one, the build uses the site's own icon, or makes one from the app's initials. Push, and the APK appears under **Releases** a few minutes later.

| Setting | What it does |
|---|---|
| `mode` | `offline` bundles a copy of the site in the app, so it works without internet (best for games and tools). `online` opens the live site, always up to date (best for news, shops, WordPress). `auto` tries offline and falls back to online when the site needs a server. |
| `pullToRefresh` | Pull down to reload (online mode) |
| `orientation` | `any`, `portrait` or `landscape` |
| `id` | The Android package name. Keep it the same forever, or phones treat it as a different app. |

Every app also gets:
- an app icon and splash screen
- the back button working inside the site
- downloads and PDFs opening in the right app
- external links opening in the browser or their own apps
- an offline screen in online mode

## Google Play
Add the repository secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` and `ANDROID_KEY_PASSWORD`. Builds are then release-signed and also produce an `.aab` for the Play Console.

Built with the `pwa-from-any-website` and `android-app-from-web-ci` skills from [All Agentic Skills](https://github.com/maheshsurada9434/All-agentic-skills-). By **Mahesh Surada**.
