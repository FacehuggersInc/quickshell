from colormath.color_objects import sRGBColor, LabColor
from colormath.color_conversions import convert_color


# ---------- Basic Conversions ----------

def hex_to_rgb(hex_color):
    hex_color = hex_color.lstrip("#")
    return tuple(int(hex_color[i:i+2], 16) / 255 for i in (0, 2, 4))


def rgb_to_hex(rgb):
    return "#{:02x}{:02x}{:02x}".format(
        int(max(0, min(1, rgb[0])) * 255),
        int(max(0, min(1, rgb[1])) * 255),
        int(max(0, min(1, rgb[2])) * 255),
    )


def hex_to_lab(hex_color):
    rgb = sRGBColor(*hex_to_rgb(hex_color))
    return convert_color(rgb, LabColor)


def lab_to_hex(lab):
    rgb = convert_color(lab, sRGBColor)
    return rgb_to_hex((rgb.clamped_rgb_r, rgb.clamped_rgb_g, rgb.clamped_rgb_b))


# ---------- Sorting by Perceptual Brightness ----------

def sort_by_lightness(hex_colors):
    return sorted(hex_colors, key=lambda c: hex_to_lab(c).lab_l)


# ---------- Interpolation in LAB ----------

def interpolate_lab(lab1, lab2, t):
    return LabColor(
        lab_l=lab1.lab_l + (lab2.lab_l - lab1.lab_l) * t,
        lab_a=lab1.lab_a + (lab2.lab_a - lab1.lab_a) * t,
        lab_b=lab1.lab_b + (lab2.lab_b - lab1.lab_b) * t,
    )


# ---------- Generate Scale (50–900 style) ----------
# Scale goes 50 (darkest) → 900 (lightest), matching the
# dark-mode convention where low numbers = dark backgrounds.

def generate_scale(hex_colors, steps=9):
    sorted_colors = sort_by_lightness(hex_colors)

    dark_lab = hex_to_lab(sorted_colors[0])
    light_lab = hex_to_lab(sorted_colors[-1])

    # Dark mode optimised range:
    # - floor at L=4  so backgrounds are near-black but retain hue
    # - ceiling at L=88 so lightest text/accent is bright but not
    #   clinical white — avoids eye strain against dark backgrounds
    MIN_L = 4
    MAX_L = 88

    scale = {}
    labels = [50, 100, 200, 300, 400, 500, 600, 700, 800, 900]

    for i in range(steps + 1):
        t = i / steps
        lab = interpolate_lab(dark_lab, light_lab, t)
        lab.lab_l = MIN_L + (MAX_L - MIN_L) * t
        scale[labels[i]] = lab_to_hex(lab)

    return scale


# ---------- Contrast (WCAG-ish) ----------

def relative_luminance(rgb):
    def f(c):
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = map(f, rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast_ratio(hex1, hex2):
    l1 = relative_luminance(hex_to_rgb(hex1))
    l2 = relative_luminance(hex_to_rgb(hex2))
    lighter, darker = max(l1, l2), min(l1, l2)
    return (lighter + 0.05) / (darker + 0.05)


# ---------- Pick Accessible Text ----------

def pick_text_color(bg, scale):
    darkest  = scale[50]
    lightest = scale[900]

    contrast_light = contrast_ratio(bg, lightest)
    contrast_dark  = contrast_ratio(bg, darkest)

    if contrast_light >= contrast_dark:
        return lightest
    return darkest


# ---------- Build Theme ----------
# Dark mode scale mapping (50 = darkest, 900 = lightest):
#
#   background  scale[50]   L≈4   true near-black, tinted with wallpaper hue
#   surface     scale[100]  L≈13  cards / panels — just visibly lifted off bg
#   primary     scale[400]  L≈42  mid accent — visible on dark bg, not washed out
#   secondary   scale[300]  L≈32  softer accent for subtitles / dividers
#   text        scale[900]  L≈88  near-white — high contrast but not pure white
#
# Light mode reverses the mapping so bg=lightest, text=darkest.

def build_theme(hex_colors, mode="dark"):
    scale = generate_scale(hex_colors)

    if mode == "dark":
        bg        = scale[50]
        surface   = scale[100]
        primary   = scale[400]
        secondary = scale[300]
    else:
        bg        = scale[900]
        surface   = scale[800]
        primary   = scale[500]
        secondary = scale[600]

    text = pick_text_color(bg, scale)

    return {
        "mode":       mode,
        "background": bg,
        "surface":    surface,
        "primary":    primary,
        "secondary":  secondary,
        "text":       text,
    }