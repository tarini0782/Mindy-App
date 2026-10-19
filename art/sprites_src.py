# Original Mindy sprites as SVG (viewBox 0 0 100 100 unless noted).
# Every directional sprite FACES RIGHT (or UP for top-down vehicles).
OUT = '#5b3a6b'   # shared outline colour: soft plum
def g(id, c1, c2, vertical=True):
    d = 'x1="0" y1="0" x2="0" y2="1"' if vertical else 'x1="0" y1="0" x2="1" y2="0"'
    return f'<linearGradient id="{id}" {d}><stop offset="0" stop-color="{c1}"/><stop offset="1" stop-color="{c2}"/></linearGradient>'
def svg(body, defs='', vb='0 0 100 100'):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{vb}"><defs>{defs}</defs>{body}</svg>'
S = f'stroke="{OUT}" stroke-width="3" stroke-linejoin="round" stroke-linecap="round"'
def eye(x, y, r=4.2):
    return (f'<circle cx="{x}" cy="{y}" r="{r}" fill="#3b2a4a"/>'
            f'<circle cx="{x+r*0.35}" cy="{y-r*0.4}" r="{r*0.38}" fill="#fff"/>')
def smile(x1, y, x2, dip=5):
    return f'<path d="M{x1} {y} Q{(x1+x2)/2} {y+dip} {x2} {y}" fill="none" stroke="#3b2a4a" stroke-width="2.4" stroke-linecap="round"/>'
def blush(x, y, r=4.5):
    return f'<ellipse cx="{x}" cy="{y}" rx="{r}" ry="{r*0.7}" fill="#ff8fab" opacity=".55"/>'

sprites = {}

# ---------- items ----------
sprites['star'] = svg(
    f'<path d="M50 8 L61 36 L92 38 L68 57 L76 88 L50 71 L24 88 L32 57 L8 38 L39 36 Z" fill="url(#a)" {S}/>'
    '<path d="M44 20 L50 30" stroke="#fff" stroke-width="4" stroke-linecap="round" opacity=".8"/>'
    + eye(41, 50, 3.6) + eye(59, 50, 3.6) + smile(43, 60, 57, 5) + blush(35, 58, 4) + blush(65, 58, 4),
    g('a', '#ffe066', '#ffb703'))

sprites['carrot'] = svg(
    '<path d="M40 14 Q44 2 50 12 Q56 0 60 14 Q52 24 40 14Z" fill="#5fc86e" stroke="#2f7d3a" stroke-width="2.5" stroke-linejoin="round"/>'
    f'<path d="M32 26 Q50 14 68 26 Q64 60 52 92 Q50 96 48 92 Q36 60 32 26Z" fill="url(#a)" {S}/>'
    '<path d="M40 38 L50 40 M44 56 L53 58 M47 72 L53 73" stroke="#e07a00" stroke-width="2.4" stroke-linecap="round"/>'
    '<path d="M39 28 Q41 40 42 50" stroke="#fff" stroke-width="3" stroke-linecap="round" opacity=".6" fill="none"/>',
    g('a', '#ffa94d', '#ff7b00'))

sprites['apple'] = svg(
    f'<path d="M50 28 C30 14 8 30 14 56 C18 80 36 94 50 88 C64 94 82 80 86 56 C92 30 70 14 50 28Z" fill="url(#a)" {S}/>'
    '<path d="M50 28 Q50 16 56 8" stroke="#6b4423" stroke-width="4" stroke-linecap="round" fill="none"/>'
    '<path d="M56 14 Q70 4 80 16 Q66 24 56 14Z" fill="#5fc86e" stroke="#2f7d3a" stroke-width="2.5" stroke-linejoin="round"/>'
    '<path d="M24 44 Q22 56 28 66" stroke="#fff" stroke-width="5" stroke-linecap="round" opacity=".6" fill="none"/>',
    g('a', '#ff6b6b', '#d62828'))

sprites['orange'] = svg(
    f'<circle cx="50" cy="55" r="38" fill="url(#a)" {S}/>'
    '<path d="M50 18 Q56 8 66 12 Q60 22 50 18Z" fill="#5fc86e" stroke="#2f7d3a" stroke-width="2.5" stroke-linejoin="round"/>'
    '<path d="M26 44 Q22 56 28 68" stroke="#fff" stroke-width="5" stroke-linecap="round" opacity=".55" fill="none"/>'
    '<g fill="#e07a00" opacity=".5"><circle cx="58" cy="50" r="1.6"/><circle cx="66" cy="62" r="1.6"/><circle cx="50" cy="70" r="1.6"/><circle cx="44" cy="52" r="1.6"/></g>',
    g('a', '#ffc94d', '#ff9500'))

sprites['strawberry'] = svg(
    f'<path d="M50 94 C20 74 10 44 22 30 C34 20 44 28 50 26 C56 28 66 20 78 30 C90 44 80 74 50 94Z" fill="url(#a)" {S}/>'
    '<path d="M30 26 L40 16 L50 24 L60 16 L70 26 Q50 34 30 26Z" fill="#5fc86e" stroke="#2f7d3a" stroke-width="2.5" stroke-linejoin="round"/>'
    '<g fill="#ffe8a3"><ellipse cx="36" cy="48" rx="2" ry="3"/><ellipse cx="52" cy="46" rx="2" ry="3"/><ellipse cx="66" cy="50" rx="2" ry="3"/><ellipse cx="44" cy="64" rx="2" ry="3"/><ellipse cx="58" cy="66" rx="2" ry="3"/><ellipse cx="50" cy="80" rx="2" ry="3"/></g>',
    g('a', '#ff5d73', '#d90429'))

sprites['watermelon'] = svg(
    f'<path d="M6 40 A44 44 0 0 0 94 40 Z" fill="#5fc86e" {S}/>'
    '<path d="M13 40 A37 37 0 0 0 87 40 Z" fill="url(#a)"/>'
    '<g fill="#3b2a4a"><ellipse cx="34" cy="52" rx="2.4" ry="4" transform="rotate(-15 34 52)"/><ellipse cx="50" cy="60" rx="2.4" ry="4"/><ellipse cx="66" cy="52" rx="2.4" ry="4" transform="rotate(15 66 52)"/></g>'
    f'<path d="M6 40 L94 40" {S}/>'
    ,
    g('a', '#ff6b81', '#e63950'), vb='0 12 100 70')

sprites['sock'] = svg(
    f'<path d="M34 10 H62 V50 L84 66 Q92 76 82 86 Q72 94 60 84 L30 62 Q24 56 26 48 Z" fill="url(#a)" {S}/>'
    '<rect x="32" y="10" width="32" height="14" rx="4" fill="#9bbcff" stroke="#5b3a6b" stroke-width="3"/>'
    '<path d="M30 34 H62 M30 44 H62" stroke="#fff" stroke-width="5" opacity=".7"/>'
    '<path d="M70 22 Q76 16 72 10 M80 30 Q88 24 82 16" stroke="#7bd88f" stroke-width="3.2" stroke-linecap="round" fill="none"/>'
    + eye(40, 70, 0.1),
    g('a', '#ff9ec7', '#e0549b'))

sprites['rock'] = svg(
    f'<path d="M14 80 Q6 56 22 36 Q34 16 58 20 Q82 24 90 52 Q96 76 82 84 Q50 92 14 80Z" fill="url(#a)" {S}/>'
    '<path d="M36 34 L42 48 L34 58 M62 40 L58 56 L68 66" stroke="#6c757d" stroke-width="2.6" fill="none" stroke-linecap="round"/>'
    '<path d="M26 44 Q28 36 36 30" stroke="#fff" stroke-width="4" stroke-linecap="round" opacity=".5" fill="none"/>',
    g('a', '#ced4da', '#868e96'))

sprites['basket'] = svg(
    '<path d="M22 44 Q50 -4 78 44" fill="none" stroke="#8b5a2b" stroke-width="6" stroke-linecap="round"/>'
    f'<path d="M10 44 H90 L80 88 Q50 98 20 88Z" fill="url(#a)" {S}/>'
    '<path d="M16 58 H84 M18 72 H82 M36 46 L34 90 M50 46 V94 M64 46 L66 90" stroke="#8b5a2b" stroke-width="2.4" opacity=".7" stroke-linecap="round"/>',
    g('a', '#e9b872', '#c98a3c'))

sprites['heart'] = svg(
    f'<path d="M50 88 C10 58 6 30 28 22 C40 18 48 26 50 32 C52 26 60 18 72 22 C94 30 90 58 50 88Z" fill="url(#a)" {S}/>'
    '<path d="M24 36 Q26 30 32 28" stroke="#fff" stroke-width="4" stroke-linecap="round" opacity=".7" fill="none"/>',
    g('a', '#ff8fab', '#ef476f'))

sprites['note'] = svg(
    f'<path d="M40 18 L80 8 V62" fill="none" stroke="{OUT}" stroke-width="9" stroke-linejoin="round" stroke-linecap="round"/>'
    '<path d="M40 18 L80 8 V62" fill="none" stroke="#ff4fa3" stroke-width="4" stroke-linejoin="round" stroke-linecap="round"/>'
    f'<ellipse cx="30" cy="74" rx="18" ry="14" fill="#ff4fa3" {S}/><ellipse cx="68" cy="66" rx="18" ry="14" fill="#ff4fa3" {S}/>'
    '<ellipse cx="25" cy="70" rx="5" ry="3" fill="#fff" opacity=".6"/><ellipse cx="63" cy="62" rx="5" ry="3" fill="#fff" opacity=".6"/>'
    '<path d="M40 18 V74" stroke="#ff4fa3" stroke-width="4"/>',
    '')
sprites['quiet'] = svg(
    f'<circle cx="50" cy="50" r="40" fill="#cfd4da" {S}/>'
    '<path d="M32 42 H42 L56 32 V68 L42 58 H32Z" fill="#8d96a0"/>'
    '<path d="M64 40 L80 60 M80 40 L64 60" stroke="#8d96a0" stroke-width="5" stroke-linecap="round"/>', '')

sprites['cloud'] = svg(
    f'<path d="M20 52 Q8 52 8 40 Q8 28 22 28 Q26 12 44 14 Q56 4 70 16 Q92 14 92 36 Q98 52 82 52Z" fill="url(#a)" {S}/>'
    '<path d="M24 40 Q26 34 32 32" stroke="#fff" stroke-width="4" stroke-linecap="round" fill="none" opacity=".9"/>',
    g('a', '#ffffff', '#e3ecff'), vb='0 0 100 60')

sprites['storm'] = svg(
    f'<path d="M20 56 Q6 56 6 42 Q6 28 22 28 Q26 12 46 14 Q58 4 72 16 Q94 14 94 38 Q100 56 82 56Z" fill="url(#a)" {S}/>'
    '<path d="M30 40 L44 36 M70 40 L56 36" stroke="#3b2a4a" stroke-width="3.4" stroke-linecap="round"/>'
    + eye(38, 46, 3.2) + eye(62, 46, 3.2) + '<path d="M42 56 Q50 50 58 56" stroke="#3b2a4a" stroke-width="2.6" fill="none" stroke-linecap="round"/>'
    '<path d="M54 60 L44 76 L52 76 L46 94 L62 72 L54 72 L60 60Z" fill="#ffe066" stroke="#c98a00" stroke-width="2" stroke-linejoin="round"/>'
    '<path d="M24 66 L20 78 M76 66 L72 78 M34 72 L30 84" stroke="#7aa7ff" stroke-width="3" stroke-linecap="round"/>',
    g('a', '#8d86b3', '#5d5780'))

sprites['spring'] = svg(
    '<path d="M30 90 H70 M34 74 H66 M30 58 H70 M34 42 H66" stroke="#5b3a6b" stroke-width="6" stroke-linecap="round"/>'
    '<path d="M30 90 H70 M34 74 H66 M30 58 H70 M34 42 H66" stroke="#4cc9f0" stroke-width="3" stroke-linecap="round"/>'
    f'<ellipse cx="50" cy="30" rx="26" ry="12" fill="#ff5d8f" {S}/>', '')

sprites['snowflake'] = svg(
    '<g stroke="#5b3a6b" stroke-width="9" stroke-linecap="round"><path d="M50 8 V92 M14 29 L86 71 M14 71 L86 29"/></g>'
    '<g stroke="#bde7ff" stroke-width="5" stroke-linecap="round"><path d="M50 8 V92 M14 29 L86 71 M14 71 L86 29"/></g>'
    '<circle cx="50" cy="50" r="9" fill="#fff" stroke="#5b3a6b" stroke-width="3"/>', '')

sprites['puffy'] = svg(
    f'<ellipse cx="50" cy="56" rx="40" ry="36" fill="url(#a)" {S}/>'
    f'<path d="M26 26 Q22 10 34 14 Q38 22 38 28Z M74 26 Q78 10 66 14 Q62 22 62 28Z" fill="#ff9e7a" {S}/>'
    + eye(36, 52, 5) + eye(64, 52, 5) + blush(26, 64, 6) + blush(74, 64, 6)
    + '<path d="M44 62 Q50 70 56 62" fill="#ff6b81" stroke="#3b2a4a" stroke-width="2.4" stroke-linejoin="round"/>'
    '<path d="M26 88 q4 8 10 0 M64 88 q4 8 10 0" stroke="#5b3a6b" stroke-width="3" fill="none" stroke-linecap="round"/>',
    g('a', '#ffd6a5', '#ffadad'))

sprites['teddy'] = svg(
    f'<circle cx="24" cy="26" r="13" fill="#c98a5b" {S}/><circle cx="76" cy="26" r="13" fill="#c98a5b" {S}/>'
    f'<circle cx="24" cy="26" r="6" fill="#f2c9a0"/><circle cx="76" cy="26" r="6" fill="#f2c9a0"/>'
    f'<circle cx="50" cy="52" r="36" fill="url(#a)" {S}/><ellipse cx="50" cy="64" rx="15" ry="11" fill="#f2c9a0" stroke="#5b3a6b" stroke-width="2.5"/>'
    + eye(37, 46, 4.5) + eye(63, 46, 4.5) + '<ellipse cx="50" cy="59" rx="5" ry="3.6" fill="#3b2a4a"/>' + smile(44, 68, 56, 4),
    g('a', '#d9a066', '#b97a45'))

# ---------- vehicles ----------
sprites['car_up'] = svg(   # top-down, BONNET POINTS UP
    f'<rect x="22" y="8" width="56" height="86" rx="22" fill="url(#a)" {S}/>'
    '<rect x="30" y="34" width="40" height="26" rx="8" fill="#bde7ff" stroke="#5b3a6b" stroke-width="2.5"/>'
    '<path d="M32 20 Q50 12 68 20" stroke="#fff" stroke-width="3.5" fill="none" stroke-linecap="round" opacity=".8"/>'
    '<rect x="14" y="20" width="10" height="20" rx="4" fill="#3b2a4a"/><rect x="76" y="20" width="10" height="20" rx="4" fill="#3b2a4a"/>'
    '<rect x="14" y="62" width="10" height="20" rx="4" fill="#3b2a4a"/><rect x="76" y="62" width="10" height="20" rx="4" fill="#3b2a4a"/>'
    '<circle cx="34" cy="12" r="4" fill="#fff59d" stroke="#5b3a6b" stroke-width="2"/><circle cx="66" cy="12" r="4" fill="#fff59d" stroke="#5b3a6b" stroke-width="2"/>'
    '<rect x="34" y="70" width="32" height="14" rx="5" fill="#ff6b81" opacity=".5"/>',
    g('a', '#ff8fa3', '#e63950'))

# ---------- characters (side view, FACE RIGHT) ----------
sprites['unicorn_side'] = svg(
    # tail (rainbow)
    '<path d="M24 52 Q4 54 8 78 Q10 86 20 84" fill="none" stroke="#5b3a6b" stroke-width="13" stroke-linecap="round"/>'
    '<path d="M24 52 Q4 54 8 78 Q10 86 20 84" fill="none" stroke="#ff6b9d" stroke-width="9" stroke-linecap="round"/>'
    '<path d="M24 54 Q10 58 13 76" fill="none" stroke="#7bd3ff" stroke-width="4" stroke-linecap="round"/>'
    # back legs & front legs
    f'<rect x="30" y="70" width="11" height="24" rx="5" fill="#fff" {S}/><rect x="52" y="70" width="11" height="24" rx="5" fill="#fff" {S}/>'
    f'<rect x="40" y="72" width="11" height="22" rx="5" fill="#f3e9ff" {S}/><rect x="62" y="72" width="11" height="22" rx="5" fill="#f3e9ff" {S}/>'
    '<rect x="30" y="88" width="11" height="6" rx="3" fill="#ffcf5c"/><rect x="52" y="88" width="11" height="6" rx="3" fill="#ffcf5c"/>'
    # body
    f'<ellipse cx="48" cy="58" rx="30" ry="18" fill="url(#a)" {S}/>'
    # neck + head
    f'<path d="M62 54 L70 28 L86 34 L78 62Z" fill="url(#a)" {S}/>'
    f'<ellipse cx="82" cy="32" rx="14" ry="12" fill="url(#a)" {S}/>'
    f'<ellipse cx="92" cy="38" rx="7" ry="6" fill="#ffe4ee" {S}/>'
    # mane
    '<path d="M64 24 Q54 30 60 40 Q50 44 58 54 Q52 60 62 62" fill="none" stroke="#5b3a6b" stroke-width="12" stroke-linecap="round"/>'
    '<path d="M64 24 Q54 30 60 40 Q50 44 58 54 Q52 60 62 62" fill="none" stroke="#b388ff" stroke-width="8" stroke-linecap="round"/>'
    '<path d="M62 28 Q56 34 62 42 Q54 46 60 54" fill="none" stroke="#ff9ec7" stroke-width="3.5" stroke-linecap="round"/>'
    # ear + horn
    f'<path d="M72 22 L70 8 L80 18Z" fill="#fff" {S}/>'
    f'<path d="M84 22 L96 2 L92 24Z" fill="url(#h)" {S}/>'
    + eye(84, 32, 3.8) + blush(80, 40, 3.6) + '<path d="M92 41 Q95 43 97 41" stroke="#3b2a4a" stroke-width="2" fill="none" stroke-linecap="round"/>',
    g('a', '#ffffff', '#efe3ff') + g('h', '#ffe066', '#ffb703'))

sprites['dragon_side'] = svg(
    # tail with spike
    '<path d="M26 66 Q6 66 8 82 Q10 90 22 84" fill="none" stroke="#5b3a6b" stroke-width="13" stroke-linecap="round"/>'
    '<path d="M26 66 Q6 66 8 82 Q10 90 22 84" fill="none" stroke="#5fd48a" stroke-width="9" stroke-linecap="round"/>'
    f'<path d="M8 82 L2 92 L14 90Z" fill="#ffd166" {S}/>'
    # back wing
    f'<path d="M36 56 Q16 28 34 12 Q50 22 54 54Z" fill="url(#w)" {S}/>'
    '<path d="M38 50 Q30 32 36 20 M46 52 Q42 34 44 24" stroke="#fff" stroke-width="2" fill="none" opacity=".6"/>'
    # legs
    f'<rect x="38" y="78" width="12" height="14" rx="6" fill="#5fd48a" {S}/><rect x="60" y="78" width="12" height="14" rx="6" fill="#5fd48a" {S}/>'
    # body + belly
    f'<ellipse cx="52" cy="64" rx="30" ry="24" fill="url(#a)" {S}/>'
    '<ellipse cx="58" cy="70" rx="17" ry="15" fill="#fff0c2"/>'
    '<path d="M46 66 H70 M48 73 H68 M52 80 H64" stroke="#f3d27a" stroke-width="2" stroke-linecap="round"/>'
    # head
    f'<ellipse cx="74" cy="42" rx="19" ry="16" fill="url(#a)" {S}/>'
    f'<ellipse cx="88" cy="48" rx="9" ry="7" fill="#7be0a0" {S}/>'
    '<circle cx="86" cy="46" r="1.4" fill="#3b2a4a"/><circle cx="91" cy="46" r="1.4" fill="#3b2a4a"/>'
    f'<path d="M64 28 L62 14 L72 24Z M76 26 L78 12 L86 26Z" fill="#ffd166" {S}/>'
    + eye(77, 38, 4.4) + blush(74, 48, 3.6) + '<path d="M84 53 Q89 56 92 52" stroke="#3b2a4a" stroke-width="2" fill="none" stroke-linecap="round"/>'
    ''
    ,
    g('a', '#8ff0b0', '#43c776') + g('w', '#ffc2de', '#ff8fbf'))

sprites['dino_side'] = svg(
    '<path d="M30 60 Q8 60 6 80 Q22 80 34 74Z" fill="#7fd77f" stroke="#5b3a6b" stroke-width="3" stroke-linejoin="round"/>'
    f'<rect x="38" y="76" width="13" height="18" rx="6" fill="#5fc86e" {S}/><rect x="58" y="76" width="13" height="18" rx="6" fill="#5fc86e" {S}/>'
    f'<ellipse cx="50" cy="62" rx="28" ry="24" fill="url(#a)" {S}/>'
    '<ellipse cx="56" cy="70" rx="15" ry="13" fill="#e8ffd1"/>'
    f'<path d="M34 42 L38 30 L44 42 M46 38 L52 26 L56 38 M58 38 L64 28 L66 40Z" fill="#ffb347" {S}/>'
    f'<ellipse cx="72" cy="40" rx="20" ry="16" fill="url(#a)" {S}/>'
    f'<path d="M84 46 Q96 46 96 40 Q92 34 86 36Z" fill="#7fd77f" {S}/>'
    + eye(76, 36, 4.6) + blush(72, 46, 3.6) + '<path d="M84 49 Q90 52 94 47" stroke="#3b2a4a" stroke-width="2" fill="none" stroke-linecap="round"/>'
    f'<path d="M56 62 Q62 68 66 62" stroke="#3b2a4a" stroke-width="0"/>',
    g('a', '#9be37b', '#4fb86a'))

# ---------- the six hosts (front view) ----------
def face(cx, cy, e=10, mouth=7):
    return (eye(cx-e, cy, 4.6) + eye(cx+e, cy, 4.6) + blush(cx-e-5, cy+9, 4.8) + blush(cx+e+5, cy+9, 4.8)
            + smile(cx-6, cy+8, cx+6, mouth*0.7))

sprites['host_kara'] = svg(   # unicorn
    '<path d="M16 60 Q4 40 14 24 Q22 40 30 48Z" fill="#ff9ec7" stroke="#5b3a6b" stroke-width="3" stroke-linejoin="round"/>'
    '<path d="M84 60 Q96 40 86 24 Q78 40 70 48Z" fill="#7bd3ff" stroke="#5b3a6b" stroke-width="3" stroke-linejoin="round"/>'
    f'<path d="M30 46 L24 14 L44 30Z" fill="#fff" {S}/><path d="M70 46 L76 14 L56 30Z" fill="#fff" {S}/>'
    f'<path d="M50 -2 L42 30 L58 30Z" fill="url(#h)" {S}/>'
    f'<ellipse cx="50" cy="60" rx="34" ry="32" fill="url(#a)" {S}/>'
    f'<ellipse cx="50" cy="76" rx="16" ry="11" fill="#ffe4ee" stroke="#5b3a6b" stroke-width="2.5"/>'
    '<circle cx="45" cy="75" r="1.6" fill="#3b2a4a"/><circle cx="55" cy="75" r="1.6" fill="#3b2a4a"/>'
    '<path d="M28 34 Q24 52 28 62 M72 34 Q76 52 72 62" stroke="#ff6b9d" stroke-width="7" stroke-linecap="round" fill="none"/>'
    + eye(36, 58, 5.4) + eye(64, 58, 5.4) + blush(27, 68, 5) + blush(73, 68, 5),
    g('a', '#ffffff', '#f1e6ff') + g('h', '#ffe066', '#ffb703'))

sprites['host_nova'] = svg(   # small hero with mask and cape
    '<path d="M18 52 L8 96 L50 88 L92 96 L82 52Z" fill="url(#c)" stroke="#5b3a6b" stroke-width="3" stroke-linejoin="round"/>'
    f'<rect x="32" y="70" width="36" height="26" rx="10" fill="url(#b)" {S}/>'
    '<path d="M50 76 L54 84 L62 84 L56 89 L58 97 L50 92 L42 97 L44 89 L38 84 L46 84Z" fill="#ffe066" stroke="#c98a00" stroke-width="1.6" stroke-linejoin="round"/>'
    f'<circle cx="50" cy="42" r="30" fill="#ffd9b8" {S}/>'
    f'<path d="M20 40 Q22 10 50 12 Q78 10 80 40 Q70 24 50 28 Q30 24 20 40Z" fill="#5b3a6b"/>'
    f'<path d="M20 44 Q50 34 80 44 L78 56 Q64 62 50 54 Q36 62 22 56Z" fill="url(#c)" stroke="#5b3a6b" stroke-width="2.5" stroke-linejoin="round"/>'
    '<circle cx="38" cy="48" r="5.5" fill="#fff"/><circle cx="62" cy="48" r="5.5" fill="#fff"/>'
    '<circle cx="39" cy="48.5" r="3" fill="#3b2a4a"/><circle cx="63" cy="48.5" r="3" fill="#3b2a4a"/>'
    + blush(30, 62, 4.5) + blush(70, 62, 4.5) + smile(43, 62, 57, 6),
    g('b', '#4d7cff', '#2a4dd0') + g('c', '#ff6b81', '#e63950'))

sprites['host_lumi'] = svg(   # princess
    f'<path d="M22 96 Q50 52 78 96Z" fill="url(#b)" {S}/>'
    '<path d="M36 92 Q50 74 64 92" fill="none" stroke="#fff" stroke-width="3" opacity=".7"/>'
    f'<path d="M22 44 Q18 82 30 86 L30 44Z M78 44 Q82 82 70 86 L70 44Z" fill="#a66bff" {S}/>'
    f'<circle cx="50" cy="46" r="29" fill="#ffd9b8" {S}/>'
    f'<path d="M21 46 Q20 16 50 16 Q80 16 79 46 Q66 30 50 32 Q34 30 21 46Z" fill="#a66bff" {S}/>'
    f'<path d="M30 18 L34 4 L42 14 L50 0 L58 14 L66 4 L70 18Z" fill="url(#h)" {S}/>'
    '<circle cx="50" cy="12" r="3.2" fill="#ff5d8f"/>'
    + eye(38, 50, 4.8) + eye(62, 50, 4.8) + blush(30, 60, 4.8) + blush(70, 60, 4.8) + smile(43, 60, 57, 6),
    g('b', '#d9a8ff', '#a66bff') + g('h', '#ffe066', '#ffb703'))

sprites['host_bubbles'] = svg(   # bunny
    f'<ellipse cx="34" cy="26" rx="10" ry="26" fill="url(#a)" {S}/><ellipse cx="66" cy="26" rx="10" ry="26" fill="url(#a)" {S}/>'
    '<ellipse cx="34" cy="28" rx="4.5" ry="18" fill="#ffb3cd"/><ellipse cx="66" cy="28" rx="4.5" ry="18" fill="#ffb3cd"/>'
    f'<ellipse cx="50" cy="66" rx="34" ry="29" fill="url(#a)" {S}/>'
    + eye(36, 60, 5) + eye(64, 60, 5) + blush(27, 70, 5) + blush(73, 70, 5)
    + '<ellipse cx="50" cy="68" rx="4.6" ry="3.4" fill="#ff6b9d"/>' + '<path d="M50 71 V76 M50 76 Q45 80 41 77 M50 76 Q55 80 59 77" stroke="#3b2a4a" stroke-width="2.2" fill="none" stroke-linecap="round"/>'
    '<g stroke="#3b2a4a" stroke-width="1.6" stroke-linecap="round"><path d="M30 72 L16 70 M30 76 L16 78 M70 72 L84 70 M70 76 L84 78"/></g>'
    '<circle cx="82" cy="30" r="9" fill="#bdeaff" stroke="#5b3a6b" stroke-width="2" opacity=".85"/><circle cx="79" cy="27" r="2.2" fill="#fff"/>',
    g('a', '#ffffff', '#f1ebf7'))

sprites['host_pip'] = svg(   # baby dragon
    f'<path d="M8 64 Q0 36 22 40 Q26 54 28 66Z" fill="#ffb3d1" {S}/><path d="M92 64 Q100 36 78 40 Q74 54 72 66Z" fill="#ffb3d1" {S}/>'
    f'<path d="M30 30 Q26 14 36 12 Q42 20 42 30Z M70 30 Q74 14 64 12 Q58 20 58 30Z" fill="#ffd166" {S}/>'
    f'<ellipse cx="50" cy="64" rx="34" ry="30" fill="url(#a)" {S}/>'
    f'<ellipse cx="50" cy="82" rx="18" ry="12" fill="#fff0c2" stroke="#5b3a6b" stroke-width="2.5"/>'
    '<path d="M40 44 L50 36 L60 44" fill="#ffd166" stroke="#5b3a6b" stroke-width="2.5" stroke-linejoin="round"/>'
    + eye(36, 62, 5.4) + eye(64, 62, 5.4) + blush(27, 72, 5) + blush(73, 72, 5) + smile(43, 76, 57, 6)
    + '<circle cx="46" cy="70" r="1.6" fill="#3b7a4f"/><circle cx="54" cy="70" r="1.6" fill="#3b7a4f"/>',
    g('a', '#8ff0b0', '#43c776'))

sprites['host_twinkle'] = svg(   # fairy
    f'<path d="M48 54 Q4 20 14 66 Q30 70 48 60Z" fill="url(#w)" stroke="#5b3a6b" stroke-width="3" stroke-linejoin="round" opacity=".92"/>'
    f'<path d="M52 54 Q96 20 86 66 Q70 70 52 60Z" fill="url(#w)" stroke="#5b3a6b" stroke-width="3" stroke-linejoin="round" opacity=".92"/>'
    f'<path d="M24 100 Q30 60 50 62 Q70 60 76 100Z" fill="#ffb3d9" {S}/>'
    f'<circle cx="50" cy="40" r="26" fill="#ffe1cc" {S}/>'
    f'<path d="M24 40 Q22 10 50 10 Q78 10 76 40 Q64 24 50 26 Q36 24 24 40Z" fill="#ffb347" {S}/>'
    f'<circle cx="50" cy="8" r="7" fill="#ffb347" {S}/>'
    '<path d="M72 8 L76 0 L80 8 L88 10 L80 14 L76 22 L72 14 L64 10Z" fill="#ffe066" stroke="#c98a00" stroke-width="1.6" stroke-linejoin="round"/>'
    + eye(40, 44, 4.4) + eye(60, 44, 4.4) + blush(33, 53, 4.4) + blush(67, 53, 4.4) + smile(44, 54, 56, 5),
    g('w', '#d7f3ff', '#8edcf5'))

sprites['mindy'] = svg(
    f'<circle cx="50" cy="52" r="40" fill="url(#a)" {S}/>'
    '<path d="M50 12 C44 2 30 6 36 18 C40 26 50 22 50 12Z M50 12 C56 2 70 6 64 18 C60 26 50 22 50 12Z" fill="#ff8fab" stroke="#5b3a6b" stroke-width="2.5" stroke-linejoin="round"/>'
    + face(50, 54, 13) + '<ellipse cx="40" cy="30" rx="9" ry="5" fill="#fff" opacity=".5"/>',
    g('a', '#d6c1ff', '#9d7bff'))


sprites['cactus'] = svg(
    f'<rect x="38" y="10" width="26" height="84" rx="13" fill="url(#a)" {S}/>'
    f'<path d="M38 52 H26 Q16 52 16 42 V30 Q16 22 24 22 Q32 22 32 30 V40 H38" fill="url(#a)" {S}/>'
    f'<path d="M64 62 H76 Q86 62 86 52 V40 Q86 32 78 32 Q70 32 70 40 V50 H64" fill="url(#a)" {S}/>'
    '<path d="M46 20 V80" stroke="#fff" stroke-width="3" opacity=".35" stroke-linecap="round"/>'
    + eye(46, 42, 3.4) + eye(58, 42, 3.4) + smile(47, 52, 57, 4),
    g('a', '#7fdc8a', '#3fae5d'))

sprites['eagle_side'] = svg(   # faces RIGHT
    f'<path d="M30 52 Q4 30 8 62 Q20 64 34 62Z" fill="#8a5a3c" {S}/>'
    f'<path d="M40 50 Q36 12 62 6 Q66 30 64 52Z" fill="#a06a45" {S}/>'
    f'<ellipse cx="54" cy="58" rx="26" ry="20" fill="url(#a)" {S}/>'
    f'<ellipse cx="62" cy="66" rx="14" ry="10" fill="#f4e2c8"/>'
    f'<circle cx="78" cy="44" r="15" fill="#f6efe6" {S}/>'
    f'<path d="M90 44 L100 50 L90 54Z" fill="#ffb703" {S}/>'
    '<path d="M70 34 Q76 28 84 33" stroke="#5b3a6b" stroke-width="3" fill="none" stroke-linecap="round"/>'
    + eye(79, 43, 3.8) + blush(76, 52, 3.2),
    g('a', '#b07a52', '#8a5a3c'))

NAMES = list(sprites)
