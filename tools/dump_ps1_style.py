import bpy
from collections import Counter

img = bpy.data.images.get("Image_0.001")
if img is None:
    for im in bpy.data.images:
        if "Image_0" in im.name:
            img = im
            break
print("image", img.name if img else None, img.size[:] if img else None)
if img is None:
    raise SystemExit(0)

w, h = int(img.size[0]), int(img.size[1])
pix = list(img.pixels)  # RGBA float 0..1
print("pixels", len(pix), "expected", w * h * 4)


def rgb_at(x, y):
    # Blender images: y=0 is bottom
    i = (y * w + x) * 4
    return pix[i], pix[i + 1], pix[i + 2]


def is_bg(r, g, b):
    return r >= 0.96 and g >= 0.96 and b >= 0.96


visited = bytearray(w * h)
regions = []
for y in range(h):
    for x in range(w):
        idx = y * w + x
        if visited[idx]:
            continue
        r, g, b = rgb_at(x, y)
        if is_bg(r, g, b):
            visited[idx] = 1
            continue
        stack = [(x, y)]
        visited[idx] = 1
        minx = maxx = x
        miny = maxy = y
        count = 0
        while stack:
            cx, cy = stack.pop()
            count += 1
            if cx < minx:
                minx = cx
            if cx > maxx:
                maxx = cx
            if cy < miny:
                miny = cy
            if cy > maxy:
                maxy = cy
            for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                if 0 <= nx < w and 0 <= ny < h:
                    nidx = ny * w + nx
                    if visited[nidx]:
                        continue
                    nr, ng, nb = rgb_at(nx, ny)
                    if is_bg(nr, ng, nb):
                        visited[nidx] = 1
                        continue
                    visited[nidx] = 1
                    stack.append((nx, ny))
        if count >= 80:
            # convert blender y (bottom origin) to image-top origin
            y0_top = h - 1 - maxy
            y1_top = h - 1 - miny
            regions.append((count, minx, y0_top, maxx, y1_top, miny, maxy))

regions.sort(reverse=True)
print("regions count,x0,y0top,x1,y1top,size:")
for count, x0, y0, x1, y1, miny, maxy in regions:
    print(
        f"  {count:6d}  [{x0:3d},{y0:3d}]-[{x1:3d},{y1:3d}]  "
        f"{x1-x0+1}x{y1-y0+1}  uv u[{x0/w:.3f},{(x1+1)/w:.3f}] "
        f"v[{miny/h:.3f},{(maxy+1)/h:.3f}]"
    )

acc = Counter()
for y in range(h):
    for x in range(w):
        r, g, b = rgb_at(x, y)
        if is_bg(r, g, b):
            continue
        qr = int(r * 31) * 8
        qg = int(g * 31) * 8
        qb = int(b * 31) * 8
        acc[(qr, qg, qb)] += 1
print("top colors:")
for (r, g, b), c in acc.most_common(20):
    print(f"  #{r:02X}{g:02X}{b:02X}  {c}")
