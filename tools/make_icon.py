# Gera os icones do jogo (arte propria, procedural). Uso: python3 tools/make_icon.py
from PIL import Image, ImageDraw, ImageFilter
import math, random, os
random.seed(7)
def make(size, fg_only=False, bg_only=False):
    S = size * 4
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if not fg_only:
        for y in range(S):
            t = y / S
            r = int(26 + (214 - 26) * t ** 1.6); g = int(30 + (112 - 30) * t ** 1.9); b = int(48 + (58 - 48) * t)
            d.line([(0, y), (S, y)], fill=(r, g, b, 255))
        cx, cy, rad = S * 0.5, S * 0.60, S * 0.17
        d.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], fill=(255, 196, 120, 255))
    if not bg_only:
        # pinheiros
        for i, (px, h, w) in enumerate([(0.14, 0.50, 0.17), (0.30, 0.36, 0.13), (0.86, 0.54, 0.18), (0.70, 0.38, 0.13)]):
            base = S * 0.86; x = S * px
            for k in range(5):
                yy = base - S * h * (k / 5.0); ww = S * w * (1 - k / 6.0)
                d.polygon([(x - ww / 2, yy), (x + ww / 2, yy), (x, yy - S * h * 0.42)], fill=(14, 20, 22, 255))
        # figura do sobrevivente
        fx, fy = S * 0.5, S * 0.86
        col = (10, 13, 15, 255)
        d.ellipse([fx - S * 0.045, fy - S * 0.44, fx + S * 0.045, fy - S * 0.35], fill=col)
        d.rounded_rectangle([fx - S * 0.07, fy - S * 0.34, fx + S * 0.07, fy - S * 0.15], radius=S * 0.02, fill=col)
        d.rectangle([fx - S * 0.065, fy - S * 0.16, fx - S * 0.012, fy], fill=col)
        d.rectangle([fx + S * 0.012, fy - S * 0.16, fx + S * 0.065, fy], fill=col)
        d.rounded_rectangle([fx - S * 0.10, fy - S * 0.33, fx - S * 0.07, fy - S * 0.14], radius=S * 0.012, fill=col)
        d.line([(fx + S * 0.085, fy - S * 0.30), (fx + S * 0.16, fy - S * 0.47)], fill=col, width=int(S * 0.03))
        d.rectangle([0, int(S * 0.86), S, S], fill=(12, 16, 18, 255))
    if not fg_only and not bg_only:
        fog = Image.new("RGBA", (S, S), (0, 0, 0, 0)); fd = ImageDraw.Draw(fog)
        for k in range(26):
            x = random.uniform(-0.1, 1.1) * S; y = random.uniform(0.70, 0.84) * S; r = random.uniform(0.08, 0.2) * S
            fd.ellipse([x - r, y - r * 0.28, x + r, y + r * 0.28], fill=(226, 214, 204, 30))
        fog = fog.filter(ImageFilter.GaussianBlur(S * 0.02)); img = Image.alpha_composite(img, fog)
    return img.resize((size, size), Image.LANCZOS)
os.makedirs("art", exist_ok=True)
make(512).save("icon.png")
make(192).save("art/icon_192.png")
make(432, bg_only=True).save("art/icon_bg_432.png")
fg = make(432, fg_only=True)
# zona segura do icone adaptativo: reduzir o primeiro plano
canvas = Image.new("RGBA", (432, 432), (0, 0, 0, 0)); small = fg.resize((300, 300), Image.LANCZOS); canvas.paste(small, (66, 80), small); canvas.save("art/icon_fg_432.png")
print("ok")
