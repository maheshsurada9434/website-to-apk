"""Makes the app icon, adaptive icon and splash screens for one app.

Icon, in order of preference: apps/<id>/icon.png, the URLs in "iconSources", the site's own
apple-touch-icon / favicon, or a generated icon with the app's initials.
Usage: python3 scripts/make-assets.py apps/<id>
"""
import io, json, os, sys, urllib.request, urllib.parse
from PIL import Image, ImageDraw, ImageFilter, ImageFont

app_dir = sys.argv[1]
cfg = json.load(open(os.path.join(app_dir, 'app.json')))
url = cfg['url'].rstrip('/')
hexrgb = lambda h: tuple(int(h.lstrip('#')[i:i + 2], 16) for i in (0, 2, 4))
bg = hexrgb(cfg.get('backgroundColor', cfg.get('themeColor', '#ffffff')))

def fetch(u):
    try:
        req = urllib.request.Request(u, headers={'User-Agent': 'Mozilla/5.0 (Linux; Android 14) WebsiteToApk'})
        im = Image.open(io.BytesIO(urllib.request.urlopen(req, timeout=30).read())); im.load()
        if min(im.size) < 96: raise ValueError('too small')
        print('icon from', u, im.size); return im.convert('RGBA')
    except Exception as e:
        print('skip', u, e); return None

icon = None
local = os.path.join(app_dir, 'icon.png')
if os.path.exists(local): icon = Image.open(local).convert('RGBA'); print('icon from', local)
for u in cfg.get('iconSources', []):
    icon = icon or fetch(u)
for p in ['/apple-touch-icon.png', '/icon-512.png', '/icons/icon-512.png', '/android-chrome-512x512.png', '/favicon.png']:
    icon = icon or fetch(url + p)
if icon is None:
    print('generating an icon from the app name')
    S = 1024; icon = Image.new('RGBA', (S, S), bg + (255,)); d = ImageDraw.Draw(icon)
    letters = ''.join(w[0] for w in cfg['name'].split()[:2]).upper()
    import glob
    fp = (glob.glob('/usr/share/fonts/**/DejaVuSans-Bold.ttf', recursive=True) + glob.glob('/usr/share/fonts/**/*Bold*.ttf', recursive=True) + [None])[0]
    f = ImageFont.truetype(fp, 420) if fp else ImageFont.load_default()
    bb = d.textbbox((0, 0), letters, font=f)
    d.text(((S - bb[2] - bb[0]) / 2, (S - bb[3] - bb[1]) / 2), letters, font=f, fill=(255, 255, 255, 255))

def accent(im):
    best, score = (37, 99, 235), -1
    for r, g, b, a in list(im.resize((64, 64)).getdata()):
        if a < 200: continue
        mx, mn = max(r, g, b), min(r, g, b); s = (mx - mn) / (mx or 1) * (1 - abs(mx / 255 - 0.6))
        if s > score: best, score = (r, g, b), s
    return '#%02x%02x%02x' % best

def full_bleed(im):
    w, h = im.size
    return all(im.getpixel(p)[3] > 240 for p in [(1, 1), (w - 2, 1), (1, h - 2), (w - 2, h - 2)])

def fit(im, w, h):
    r = min(w / im.width, h / im.height)
    return im.resize((max(1, int(im.width * r)), max(1, int(im.height * r))), Image.LANCZOS)

os.makedirs('assets', exist_ok=True)
S = 1024
if full_bleed(icon):
    sq = icon.resize((S, S), Image.LANCZOS)
    sq.save('assets/icon-only.png')
    # adaptive icon: the same art, scaled into the safe zone, over its own edge colour
    fg = Image.new('RGBA', (S, S), (0, 0, 0, 0)); inner = fit(icon, int(S * .78), int(S * .78))
    fg.paste(inner, ((S - inner.width) // 2, (S - inner.height) // 2), inner)
    icon_bg = sq.getpixel((4, S // 2))[:3]
else:
    art = fit(icon, int(S * .64), int(S * .64)); sq = Image.new('RGBA', (S, S), bg + (255,))
    sq.paste(art, ((S - art.width) // 2, (S - art.height) // 2), art); sq.save('assets/icon-only.png')
    fg = Image.new('RGBA', (S, S), (0, 0, 0, 0)); a2 = fit(icon, int(S * .56), int(S * .56))
    fg.paste(a2, ((S - a2.width) // 2, (S - a2.height) // 2), a2); icon_bg = bg
fg.save('assets/icon-foreground.png')
Image.new('RGBA', (S, S), icon_bg + (255,)).save('assets/icon-background.png')

# Splash: rounded icon with a soft glow, centred on the app background
W = 2732; sp = Image.new('RGBA', (W, W), bg + (255,))
ic = sq.resize((560, 560), Image.LANCZOS)
mask = Image.new('L', ic.size, 0); ImageDraw.Draw(mask).rounded_rectangle([0, 0, ic.width - 1, ic.height - 1], radius=130, fill=255)
glow = Image.new('RGBA', (W, W), (0, 0, 0, 0)); ImageDraw.Draw(glow).ellipse([W // 2 - 520, W // 2 - 520, W // 2 + 520, W // 2 + 520], fill=hexrgb(accent(icon)) + (90,))
sp = Image.alpha_composite(sp, glow.filter(ImageFilter.GaussianBlur(160)))
sp.paste(ic, ((W - ic.width) // 2, (W - ic.height) // 2), mask)
sp.convert('RGB').save('assets/splash.png'); sp.convert('RGB').save('assets/splash-dark.png')

json.dump({'accent': accent(icon), 'iconBackground': '#%02x%02x%02x' % icon_bg}, open('assets/colors.json', 'w'))
print('accent', accent(icon))
