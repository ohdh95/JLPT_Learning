"""Export the committed SVG to Android, iOS and Linux launcher assets.

Run with Python packages cairosvg and Pillow installed. No font is required:
the SVG stores the Japanese character as an outline.
"""

import io
import json
from pathlib import Path
import xml.etree.ElementTree as ET

import cairosvg
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ANDROID = ROOT / 'android/app/src/main/res'
SVG = ROOT / 'design/app_icon.svg'


def vector(paths):
    lines = [
        '<vector xmlns:android="http://schemas.android.com/apk/res/android"',
        '    android:width="108dp" android:height="108dp"',
        '    android:viewportWidth="108" android:viewportHeight="108">',
    ]
    for path in paths:
        lines.append(
            f'    <path android:fillColor="{path.attrib["fill"]}" '
            f'android:pathData="{path.attrib["d"]}" />'
        )
    return '\n'.join(lines) + '\n</vector>\n'


def main():
    svg = ET.parse(SVG).getroot()
    paths = svg.findall('{http://www.w3.org/2000/svg}path')
    background = next(p for p in paths if p.attrib['id'] == 'background')
    foreground = [p for p in paths if p is not background]
    (ANDROID / 'drawable/ic_launcher_jlpt.xml').write_text(vector(paths))
    (ANDROID / 'drawable/ic_launcher_foreground.xml').write_text(
        vector(foreground)
    )
    (ANDROID / 'values/icon_colors.xml').write_text(
        '<resources>\n'
        f'    <color name="ic_launcher_background">{background.attrib["fill"]}</color>\n'
        '</resources>\n'
    )
    adaptive_dir = ANDROID / 'mipmap-anydpi-v26'
    adaptive_dir.mkdir(exist_ok=True)
    (adaptive_dir / 'ic_launcher.xml').write_text(
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background" />\n'
        '    <foreground android:drawable="@drawable/ic_launcher_foreground" />\n'
        '</adaptive-icon>\n'
    )
    master = Image.open(io.BytesIO(cairosvg.svg2png(url=str(SVG))))
    master = master.convert('RGB')
    master.save(ROOT / 'design/app_icon.png')
    for density, size in {
        'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192
    }.items():
        master.resize((size, size), Image.Resampling.LANCZOS).save(
            ANDROID / f'mipmap-{density}/ic_launcher.png'
        )
    ios = ROOT / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    entries = json.loads((ios / 'Contents.json').read_text())['images']
    for entry in entries:
        size = round(float(entry['size'].split('x')[0]) *
                     float(entry['scale'].rstrip('x')))
        master.resize((size, size), Image.Resampling.LANCZOS).save(
            ios / entry['filename']
        )
    print('Exported Android vector/adaptive/legacy icons, iOS PNGs and preview.')


if __name__ == '__main__':
    main()
