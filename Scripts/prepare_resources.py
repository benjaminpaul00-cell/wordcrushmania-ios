"""Package the existing logo as an opaque App Store icon; no new artwork is generated."""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
catalog = ROOT / 'App/Resources/Assets.xcassets'
logo = Image.open(catalog / 'Logo.imageset/word_crush_mania_logo_cutout.png').convert('RGBA')
logo.thumbnail((920, 920), Image.Resampling.LANCZOS)
icon = Image.new('RGBA', (1024, 1024), (31, 15, 60, 255))
icon.alpha_composite(logo, ((1024-logo.width)//2, (1024-logo.height)//2))
folder = catalog / 'AppIcon.appiconset'
folder.mkdir(parents=True, exist_ok=True)
icon.convert('RGB').save(folder / 'AppIcon.png')
(folder/'Contents.json').write_text(json.dumps({
    'images': [{'filename':'AppIcon.png', 'idiom':'universal', 'platform':'ios', 'size':'1024x1024'}],
    'info': {'author':'xcode', 'version':1}
}, indent=2)+'\n', encoding='utf-8')
(catalog/'Contents.json').write_text(json.dumps({'info':{'author':'xcode','version':1}})+'\n', encoding='utf-8')
print('Prepared opaque 1024 x 1024 app icon from existing logo.')
