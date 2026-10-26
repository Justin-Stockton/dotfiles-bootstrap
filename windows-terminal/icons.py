#!/usr/bin/env python3
"""Draw the Windows Terminal profile icons as SVG and render the 64px PNGs Terminal loads.

Each icon is a Catppuccin Mocha tile tinted with one accent plus a stroked glyph. Add an
entry to ICONS, run this script (needs rsvg-convert), and map profiles to it in
windows-terminal.ps1.
"""
import shutil
import subprocess
from pathlib import Path

BASE = "#1E1E2E"
ACCENTS = {
    "rosewater": "#F5E0DC", "flamingo": "#F2CDCD", "pink": "#F5C2E7", "mauve": "#CBA6F7",
    "red": "#F38BA8", "maroon": "#EBA0AC", "peach": "#FAB387", "yellow": "#F9E2AF",
    "green": "#A6E3A1", "teal": "#94E2D5", "sky": "#89DCEB", "sapphire": "#74C7EC",
    "blue": "#89B4FA", "lavender": "#B4BEFE", "subtext": "#BAC2DE",
}


def dot(x, y, r=1.1):
    return f'<circle cx="{x}" cy="{y}" r="{r}" fill="currentColor" stroke="none"/>'


# name: (accent, glyph drawn on a 32x32 grid with currentColor strokes)
ICONS = {
    # Shells and tools
    "terminal": ("green", '<rect x="6" y="8" width="20" height="16" rx="2.5"/><line x1="6" y1="12.5" x2="26" y2="12.5"/>'
                 '<polyline points="10,16 13,18.5 10,21"/><line x1="15" y1="21" x2="20" y2="21"/>'),
    "powershell": ("blue", '<polyline points="8,10 14,16 8,22"/><line x1="16.5" y1="22" x2="24.5" y2="22"/>'),
    "pwsh": ("lavender", '<path d="M10,8.5 H26.5 L22,23.5 H5.5 Z"/><polyline points="11,12.5 15,16 11,19.5"/>'
             '<line x1="16.5" y1="19.5" x2="20" y2="19.5"/>'),
    "cmd": ("subtext", '<path d="M13.5,11 A5.6,5.6 0 1 0 13.5,21"/>' + dot(17, 12.6) + dot(17, 19.4)
            + '<line x1="20" y1="9.5" x2="25" y2="22.5"/>'),
    "azure": ("sapphire", '<path d="M10.5,22 H22.5 A4.2,4.2 0 0 0 22.8,13.6 A6,6 0 0 0 11.6,15.2 A3.4,3.4 0 0 0 10.5,22 Z"/>'),
    "developer": ("mauve", '<polyline points="11,10 6,16 11,22"/><polyline points="21,10 26,16 21,22"/>'
                  '<line x1="18" y1="9" x2="14" y2="23"/>'),
    "git": ("maroon", '<circle cx="11" cy="9.5" r="2.3"/><circle cx="11" cy="22.5" r="2.3"/><circle cx="21" cy="12.5" r="2.3"/>'
            '<line x1="11" y1="11.8" x2="11" y2="20.2"/><path d="M21,14.8 C21,19 11,17 11,20.2"/>'),
    "ssh": ("flamingo", '<circle cx="11" cy="16" r="4.5"/><line x1="15.5" y1="16" x2="26" y2="16"/>'
            '<line x1="22" y1="16" x2="22" y2="20"/><line x1="25.5" y1="16" x2="25.5" y2="19"/>'),
    "docker": ("sapphire", '<rect x="7.5" y="14" width="5" height="4" rx="0.6"/><rect x="13.5" y="14" width="5" height="4" rx="0.6"/>'
               '<rect x="19.5" y="14" width="5" height="4" rx="0.6"/><rect x="13.5" y="9" width="5" height="4" rx="0.6"/>'
               '<path d="M6,21.5 Q16,26 26.5,20"/>'),
    "nushell": ("yellow", '<polyline points="7,10 12,16 7,22"/><line x1="15" y1="11" x2="25" y2="11"/>'
                '<line x1="15" y1="16" x2="25" y2="16"/><line x1="15" y1="21" x2="25" y2="21"/>'),
    "fish": ("teal", '<path d="M6.5,16 C10.5,9.5 18.5,9.5 22.5,16 C18.5,22.5 10.5,22.5 6.5,16 Z"/>'
             '<polyline points="22.5,16 26.5,11.5 26.5,20.5 22.5,16"/>' + dot(11.5, 15)),
    "python": ("peach", '<polyline points="6,11 10,16 6,21"/><polyline points="12,11 16,16 12,21"/>'
               '<polyline points="18,11 22,16 18,21"/>'),
    # Linux distributions
    "ubuntu": ("peach", '<polyline points="8,10 14,16 8,22"/><path d="M17,17.5 c1.6,-2.6 3.4,-2.6 5,0 s3.4,2.6 5,0"/>'),
    "debian": ("red", '<path d="M16.5,16.5 a1.6,1.6 0 0 1 3.2,0 a3.2,3.2 0 0 1 -6.4,0 a4.8,4.8 0 0 1 9.6,0 a6.4,6.4 0 0 1 -12.8,0"/>'),
    "fedora": ("sapphire", '<circle cx="16" cy="16" r="8.5"/><path d="M20,11 H18.5 a2.5,2.5 0 0 0 -2.5,2.5 V22"/>'
               '<line x1="12.5" y1="16" x2="19" y2="16"/>'),
    "arch": ("lavender", '<polyline points="7.5,23.5 16,8 24.5,23.5"/><path d="M12.5,23.5 Q16,17.5 19.5,23.5"/>'),
    "alpine": ("teal", '<polygon points="5.5,23 12.5,12 16.5,18 20,13.5 26.5,23"/>'),
    "opensuse": ("green", '<circle cx="19.5" cy="13" r="3.5"/>' + dot(20, 13, 1.2)
                 + '<path d="M25,19.5 C22,23.5 13,23.5 10,20 C8.2,17.8 9.6,15.2 12,15.4 C14,15.6 14.4,18.2 12.8,18.6"/>'),
    "kali": ("pink", '<path d="M10.5,8.5 Q7,16 10.5,23.5"/><path d="M16.5,8 Q13,16 16.5,24"/><path d="M22.5,8.5 Q19,16 22.5,23.5"/>'),
    "nixos": ("sky", '<line x1="16" y1="7.5" x2="16" y2="24.5"/><line x1="8.6" y1="11.75" x2="23.4" y2="20.25"/>'
              '<line x1="8.6" y1="20.25" x2="23.4" y2="11.75"/><polyline points="13.6,9.4 16,11.6 18.4,9.4"/>'
              '<polyline points="13.6,22.6 16,20.4 18.4,22.6"/>'),
    "linux": ("rosewater", '<ellipse cx="16" cy="17" rx="6.5" ry="7.5"/><ellipse cx="16" cy="19.2" rx="3.4" ry="4.4"/>'
              + dot(14, 13) + dot(18, 13) + '<polyline points="15,15 16,16.2 17,15"/>'
              '<line x1="11" y1="25.5" x2="14" y2="25.5"/><line x1="18" y1="25.5" x2="21" y2="25.5"/>'),
}


def svg(accent, glyph):
    color = ACCENTS[accent]
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" width="32" height="32">
  <rect x="1" y="1" width="30" height="30" rx="7" fill="{BASE}"/>
  <rect x="1" y="1" width="30" height="30" rx="7" fill="{color}" fill-opacity="0.14" stroke="{color}" stroke-opacity="0.45"/>
  <g color="{color}" fill="none" stroke="{color}" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round">{glyph}</g>
</svg>
'''


def main():
    out = Path(__file__).resolve().parent / "icons"
    out.mkdir(exist_ok=True)
    renderer = shutil.which("rsvg-convert")
    for name, (accent, glyph) in ICONS.items():
        path = out / f"{name}.svg"
        path.write_text(svg(accent, glyph))
        if renderer:
            subprocess.run([renderer, "-w", "64", "-h", "64", str(path), "-o", str(path.with_suffix(".png"))], check=True)
    if not renderer:
        print("rsvg-convert not found; wrote SVGs only. Install librsvg to render PNGs.")


if __name__ == "__main__":
    main()
