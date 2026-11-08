# Pack generated desk product-photos into a 256 PS1-style atlas.
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$code = @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;

public static class DeskAtlas {
    static bool IsBg(Color c) {
        return c.R >= 245 && c.G >= 245 && c.B >= 245;
    }

    public static Rectangle Trim(Bitmap src) {
        int minx = src.Width, miny = src.Height, maxx = 0, maxy = 0;
        for (int y = 0; y < src.Height; y++) {
            for (int x = 0; x < src.Width; x++) {
                if (IsBg(src.GetPixel(x, y))) continue;
                if (x < minx) minx = x;
                if (y < miny) miny = y;
                if (x > maxx) maxx = x;
                if (y > maxy) maxy = y;
            }
        }
        if (maxx < minx) return new Rectangle(0, 0, src.Width, src.Height);
        minx = Math.Max(0, minx - 2);
        miny = Math.Max(0, miny - 2);
        maxx = Math.Min(src.Width - 1, maxx + 2);
        maxy = Math.Min(src.Height - 1, maxy + 2);
        return Rectangle.FromLTRB(minx, miny, maxx + 1, maxy + 1);
    }

    static void Fit(Graphics g, Image img, Rectangle src, Rectangle dst) {
        float sa = (float)src.Width / src.Height;
        float da = (float)dst.Width / dst.Height;
        Rectangle d = dst;
        if (sa > da) {
            int h = Math.Max(1, (int)(dst.Width / sa));
            d.Y += (dst.Height - h) / 2;
            d.Height = h;
        } else {
            int w = Math.Max(1, (int)(dst.Height * sa));
            d.X += (dst.Width - w) / 2;
            d.Width = w;
        }
        g.DrawImage(img, d, src, GraphicsUnit.Pixel);
    }

    public static void Pack(string topPath, string underPath, string heroPath, string outPath) {
        using (Bitmap top = (Bitmap)Image.FromFile(topPath))
        using (Bitmap under = (Bitmap)Image.FromFile(underPath))
        using (Bitmap hero = (Bitmap)Image.FromFile(heroPath))
        using (Bitmap atlas = new Bitmap(256, 256, PixelFormat.Format24bppRgb))
        using (Graphics g = Graphics.FromImage(atlas)) {
            g.Clear(Color.White);
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            g.SmoothingMode = SmoothingMode.HighQuality;

            Rectangle topBox = Trim(top);
            // Drop the mug on the right of the generated top-down.
            topBox.Width = Math.Max(8, (int)(topBox.Width * 0.56));
            Rectangle underBox = Trim(under);
            Rectangle heroBox = Trim(hero);

            Rectangle rFront = new Rectangle(4, 4, 140, 28);
            Rectangle rTop = new Rectangle(4, 36, 140, 118);
            Rectangle rUnder = new Rectangle(4, 158, 140, 94);
            Rectangle rHero = new Rectangle(148, 4, 104, 248);

            Fit(g, top, topBox, rTop);
            Fit(g, under, underBox, rUnder);
            Fit(g, hero, heroBox, rHero);

            // Thin front strip: edge of the tabletop photo, slightly darker (edge banding).
            Rectangle topEdge = new Rectangle(topBox.X, topBox.Y + topBox.Height - Math.Max(6, topBox.Height / 10), topBox.Width, Math.Max(6, topBox.Height / 10));
            Fit(g, top, topEdge, rFront);
            using (Brush dim = new SolidBrush(Color.FromArgb(55, 40, 28, 16))) {
                g.FillRectangle(dim, rFront);
            }

            atlas.Save(outPath, ImageFormat.Png);
        }
    }
}
'@

Add-Type -TypeDefinition $code -ReferencedAssemblies System.Drawing

$srcRoot = "C:\Users\morrayne\.cursor\projects\c-Users-morrayne-Desktop-gamedev-godot-told-you-so\assets"
$out = "c:\Users\morrayne\Desktop\gamedev\godot\told-you-so\assets\textures\ps1\table_atlas.png"
New-Item -ItemType Directory -Force -Path (Split-Path $out) | Out-Null
[DeskAtlas]::Pack(
    (Join-Path $srcRoot "desk_top_empty.jpg"),
    (Join-Path $srcRoot "desk_under_ortho.jpg"),
    (Join-Path $srcRoot "desk_atlas_ps1style.jpg"),
    $out
)
Write-Host "wrote $out bytes=$((Get-Item $out).Length)"
