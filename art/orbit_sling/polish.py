"""polish.py: sprites/ -> sprites_game4/ : +sat, light rim glow baked (indigo outline vanishes on #14122B)."""
import glob, os
from PIL import Image, ImageEnhance, ImageFilter, ImageChops
for f in glob.glob("sprites/*.png"):
    n = os.path.basename(f)
    if n.startswith("bg_"): continue
    im = Image.open(f).convert("RGBA"); r, g, b, a = im.split()
    rgb = ImageEnhance.Color(Image.merge("RGB", (r, g, b))).enhance(1.35)
    rgb = ImageEnhance.Contrast(rgb).enhance(1.08)
    im = Image.merge("RGBA", (*rgb.split(), a))
    pad = 24; canvas = Image.new("RGBA", (im.width + pad*2, im.height + pad*2), (0,0,0,0)); canvas.paste(im, (pad, pad))
    al = canvas.getchannel("A")
    rim = al.filter(ImageFilter.MaxFilter(7))                     # ~3px ring
    glow = al.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(9))
    out = Image.new("RGBA", canvas.size, (0,0,0,0))
    out.alpha_composite(Image.merge("RGBA", (*Image.new("RGB", canvas.size, (184,170,255)).split(), glow.point(lambda v: int(v*.55)))))
    out.alpha_composite(Image.merge("RGBA", (*Image.new("RGB", canvas.size, (240,236,255)).split(), rim)))
    out.alpha_composite(canvas)
    out.crop(out.getbbox()).save("sprites_game4/" + n)
print(len(os.listdir("sprites_game4")), "polished")
