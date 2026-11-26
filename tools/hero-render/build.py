import json, sys, os
from PIL import Image, ImageDraw, ImageFilter, ImageChops
SRC = sys.argv[1]; OUT = sys.argv[2]
os.makedirs(OUT, exist_ok=True)
meta = json.load(open(f'{SRC}/meta.json'))
NF = {'idle': 6, 'walk': 8, 'attack': 6, 'hurt': 2}
HERO = {0: 'guanyu', 1: 'lubu', 2: 'zhaoyun', 3: 'c_knight_m', 4: 'c_knight_f', 5: 'c_elf_m', 6: 'c_elf_f', 7: 'c_mage_m', 8: 'c_mage_f', 9: 'c_dark_m', 10: 'c_dark_f'}
TRAIL = {0: (150, 255, 190), 1: (255, 140, 90), 2: (170, 215, 255), 3: (220, 230, 255), 4: (220, 230, 255), 5: (170, 255, 170), 6: (170, 255, 170), 7: (140, 180, 255), 8: (140, 180, 255), 9: (210, 150, 255), 10: (210, 150, 255)}
SS = 2

def catmull(pts, n=10):
    out = []
    P = [pts[0]] + pts + [pts[-1]]
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        for k in range(n):
            t = k / n
            out.append(tuple(0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t * t + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t * t * t) for j in range(2)))
    out.append(pts[-1])
    return out

def trail(im, hero, view, f):
    if f not in (2, 3, 4):
        return im
    segs = {2: [(2, 0.45)], 3: [(2, 0.5), (3, 1.0)], 4: [(3, 0.55), (4, 0.8)]}[f]
    pts = []
    for ff, a in segs:
        arc = meta[f'h{hero}_{view}_attack_{ff}']['arc']
        for p in (arc if not pts else arc[1:]):
            pts.append((p[0] * SS, p[1] * SS, a))
    lay = Image.new('RGBA', im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    core = Image.new('RGBA', im.size, (0, 0, 0, 0))
    dc = ImageDraw.Draw(core)
    col = TRAIL[hero]
    n = len(pts)
    for i in range(n - 1):
        u = (i + 1) / n
        a = pts[i + 1][2]
        w = int(4 + 26 * u)
        d.line([pts[i][:2], pts[i + 1][:2]], fill=col + (int(170 * a * u),), width=w)
        dc.line([pts[i][:2], pts[i + 1][:2]], fill=(255, 255, 235, int(220 * a * u)), width=int(2 + 8 * u))
    glow = lay.filter(ImageFilter.GaussianBlur(6))
    core = core.filter(ImageFilter.GaussianBlur(1.5))
    base = Image.new('RGBA', im.size, (0, 0, 0, 0))
    base.alpha_composite(glow); base.alpha_composite(glow); base.alpha_composite(core)
    out = base.copy(); out.alpha_composite(im)
    return out

def outline(im):
    a = im.getchannel('A')
    m = a.point(lambda v: 255 if v > 110 else 0)
    dil = m.filter(ImageFilter.MaxFilter(3))
    ring = ImageChops.subtract(dil, m)
    ol = Image.new('RGBA', im.size, (22, 14, 10, 0))
    ol.putalpha(ring.point(lambda v: 150 if v else 0))
    out = ol.copy(); out.alpha_composite(im)
    return out

for hero in [int(x) for x in (sys.argv[3] if len(sys.argv) > 3 else '0,1,2').split(',')]:
    frames = []
    for view in ('front', 'back'):
        for anim, nf in NF.items():
            for f in range(nf):
                k = f'h{hero}_{view}_{anim}_{f}'
                im = Image.open(f'{SRC}/{k}.png').convert('RGBA')
                if anim == 'attack':
                    im = trail(im, hero, view, f)
                # premultiplied downsample
                r, g, b, a = im.split()
                pm = Image.merge('RGBA', (ImageChops.multiply(r, a), ImageChops.multiply(g, a), ImageChops.multiply(b, a), a))
                sm = pm.resize((im.width // SS, im.height // SS), Image.BOX)
                r, g, b, a = sm.split()
                def un(c):
                    return Image.eval(Image.merge('LA', (c, a)), lambda v: v).getchannel(0)
                import numpy as np
                arr = np.asarray(sm).astype(np.float32)
                al = arr[..., 3:4]
                rgb = np.where(al > 0, arr[..., :3] * 255.0 / np.maximum(al, 1), 0)
                arr = np.concatenate([np.clip(rgb, 0, 255), al], axis=2).astype(np.uint8)
                sm = Image.fromarray(arr, 'RGBA')
                sm = outline(sm)
                bb = sm.getbbox()
                c = sm.crop(bb)
                foot = meta[k]['foot']
                frames.append((f'{view}_{anim}_{f}', c, bb[0], bb[1], foot, meta[k].get('g'), meta[k].get('t')))
    # shelf pack
    W = 1024
    frames_sorted = sorted(frames, key=lambda t: -t[1].height)
    x = y = sh = 0
    pos = {}
    for name, c, bx, by, foot, *_ in frames_sorted:
        if x + c.width > W:
            x = 0; y += sh + 1; sh = 0
        pos[name] = (x, y)
        x += c.width + 1; sh = max(sh, c.height)
    H = y + sh
    atlas = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    info = {}
    for name, c, bx, by, foot, wg, wt in frames:
        px, py = pos[name]
        atlas.alpha_composite(c, (px, py))
        info[name] = [px, py, c.width, c.height, round(foot[0] - bx, 1), round(foot[1] - by, 1)]
        if wg and wt:
            info[name] += [round(wg[0] - bx, 1), round(wg[1] - by, 1), round(wt[0] - bx, 1), round(wt[1] - by, 1)]
    nm = HERO[hero]
    atlas.save(f'{OUT}/{nm}.png', optimize=True)
    atlas.save(f'{OUT}/{nm}.webp', lossless=True, method=6)
    json.dump({'n': NF, 'f': info}, open(f'{OUT}/{nm}.json', 'w'), separators=(',', ':'))
    print(nm, atlas.size, os.path.getsize(f'{OUT}/{nm}.png'), os.path.getsize(f'{OUT}/{nm}.webp'))
