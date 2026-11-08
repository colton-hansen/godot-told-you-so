# Kitchen / floor textures — painted materials, not noise.
# 2012 prepared basement: cheap alder laminate, linoleum, кафель, painted cinder block.
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$code = @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

public static class KitchenTex {
    static uint UHash(int x, int y, int seed) {
        unchecked {
            uint v = (uint)(x * 73856093) ^ (uint)(y * 19349663) ^ (uint)(seed * 83492791);
            v = v * 1103515245u + 12345u;
            v ^= v >> 16;
            v = v * 1103515245u + 6789u;
            v ^= v >> 13;
            return v;
        }
    }

    static double H01(int x, int y, int seed) {
        return (UHash(x, y, seed) % 100000u) / 100000.0;
    }

    static int Wrap(int v, int m) {
        int r = v % m;
        return r < 0 ? r + m : r;
    }

    static void SetRgb(byte[] buf, int stride, int w, int h, int x, int y, int r, int g, int b) {
        x = Wrap(x, w);
        y = Wrap(y, h);
        if (r < 0) r = 0; if (r > 255) r = 255;
        if (g < 0) g = 0; if (g > 255) g = 255;
        if (b < 0) b = 0; if (b > 255) b = 255;
        int o = y * stride + x * 3;
        buf[o] = (byte)b;
        buf[o + 1] = (byte)g;
        buf[o + 2] = (byte)r;
    }

    static void GetRgb(byte[] buf, int stride, int w, int h, int x, int y, out int r, out int g, out int b) {
        x = Wrap(x, w);
        y = Wrap(y, h);
        int o = y * stride + x * 3;
        b = buf[o];
        g = buf[o + 1];
        r = buf[o + 2];
    }

    static void Fill(byte[] buf, int stride, int w, int h, int r, int g, int b) {
        for (int y = 0; y < h; y++)
            for (int x = 0; x < w; x++)
                SetRgb(buf, stride, w, h, x, y, r, g, b);
    }

    static void AddRgb(byte[] buf, int stride, int w, int h, int x, int y, int dr, int dg, int db) {
        int r, g, b;
        GetRgb(buf, stride, w, h, x, y, out r, out g, out b);
        SetRgb(buf, stride, w, h, x, y, r + dr, g + dg, b + db);
    }

    static void Blob(byte[] buf, int stride, int w, int h, int cx, int cy, int radius, int dr, int dg, int db) {
        int r2 = radius * radius;
        for (int dy = -radius; dy <= radius; dy++) {
            for (int dx = -radius; dx <= radius; dx++) {
                int d2 = dx * dx + dy * dy;
                if (d2 > r2) continue;
                double fall = 1.0 - Math.Sqrt(d2) / (double)radius;
                AddRgb(buf, stride, w, h, cx + dx, cy + dy,
                    (int)(dr * fall), (int)(dg * fall), (int)(db * fall));
            }
        }
    }

    static void HLine(byte[] buf, int stride, int w, int h, int y, int r, int g, int b, int thickness) {
        for (int t = 0; t < thickness; t++)
            for (int x = 0; x < w; x++)
                SetRgb(buf, stride, w, h, x, y + t, r, g, b);
    }

    static void VLine(byte[] buf, int stride, int w, int h, int x, int r, int g, int b, int thickness) {
        for (int t = 0; t < thickness; t++)
            for (int y = 0; y < h; y++)
                SetRgb(buf, stride, w, h, x + t, y, r, g, b);
    }

    static void SavePng(byte[] buf, int stride, int w, int h, string path) {
        var fmt = PixelFormat.Format24bppRgb;
        using (var bmp = new Bitmap(w, h, fmt)) {
            var rect = new Rectangle(0, 0, w, h);
            var data = bmp.LockBits(rect, ImageLockMode.WriteOnly, fmt);
            try {
                Marshal.Copy(buf, 0, data.Scan0, buf.Length);
            } finally {
                bmp.UnlockBits(data);
            }
            string dir = Path.GetDirectoryName(path);
            if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
                Directory.CreateDirectory(dir);
            bmp.Save(path, ImageFormat.Png);
        }
    }

    static byte[] NewBuf(int w, int h, out int stride) {
        stride = ((w * 3 + 3) / 4) * 4;
        return new byte[stride * h];
    }

    // Cheap 2010s kitchen кафель: readable grout, two beige tones, dirt in joints.
    public static void FloorCeramic64(string path) {
        int w = 64, h = 64, stride;
        byte[] buf = NewBuf(w, h, out stride);
        int tile = 16;
        int grout = 2;
        int[,] pal = {
            { 206, 186, 150 },
            { 194, 174, 138 },
            { 214, 196, 162 },
            { 188, 168, 132 },
            { 200, 182, 146 },
            { 178, 160, 128 }
        };
        for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
                int tx = x / tile;
                int ty = y / tile;
                int lx = x % tile;
                int ly = y % tile;
                if (lx < grout || ly < grout) {
                    double n = H01(x, y, 9);
                    int d = (int)(n * 14);
                    SetRgb(buf, stride, w, h, x, y, 96 + d, 82 + d, 64 + d / 2);
                    if (H01(x, y, 21) > 0.82) {
                        AddRgb(buf, stride, w, h, x, y, 18, 10, 4);
                    }
                } else {
                    int pi = (int)(UHash(tx, ty, 3) % 6);
                    int r = pal[pi, 0], g = pal[pi, 1], b = pal[pi, 2];
                    if (lx == grout || ly == grout) {
                        r += 18; g += 16; b += 12;
                    }
                    if (lx == tile - 1 || ly == tile - 1) {
                        r -= 16; g -= 14; b -= 12;
                    }
                    double speck = H01(x, y, 44);
                    if (speck > 0.97) { r -= 22; g -= 18; b -= 14; }
                    else if (speck < 0.03) { r += 16; g += 14; b += 10; }
                    SetRgb(buf, stride, w, h, x, y, r, g, b);
                }
            }
        }
        Blob(buf, stride, w, h, 22, 40, 7, -28, -22, -14);
        Blob(buf, stride, w, h, 50, 12, 5, -18, -14, -8);
        Blob(buf, stride, w, h, 8, 58, 4, -12, -16, -6);
        SavePng(buf, stride, w, h, path);
    }

    // Линолеум «под паркет» — golden oak strips, offset rows, dark joints.
    public static void FloorParquetLino64(string path) {
        int w = 64, h = 64, stride;
        byte[] buf = NewBuf(w, h, out stride);
        int[,] pal = {
            { 186, 132, 72 },
            { 168, 116, 60 },
            { 198, 146, 84 },
            { 158, 108, 54 },
            { 176, 124, 66 }
        };
        int ph = 16;
        int pw = 32;
        for (int y = 0; y < h; y++) {
            int row = y / ph;
            int off = (row % 2) * (pw / 2);
            for (int x = 0; x < w; x++) {
                int col = (x + off) / pw;
                int lx = (x + off) % pw;
                int ly = y % ph;
                if (lx == 0 || ly == 0) {
                    SetRgb(buf, stride, w, h, x, y, 92, 62, 34);
                    continue;
                }
                int pi = (int)(UHash(col, row, 17) % 5);
                int r = pal[pi, 0], g = pal[pi, 1], b = pal[pi, 2];
                double grain = Math.Sin((x + col * 3) * 0.9) * 0.5 + 0.5;
                int gd = (int)((grain - 0.5) * 22);
                r += gd; g += gd / 2;
                if (ly == 1) { r += 14; g += 10; b += 6; }
                if (ly == ph - 1) { r -= 18; g -= 14; b -= 10; }
                if (H01(x, row, 5) > 0.93 && ly > 2 && ly < ph - 2) {
                    r -= 20; g -= 16; b -= 10;
                }
                SetRgb(buf, stride, w, h, x, y, r, g, b);
            }
        }
        Blob(buf, stride, w, h, 18, 28, 6, -20, -16, -10);
        Blob(buf, stride, w, h, 48, 50, 5, -14, -10, -6);
        SavePng(buf, stride, w, h, path);
    }

    // IKEA/Leroy ~2010 alder («ольха») laminate doors: frame + vertical grain, not noise.
    public static void CabinetAlder256(string path) {
        int w = 256, h = 256, stride;
        byte[] buf = NewBuf(w, h, out stride);
        for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
                int lx = x % 128;
                if (lx < 3) {
                    int md = (int)(H01(x, y, 2) * 8);
                    SetRgb(buf, stride, w, h, x, y, 118 + md, 78 + md, 42);
                    continue;
                }
                double wander = Math.Sin(y * 0.012) * 0.5;
                double g1 = Math.Sin((x + wander) * 0.7);
                double g2 = Math.Sin(x * 2.1);
                int d = (int)(g1 * 6 + g2 * 3);
                int r = 201 + d;
                int g = 149 + d * 3 / 4;
                int b = 90 + d / 3;
                if (lx == 3 || lx == 127) { r -= 22; g -= 16; b -= 10; }
                if (H01(x, y / 3, 8) > 0.94) { r -= 14; g -= 10; b -= 5; }
                SetRgb(buf, stride, w, h, x, y, r, g, b);
            }
        }
        Blob(buf, stride, w, h, 40, 220, 10, -16, -12, -6);
        Blob(buf, stride, w, h, 200, 30, 8, 12, 8, 4);
        SavePng(buf, stride, w, h, path);
    }

    // Cheap «искусственный камень» laminate counter, 2010 kitchen.
    public static void CounterLaminate256(string path) {
        int w = 256, h = 256, stride;
        byte[] buf = NewBuf(w, h, out stride);
        Fill(buf, stride, w, h, 186, 176, 158);
        for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
                double n = Math.Sin(x * 0.03) * Math.Sin(y * 0.028);
                int d = (int)(n * 6);
                AddRgb(buf, stride, w, h, x, y, d, d, d / 2);
            }
        }
        int[][] chips = {
            new int[] { 228, 222, 206 },
            new int[] { 96, 88, 78 },
            new int[] { 148, 118, 90 },
            new int[] { 208, 198, 182 },
            new int[] { 74, 70, 64 },
            new int[] { 168, 156, 138 }
        };
        for (int i = 0; i < 2800; i++) {
            int cx = (int)(H01(i, 2, 11) * w);
            int cy = (int)(H01(i, 7, 19) * h);
            int[] c = chips[i % chips.Length];
            SetRgb(buf, stride, w, h, cx, cy, c[0], c[1], c[2]);
            if (H01(i, 4, 5) > 0.7) {
                SetRgb(buf, stride, w, h, cx + 1, cy, c[0], c[1], c[2]);
            }
        }
        for (int i = 0; i < 90; i++) {
            int cx = (int)(H01(i, 12, 31) * w);
            int cy = (int)(H01(i, 17, 37) * h);
            int rw = 1 + (int)(H01(i, 3, 29) * 3);
            int rh = 1 + (int)(H01(i, 9, 23) * 2);
            int[] c = chips[i % chips.Length];
            for (int dy = 0; dy < rh; dy++)
                for (int dx = 0; dx < rw; dx++)
                    SetRgb(buf, stride, w, h, cx + dx, cy + dy, c[0], c[1], c[2]);
        }
        Blob(buf, stride, w, h, 70, 190, 16, -14, -12, -8);
        Blob(buf, stride, w, h, 200, 40, 12, 10, 8, 4);
        SavePng(buf, stride, w, h, path);
    }

    // Brushed steel for shelves — vertical grain you can actually see.
    public static void MetalBrushed256(string path) {
        int w = 256, h = 256, stride;
        byte[] buf = NewBuf(w, h, out stride);
        for (int x = 0; x < w; x++) {
            double stripe = Math.Sin(x * 1.6) * 6 + Math.Sin(x * 4.2) * 3;
            int basev = (int)(168 + stripe);
            for (int y = 0; y < h; y++) {
                int jitter = (int)((H01(x, y / 6, 6) - 0.5) * 8);
                int v = basev + jitter;
                SetRgb(buf, stride, w, h, x, y, v + 2, v, v - 3);
            }
        }
        for (int i = 0; i < 4; i++) {
            int sx = (int)(H01(i, 1, 33) * w);
            VLine(buf, stride, w, h, sx, 124, 126, 130, 1);
        }
        Blob(buf, stride, w, h, 30, 200, 14, -22, -20, -16);
        Blob(buf, stride, w, h, 180, 20, 10, 18, 18, 16);
        SavePng(buf, stride, w, h, path);
    }

    // Painted шлакоблок — the 2012 basement wall, not gray static.
    public static void WallCinder256(string path) {
        int w = 256, h = 256, stride;
        byte[] buf = NewBuf(w, h, out stride);
        int bw = 64;
        int bh = 32;
        int mortar = 3;
        int[,] pal = {
            { 214, 202, 176 },
            { 206, 194, 168 },
            { 220, 208, 182 },
            { 198, 186, 162 },
            { 210, 196, 170 }
        };
        for (int y = 0; y < h; y++) {
            int row = y / bh;
            int off = (row % 2) * (bw / 2);
            for (int x = 0; x < w; x++) {
                int col = (x + off) / bw;
                int lx = (x + off) % bw;
                int ly = y % bh;
                if (lx < mortar || ly < mortar) {
                    int d = (int)(H01(x, y, 2) * 10);
                    SetRgb(buf, stride, w, h, x, y, 156 + d, 142 + d, 118 + d / 2);
                } else {
                    int pi = (int)(UHash(col, row, 41) % 5);
                    int r = pal[pi, 0], g = pal[pi, 1], b = pal[pi, 2];
                    if (lx == mortar || ly == mortar) { r += 12; g += 10; b += 8; }
                    double pit = H01(x, y, 77);
                    if (pit > 0.985) { r -= 28; g -= 24; b -= 18; }
                    SetRgb(buf, stride, w, h, x, y, r, g, b);
                }
            }
        }
        Blob(buf, stride, w, h, 48, 200, 28, -30, -26, -16);
        Blob(buf, stride, w, h, 200, 90, 18, -16, -18, -10);
        Blob(buf, stride, w, h, 120, 40, 12, 14, 12, 8);
        // hairline cracks
        int cx = 80, cy = 160;
        for (int i = 0; i < 40; i++) {
            cx += (int)((H01(i, 4, 9) - 0.45) * 4);
            cy += 1;
            SetRgb(buf, stride, w, h, cx, cy, 140, 128, 108);
        }
        SavePng(buf, stride, w, h, path);
    }

    // PSX vinyl tile 16² — not a flat fill. Grout on +X/+Y so a chessboard still reads.
    public static void FloorCheckTile16(string path, bool dark) {
        int w = 16, h = 16, stride;
        byte[] buf = NewBuf(w, h, out stride);
        int br, bg, bb;
        if (dark) { br = 42; bg = 38; bb = 36; }
        else { br = 248; bg = 248; bb = 246; }
        int grout = 1;
        for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
                int r = br, g = bg, b = bb;
                if (x < grout || y < grout) {
                    int d = (int)(H01(x, y, 3) * 10);
                    if (dark) SetRgb(buf, stride, w, h, x, y, 22 + d, 20 + d, 18 + d);
                    else SetRgb(buf, stride, w, h, x, y, 198 + d, 198 + d, 196 + d);
                    continue;
                }
                double n = H01(x, y, 11);
                int v = (int)((n - 0.5) * (dark ? 22 : 8));
                r += v; g += v * 3 / 4; b += v / 2;
                if (H01(x, y, 28) > 0.92) {
                    if (dark) { r += 18; g += 14; b += 10; }
                    else { r -= 8; g -= 8; b -= 6; }
                }
                if (H01(x, y, 41) < 0.06) {
                    if (dark) { r += 8; g += 6; b += 4; }
                    else { r += 14; g += 12; b += 8; }
                }
                if (x == grout || y == grout) { r += dark ? 10 : 16; g += dark ? 8 : 12; b += 6; }
                if (x == w - 1 || y == h - 1) { r -= dark ? 8 : 14; g -= dark ? 6 : 12; b -= 8; }
                SetRgb(buf, stride, w, h, x, y, r, g, b);
            }
        }
        if (dark) {
            Blob(buf, stride, w, h, 5, 11, 3, 14, 10, 6);
            Blob(buf, stride, w, h, 12, 4, 2, 10, 8, 5);
        } else {
            Blob(buf, stride, w, h, 4, 10, 3, -8, -8, -6);
            Blob(buf, stride, w, h, 11, 5, 2, -6, -6, -4);
        }
        SavePng(buf, stride, w, h, path);
    }
}
'@

Add-Type -TypeDefinition $code -ReferencedAssemblies System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $root "assets\textures\kitchen_procedural"

[KitchenTex]::FloorCeramic64((Join-Path $outDir "floor_tile_grid_64.png"))
[KitchenTex]::FloorParquetLino64((Join-Path $outDir "floor_lino_worn_64.png"))
[KitchenTex]::CabinetAlder256((Join-Path $outDir "cabinet_wood_worn_256.png"))
[KitchenTex]::CounterLaminate256((Join-Path $outDir "countertop_speckle_256.png"))
[KitchenTex]::MetalBrushed256((Join-Path $outDir "appliance_metal_smudge_256.png"))
[KitchenTex]::WallCinder256((Join-Path $outDir "wall_paint_basement_256.png"))
[KitchenTex]::FloorCheckTile16((Join-Path $outDir "floor_check_white_16.png"), $false)
[KitchenTex]::FloorCheckTile16((Join-Path $outDir "floor_check_black_16.png"), $true)

Write-Host "Wrote 2012 basement textures to $outDir"
