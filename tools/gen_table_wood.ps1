# Full-bleed 256 wood albedo for table-2. Grain has to read from a few meters.
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$code = @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

public static class TableWood {
    static uint UHash(int x, int y, int seed) {
        unchecked {
            uint v = (uint)(x * 73856093) ^ (uint)(y * 19349663) ^ (uint)(seed * 83492791);
            v = v * 1103515245u + 12345u;
            v ^= v >> 16;
            return v;
        }
    }
    static double H01(int x, int y, int seed) {
        return (UHash(x, y, seed) % 100000u) / 100000.0;
    }
    static void SetRgb(byte[] buf, int stride, int w, int h, int x, int y, int r, int g, int b) {
        if ((uint)x >= (uint)w || (uint)y >= (uint)h) return;
        if (r < 0) r = 0; if (r > 255) r = 255;
        if (g < 0) g = 0; if (g > 255) g = 255;
        if (b < 0) b = 0; if (b > 255) b = 255;
        int o = y * stride + x * 3;
        buf[o] = (byte)b; buf[o + 1] = (byte)g; buf[o + 2] = (byte)r;
    }
    static void SavePng(byte[] buf, int stride, int w, int h, string path) {
        using (var bmp = new Bitmap(w, h, PixelFormat.Format24bppRgb)) {
            var data = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.WriteOnly, PixelFormat.Format24bppRgb);
            try { Marshal.Copy(buf, 0, data.Scan0, buf.Length); }
            finally { bmp.UnlockBits(data); }
            bmp.Save(path, ImageFormat.Png);
        }
    }

    public static void Write256(string path) {
        int w = 256, h = 256;
        int stride = ((w * 3 + 3) / 4) * 4;
        byte[] buf = new byte[stride * h];
        int plank = 51;
        int[,] pal = {
            { 196, 142, 78 },
            { 168, 112, 58 },
            { 210, 158, 92 },
            { 150, 96, 48 },
            { 184, 128, 68 }
        };
        for (int y = 0; y < h; y++) {
            int row = y / plank;
            int ly = y % plank;
            int pi = (int)(UHash(row, 3, 11) % 5);
            int pr = pal[pi, 0], pg = pal[pi, 1], pb = pal[pi, 2];
            for (int x = 0; x < w; x++) {
                // Joint between boards.
                if (ly < 2) {
                    SetRgb(buf, stride, w, h, x, y, 72, 46, 24);
                    continue;
                }
                double warp = Math.Sin(x * 0.035 + row * 1.7) * 6.0 + (H01(x / 3, row, 8) - 0.5) * 10.0;
                double gy = ly + warp;
                double grain = Math.Sin(x * 0.55 + gy * 0.08 + row) * 0.5 + 0.5;
                grain += Math.Sin(x * 2.2 + row * 4.0) * 0.12;
                int gd = (int)((grain - 0.5) * 70);
                int r = pr + gd;
                int g = pg + gd * 3 / 4;
                int b = pb + gd / 2;
                // Occasional dark streak (pore / grain line).
                if (H01(x, row, 19) > 0.965 && ly > 4 && ly < plank - 3) {
                    r -= 48; g -= 36; b -= 22;
                }
                if (ly == 2) { r += 22; g += 16; b += 8; }
                if (ly == plank - 1) { r -= 26; g -= 20; b -= 12; }
                // Pore specks.
                if (H01(x, y, 44) > 0.985) { r -= 30; g -= 24; b -= 14; }
                SetRgb(buf, stride, w, h, x, y, r, g, b);
            }
        }
        // Coffee ring — dark ellipse, readable at distance.
        int cx = 96, cy = 118, ra = 38, rb = 32;
        for (int y = cy - rb - 3; y <= cy + rb + 3; y++) {
            for (int x = cx - ra - 3; x <= cx + ra + 3; x++) {
                double nx = (x - cx) / (double)ra;
                double ny = (y - cy) / (double)rb;
                double d = Math.Sqrt(nx * nx + ny * ny);
                if (d > 0.82 && d < 1.08) {
                    double fall = 1.0 - Math.Abs(d - 0.95) / 0.13;
                    int o = (int)(42 * fall);
                    int rr, gg, bb;
                    if ((uint)x >= (uint)w || (uint)y >= (uint)h) continue;
                    int i = y * stride + x * 3;
                    bb = buf[i]; gg = buf[i + 1]; rr = buf[i + 2];
                    SetRgb(buf, stride, w, h, x, y, rr - o, gg - o * 3 / 4, bb - o / 2);
                }
            }
        }
        // Corner wear.
        for (int i = 0; i < 18; i++) {
            int x = 8 + i;
            int y = 6 + (int)(H01(i, 2, 3) * 4);
            SetRgb(buf, stride, w, h, x, y, 90, 62, 36);
            SetRgb(buf, stride, w, h, w - 10 - i, h - 8, 88, 58, 32);
        }
        SavePng(buf, stride, w, h, path);
    }
}
'@

Add-Type -TypeDefinition $code -ReferencedAssemblies System.Drawing
$out = "c:\Users\morrayne\Desktop\gamedev\godot\told-you-so\assets\textures\ps1\table_atlas.png"
[TableWood]::Write256($out)
Write-Host "wrote $out bytes=$((Get-Item $out).Length)"
