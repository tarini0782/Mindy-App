import base64, sys
from sprites_src import sprites
from playwright.sync_api import sync_playwright
names = sys.argv[2:] or list(sprites)
cells = ''.join(
    f'<div class="c"><img src="data:image/svg+xml;base64,{base64.b64encode(sprites[n].encode()).decode()}"><div>{n}</div></div>'
    for n in names)
html = f'<html><body style="margin:0;background:#e9f2ff;font:12px sans-serif"><style>.c{{display:inline-block;width:170px;text-align:center;margin:6px}} img{{width:150px;height:150px;background:rgba(255,255,255,.4);border-radius:12px}}</style>{cells}</body></html>'
open('/tmp/sheet.html','w').write(html)
with sync_playwright() as p:
    b = p.chromium.launch(executable_path='/opt/pw-browsers/chromium', args=['--no-sandbox'])
    pg = b.new_page(viewport={'width': 1240, 'height': 800})
    pg.goto('file:///tmp/sheet.html'); pg.screenshot(path=sys.argv[1], full_page=True); b.close()
