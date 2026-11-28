# Face-moon textures: TheCoberto's face blended into a cratered moon.
# Dot-sourced by build.ps1. Needs $root.
Add-Type -AssemblyName System.Drawing
if (-not ('FaceMoon' -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class FaceMoon {
    static byte[] Read(Bitmap b) {
        var d = b.LockBits(new Rectangle(0, 0, b.Width, b.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        var px = new byte[d.Stride * b.Height];
        Marshal.Copy(d.Scan0, px, 0, px.Length);
        b.UnlockBits(d);
        return px;
    }
    static double Hash(int x, int y, int s) {
        unchecked {
            uint h = (uint)(x * 374761393 + y * 668265263 + s * 982451653);
            h = (h ^ (h >> 13)) * 1274126177u;
            return ((h ^ (h >> 16)) & 0xffffff) / (double)0xffffff;
        }
    }
    static double Noise(double x, double y, int s) {
        int xi = (int)Math.Floor(x), yi = (int)Math.Floor(y);
        double fx = x - xi, fy = y - yi;
        fx = fx * fx * (3 - 2 * fx); fy = fy * fy * (3 - 2 * fy);
        double a = Hash(xi, yi, s), b = Hash(xi + 1, yi, s), c = Hash(xi, yi + 1, s), d = Hash(xi + 1, yi + 1, s);
        return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy;
    }
    static double Fbm(double x, double y, int s) {
        double v = 0, amp = 0.5;
        for (int o = 0; o < 5; o++) { v += amp * Noise(x, y, s + o); x *= 2; y *= 2; amp *= 0.5; }
        return v;
    }

    // face: the face already cropped and scaled to size x size.
    public static Bitmap Make(Bitmap face, int size, int seed) {
        var f = Read(face);
        var rnd = new Random(seed);
        int n = 60;
        var cx = new double[n]; var cy = new double[n]; var cr = new double[n]; var cd = new double[n];
        for (int i = 0; i < n; i++) {
            cx[i] = rnd.NextDouble() * size; cy[i] = rnd.NextDouble() * size;
            double t = rnd.NextDouble();
            cr[i] = size * (0.008 + 0.06 * t * t * t);
            cd[i] = 0.12 + 0.22 * rnd.NextDouble();
        }
        var outB = new Bitmap(size, size, PixelFormat.Format32bppArgb);
        var od = outB.LockBits(new Rectangle(0, 0, size, size), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
        var o = new byte[od.Stride * size];
        double R = size * 0.47, c0 = size / 2.0;
        for (int y = 0; y < size; y++) for (int x = 0; x < size; x++) {
            int i = y * od.Stride + x * 4;
            double dx = x + 0.5 - c0, dy = y + 0.5 - c0, d = Math.Sqrt(dx * dx + dy * dy) / R;
            double edge = Math.Max(0, Math.Min(1, (1 - d) * R));
            if (edge <= 0) continue;   // transparent black outside the moon
            // Face brightness, contrast boosted
            int fi = y * size * 4 + x * 4;
            double fa = f[fi + 3] / 255.0;
            double lum = fa * (0.299 * f[fi + 2] + 0.587 * f[fi + 1] + 0.114 * f[fi]) / 255.0;
            double F = Math.Max(0, Math.Min(1, (lum - 0.28) * 2.1));
            // Maria (dark seas) and fine surface noise
            double mare = Fbm(x / (size * 0.28), y / (size * 0.28), seed + 50);
            double surf = 0.85 + 0.15 * Fbm(x / (size * 0.04), y / (size * 0.04), seed + 90);
            double C = surf * (1 - 0.45 * Math.Max(0, Math.Min(1, (mare - 0.45) * 3)));
            // Craters: dark bowl, light rim, lit from the upper left
            for (int k = 0; k < n; k++) {
                double ex = x - cx[k], ey = y - cy[k], dd = Math.Sqrt(ex * ex + ey * ey) / cr[k];
                if (dd < 1) C *= 1 - cd[k] * (1 - dd * dd) * (0.6 + 0.4 * ((ex + ey) / (cr[k] * 1.42) * 0.5 + 0.5));
                else if (dd < 1.2) C *= 1 + cd[k] * 0.18 * (1 - (dd - 1) / 0.2);
            }
            double limb = 0.62 + 0.38 * Math.Sqrt(Math.Max(0, 1 - d * d));
            double v = (0.22 + 0.78 * F) * C * limb * edge;
            v = Math.Max(0, Math.Min(1, v));
            o[i + 2] = (byte)(v * 236); o[i + 1] = (byte)(v * 234); o[i] = (byte)(v * 222); o[i + 3] = (byte)(255 * edge);
        }
        Marshal.Copy(o, 0, od.Scan0, o.Length);
        outB.UnlockBits(od);
        return outB;
    }
}
'@
}

$faceSrc = Join-Path $root 'sources\sky-face.png'
# Phases in the game's order (also the order of the old 4x2 grid).
$moonPhases = 'full_moon', 'waning_gibbous', 'third_quarter', 'waning_crescent', 'new_moon', 'waxing_crescent', 'first_quarter', 'waxing_gibbous'
# Every phase is the face: the CobertoUtilities plugin picks which nights the pack is sent.
$facePhases = $moonPhases

function New-FaceMoon([int]$size) {
    $src = [Drawing.Image]::FromFile($faceSrc)
    $crop = [Drawing.Bitmap]::new($size, $size)
    $g = [Drawing.Graphics]::FromImage($crop)
    $g.InterpolationMode = 'HighQualityBicubic'
    # Forehead to chin of the 1008x1452 source, so the face fills the moon
    $g.DrawImage($src, [Drawing.Rectangle]::new(0, 0, $size, $size), [Drawing.Rectangle]::new(205, 60, 590, 640), 'Pixel')
    $g.Dispose(); $src.Dispose()
    $moon = [FaceMoon]::Make($crop, $size, 7)
    $crop.Dispose()
    $moon
}
# Writes the moon textures. -Layout Files: 1.21.11+ (one png per phase). Grid: older Java and Bedrock.
function Save-Moon([string]$dir, [ValidateSet('Files', 'Grid')]$Layout, [int]$tile = 256) {
    New-Item -ItemType Directory -Force $dir | Out-Null
    $faceMoon = New-FaceMoon $tile
    if ($Layout -eq 'Files') {
        foreach ($p in $facePhases) { $faceMoon.Save("$dir\$p.png", [Drawing.Imaging.ImageFormat]::Png) }
    } else {
        $grid = [Drawing.Bitmap]::new($tile * 4, $tile * 2)
        $g = [Drawing.Graphics]::FromImage($grid)
        $g.Clear([Drawing.Color]::Transparent)
        for ($i = 0; $i -lt 8; $i++) {
            $g.DrawImage($faceMoon, ($i % 4) * $tile, [math]::Floor($i / 4) * $tile, $tile, $tile)
        }
        $g.Dispose(); $grid.Save("$dir\moon_phases.png", [Drawing.Imaging.ImageFormat]::Png); $grid.Dispose()
    }
    $faceMoon.Dispose()
}
