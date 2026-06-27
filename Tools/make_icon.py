#!/usr/bin/env python3
"""Genera l'icona di Apposto: una mano che sposta/ordina le app in una griglia.

Richiede Pillow (`pip install Pillow`). Esegui:  python3 Tools/make_icon.py
Esporta i PNG in Apposto/Assets.xcassets/AppIcon.appiconset/.
"""
import os
from PIL import Image, ImageDraw, ImageFilter

S = 1024  # canvas

def lerp(a, b, t):
    return tuple(int(a[i] + (b[i]-a[i])*t) for i in range(len(a)))

def gradient(size, c1, c2):
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2*size - 2)
            px[x, y] = lerp(c1, c2, t)
    return img.convert("RGBA")

def rounded_mask(size, box, radius):
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle(box, radius=radius, fill=255)
    return m

def soft_shadow(size, box, radius, blur, alpha, offset=(0, 0)):
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bx = [box[0]+offset[0], box[1]+offset[1], box[2]+offset[0], box[3]+offset[1]]
    ImageDraw.Draw(layer).rounded_rectangle(bx, radius=radius, fill=(0, 0, 0, alpha))
    return layer.filter(ImageFilter.GaussianBlur(blur))

def rotated_rrect(w, h, radius, color, angle, center):
    """Rettangolo arrotondato ruotato, composto a tutta tela centrato in `center`."""
    pad = 24
    l = Image.new("RGBA", (w + 2*pad, h + 2*pad), (0, 0, 0, 0))
    ImageDraw.Draw(l).rounded_rectangle([pad, pad, pad+w, pad+h], radius=radius, fill=color)
    l = l.rotate(angle, expand=True, resample=Image.BICUBIC)
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    layer.alpha_composite(l, (int(center[0]-l.width/2), int(center[1]-l.height/2)))
    return layer

def tile(layer, box, radius, color):
    ImageDraw.Draw(layer).rounded_rectangle(box, radius=radius, fill=color)
    x0, y0, x1, y1 = box
    hl = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(hl).rounded_rectangle([x0, y0, x1, y0 + (y1-y0)*0.5],
                                         radius=radius, fill=(255, 255, 255, 55))
    m = rounded_mask(S, box, radius)
    layer.alpha_composite(Image.composite(hl, Image.new("RGBA", (S, S), (0, 0, 0, 0)), m))

def build():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    pad = 100
    body = [pad, pad, S-pad, S-pad]
    radius = 185

    img.alpha_composite(soft_shadow(S, body, radius, blur=34, alpha=90, offset=(0, 22)))

    grad = gradient(S, (109, 95, 230), (40, 160, 255))
    mask = rounded_mask(S, body, radius)
    img.paste(grad, (0, 0), mask)

    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([pad-60, pad-120, int(S*0.75), int(S*0.6)],
                                 fill=(255, 255, 255, 36))
    glow = glow.filter(ImageFilter.GaussianBlur(60))
    img.alpha_composite(Image.composite(glow, Image.new("RGBA", (S, S), (0, 0, 0, 0)), mask))

    content = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    GREEN = (52, 211, 153, 255)
    AMBER = (251, 191, 36, 255)
    CORAL = (255, 107, 107, 255)
    PEACH = (247, 205, 165, 255)
    PEACH_D = (228, 178, 132, 255)

    tsize, trad = 150, 34
    left = [249, 640, 249+tsize, 640+tsize]
    mid = [437, 640, 437+tsize, 640+tsize]
    right = [625, 640, 625+tsize, 640+tsize]
    tile(content, left, trad, GREEN)
    tile(content, right, trad, AMBER)

    dd = ImageDraw.Draw(content)
    dd.rounded_rectangle(mid, radius=trad, fill=(255, 255, 255, 38))
    dd.rounded_rectangle(mid, radius=trad, outline=(255, 255, 255, 150), width=6)

    held = [432, 300, 432+160, 300+160]
    hrad = 36
    content.alpha_composite(soft_shadow(S, held, hrad, blur=22, alpha=70, offset=(0, 26)))

    # Pollice: esce dal lato sinistro-alto del palmo e scende DIETRO la tile.
    # Più sottile delle dita; si vede solo dove esce dal palmo (in alto a
    # sinistra), la punta resta nascosta dietro la tile.
    content.alpha_composite(rotated_rrect(38, 196, 19, PEACH, angle=13, center=(432, 344)))

    # Tile tenuta (copre la parte bassa del pollice -> niente punta visibile)
    tile(content, held, hrad, CORAL)

    # Palmo + 4 dita davanti (il palmo copre l'attacco del pollice in alto)
    hand = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dh = ImageDraw.Draw(hand)
    dh.rounded_rectangle([430, 228, 600, 314], radius=42, fill=PEACH)
    for fx, fy in [(448, 360), (485, 372), (522, 368), (559, 356)]:
        dh.rounded_rectangle([fx, 292, fx+30, fy], radius=15, fill=PEACH)
    content.alpha_composite(hand)

    # Freccia verso lo slot di destinazione
    ax = 512
    adr = ImageDraw.Draw(content)
    y = 490
    while y < 612:
        adr.line([ax, y, ax, min(y+24, 612)], fill=(255, 255, 255, 200), width=10)
        y += 40
    adr.polygon([(ax-22, 612), (ax+22, 612), (ax, 648)], fill=(255, 255, 255, 220))

    img.alpha_composite(Image.composite(content, Image.new("RGBA", (S, S), (0, 0, 0, 0)), mask))
    return img

def main():
    img = build()
    dest = os.path.join(os.path.dirname(__file__), "..", "Apposto",
                        "Assets.xcassets", "AppIcon.appiconset")
    dest = os.path.normpath(dest)
    for sz in [16, 32, 64, 128, 256, 512, 1024]:
        img.resize((sz, sz), Image.LANCZOS).save(os.path.join(dest, f"icon_{sz}.png"))
    print("exported icons to", dest)

if __name__ == "__main__":
    main()
