#!/usr/bin/env python3
"""今日签 · 演示视频剪辑：虚拟镜头（推近/跟随）、放大光标、点击波纹、字幕、音效、配乐。
用法: edit.py SRC.mp4 EVENTS.json OFFSET OUT.mp4 [--preview SECONDS] [--fps 60]
"""
import json, sys, subprocess, math, os, wave
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
args = sys.argv[1:]
SRC, EVF, OFF, OUT = args[0], args[1], float(args[2]), args[3]
PREVIEW = float(args[args.index('--preview') + 1]) if '--preview' in args else None
FPS = int(args[args.index('--fps') + 1]) if '--fps' in args else 60
ONLY = args[args.index('--only') + 1] if '--only' in args else None   # "a:b" output seconds range for quick tests
PRIV = [int(v) for v in args[args.index('--privacy') + 1].split(',')] if '--privacy' in args else None   # x0,y0,x1,y1 要虚化的窗口
W, H = 1920, 1080
SW, SH = 1920, 1080      # source size (points == pixels on this 1x screen)

D = json.load(open(EVF))
EV = D['events']
P = D['panel']; PX, PY, PW, PH = P['x'], P['y'], P['w'], P['h']
PCX, PCY = PX + PW / 2, PY + PH / 2

def find(type_, id_=None, after=0.0):
    for e in EV:
        if e['t'] >= after and e['type'] == type_ and (id_ is None or e.get('id') == id_):
            return e
    return None

def scene_t(name):
    e = find('scene', name)
    return e['t'] if e else None

T_END = find('end')['t']
T_ANS0 = find('answer.start')['t'] if find('answer.start') else None
T_ANS1 = find('answer.end')['t'] if find('answer.end') else None

# ---------------- 时间重映射：输出时间 -> 事件时间 ----------------
INTRO = 3.4
OUTRO = 5.0
# (event_start, event_end, speed)
segs = []
cur = 0.25
if T_ANS0 and T_ANS1 and T_ANS1 - T_ANS0 > 12:
    a0 = T_ANS0 + 1.6
    a1 = T_ANS1 - 0.4
    cc = find('click', 'chat.close', T_ANS1)
    hold_end = cc['t'] - 0.35 if cc else T_ANS1 + 2.5
    segs.append((cur, a0, 1.0))
    segs.append((a0, a1, (a1 - a0) / 9.0))   # 压到 9 秒
    segs.append((a1, hold_end, 0.4))          # 答案出来后放慢，留时间读
    segs.append((hold_end, T_END + 0.3, 1.0))
else:
    segs.append((cur, T_END + 0.3, 1.0))
FAST = [(s0, s1) for s0, s1, sp in segs if sp > 1.5]
FAST_X = max([sp for _, _, sp in segs] + [1])

seg_out = []
o = INTRO
for s0, s1, sp in segs:
    d = (s1 - s0) / sp
    seg_out.append((o, o + d, s0, s1, sp))
    o += d
MAIN_END = o
TOTAL = MAIN_END + OUTRO

def out2ev(t):
    if t < INTRO: return segs[0][0]
    for o0, o1, s0, s1, sp in seg_out:
        if t < o1: return s0 + (t - o0) * sp
    return segs[-1][1]

def ev2out(e):
    for o0, o1, s0, s1, sp in seg_out:
        if s0 <= e <= s1: return o0 + (e - s0) / sp
    return None

def in_fast(e):
    return any(a <= e <= b for a, b in FAST)

# ---------------- 光标轨迹 ----------------
def ease(k): return k * k * (3 - 2 * k)
cur_keys = []   # (t, x, y)
last = (SW / 2, SH * 0.55)
for e in EV:
    if e['type'] == 'move':
        cur_keys.append(('move', e['t'], e['dur'], e['x0'], e['y0'], e['x'], e['y']))
    elif e['type'] in ('pos', 'down', 'up', 'click'):
        if 'x' in e: cur_keys.append(('pos', e['t'], 0, e['x'], e['y'], e['x'], e['y']))
cur_keys.sort(key=lambda k: k[1])

def cursor_at(t):
    x, y = SW / 2, SH * 0.55
    for kind, t0, dur, x0, y0, x1, y1 in cur_keys:
        if t0 > t: break
        if kind == 'move' and t < t0 + dur:
            k = ease((t - t0) / dur)
            return x0 + (x1 - x0) * k, y0 + (y1 - y0) * k
        x, y = x1, y1
    return x, y

CLICKS = [e for e in EV if e['type'] == 'click']
DOWNS = []   # pressed intervals for drag
dn = None
for e in EV:
    if e['type'] == 'down': dn = e['t']
    if e['type'] == 'up' and dn is not None: DOWNS.append((dn, e['t'])); dn = None

# ---------------- 镜头计划（源坐标） ----------------
def rect_c(cx, cy, h):
    w = h * 16 / 9
    return [cx, cy, h]

WIDE = rect_c(SW / 2, SH / 2, SH)
st = find('click', 'status')
MENU = rect_c(st['x'], 200, 430)
PANEL = rect_c(PCX + 28, PCY + 6, 790)

def near(id_, after=0.0):
    e = find('click', id_, after)
    return (e['x'], e['y']) if e else (PCX, PCY)

def detail(pt, h=560, dx=0, dy=0):
    return rect_c(pt[0] + dx, pt[1] + dy, h)

plan = []   # (event_time, target)
def at(t, tgt):
    if t is not None: plan.append((t, tgt))

at(0.0, WIDE)
at(st['t'] - 1.3, MENU)
at(st['t'] + 0.45, PANEL)
tb = scene_t('birth')
wheel = find('click', 'wheel')
at(wheel['t'] - 0.4, detail((PCX, wheel['y'] + 10), 560))
bs = find('click', 'birth.save')
at(bs['t'] - 0.5, PANEL)
td = scene_t('draw')
fan = find('click', 'draw.fan')
at(td + 1.6, detail((PCX, fan['y'] + 10), 640))
fl = find('flip')
at(fl['t'] + 0.2, detail((PCX, fan['y'] + 40), 700))
tk = find('click', 'draw.take')
at(tk['t'] - 2.2, PANEL)
tdial = scene_t('dial')
dc = find('click', 'dial.center')
dial_pt = (dc['x'], dc['y']) if dc else (PCX, PCY)
at(tdial + 0.4, detail(dial_pt, 470, dx=0, dy=40))
at(scene_t('calendar'), PANEL)
at(scene_t('lot'), PANEL)
tstrip = scene_t('strip')
sdown = find('down', after=tstrip)
at(tstrip + 0.2, detail((sdown['x'] - 120, sdown['y']), 600))
tw = scene_t('weather')
if tw:
    wc = find('click', 'rail.weather', tw)
    at(tw + 0.2, detail((wc['x'] - 150, wc['y'] + 120), 560))
at(scene_t('todo'), PANEL)
ct = find('click', 'composer.title')
if ct: at(ct['t'] - 0.4, detail((PCX, ct['y'] - 120), 600))
ca = find('click', 'composer.add')
if ca: at(ca['t'] + 0.3, PANEL)
tai = scene_t('ai')
at(tai, PANEL)
sk = find('click', 'set.key')
if sk: at(sk['t'] - 2.0, detail((PCX, sk['y'] - 20), 560))
suc = find('success') or find('fail')
if suc: at(suc['t'] + 1.6, PANEL)
tch = scene_t('chat')
at(tch, PANEL)
ci = find('click', 'chat.input')
if ci: at(ci['t'] - 0.3, detail((PCX, ci['y'] - 150), 560))
if T_ANS0: at(T_ANS0 + 0.4, PANEL)
if T_ANS1: at(T_ANS1 - 0.2, rect_c(PCX - 10, PY + 250, 600))
cc2 = find('click', 'chat.close', T_ANS1 or 0)
if cc2: at(cc2['t'] - 0.4, PANEL)
tdk = scene_t('dark')
if tdk: at(tdk - 0.2, rect_c(PCX + 28, PCY + 6, 860))
at(scene_t('end') + 0.2, WIDE)
plan.sort(key=lambda p: p[0])

def clamp_cam(c):
    cx, cy, h = c
    h = min(SH, max(300, h))
    w = h * 16 / 9
    cx = min(SW - w / 2, max(w / 2, cx))
    cy = min(SH - h / 2, max(h / 2, cy))
    return [cx, cy, h]

def target_at(e):
    tgt = plan[0][1]
    for t, g in plan:
        if t <= e: tgt = g
        else: break
    return clamp_cam(tgt)

# ---------------- 字幕 ----------------
CAP = [
    ('desktop', 0.5, None, '装好之后，它就安静地待在菜单栏里'),
    ('birth', 0.3, 'wheel', '第一次打开：先报上生辰八字'),
    ('wheel', 4.2, 'birth.save', '生辰只存在这台 Mac 上，不上传'),
    ('draw', 0.4, 'draw.fan', '向山人求一支签 · 左右拨动牌阵'),
    ('draw.fan', 0.0, 'draw.take', '抽出这一张，翻开就是今天的签'),
    ('dial', 0.3, 'probe', '十二时辰轮：今天的吉时、凶时，一眼看清'),
    ('probe', 0.0, 'days', '拨一拨，看看每个时辰宜做什么'),
    ('days', 0.0, 'calendar', '左右切换，往后几天的吉凶也一目了然'),
    ('calendar', 0.0, 'lot', '点日期：农历、黄历、宜忌都在'),
    ('lot', 0.0, 'strip', '点中间的签：签文、解读，还有你的命盘'),
    ('strip', 0.0, 'weather', '侧边签条：随手一拨，像在摇签筒'),
    ('weather', 0.0, 'todo', '天气也在侧栏，点开看今明两天'),
    ('todo', 0.0, 'ai', '记一件事，它会自动落在时辰轮上'),
    ('ai', 0.0, 'set.key', '接入你自己的 AI：选服务商 → 粘贴密钥 → 一键连接'),
    ('set.key', 0.0, 'chat', '密钥只存在 macOS 钥匙串，应用本身不带任何后端'),
    ('chat', 0.0, 'answer.start', '问山人：结合我的生辰八字，最近哪天适合谈合作？'),
    ('answer.start', 0.0, 'answer.end', '山人掐指一算……（已加速）'),
    ('answer.end', 0.0, 'dark', '按你的八字和近日黄历，给出具体的日子'),
    ('dark', 0.0, 'end', '深色、浅色，都跟随系统'),
]
def mark_t(name):
    t = scene_t(name)
    if t is not None: return t
    e = find('click', name) or find(name)
    return e['t'] if e else None

CAPS = []
for a, da, b, text in CAP:
    t0 = mark_t(a)
    t1 = mark_t(b) if b else None
    if t0 is None: continue
    t0 += da
    if t1 is None: t1 = t0 + 4
    CAPS.append((t0, t1 - 0.15, text))

# ---------------- 资源 ----------------
FSANS = '/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc'
FSANSM = '/usr/share/fonts/opentype/noto/NotoSansCJK-Medium.ttc'
FSERIF = '/usr/share/fonts/opentype/noto/NotoSerifCJK-Bold.ttc'
def font(path, size): return ImageFont.truetype(path, size, index=2)
F_CAP = font(FSANS, 40)

def make_cursor(scale=4):
    s = scale
    pts = [(0, 0), (0, 17), (4.2, 13.2), (7, 19.5), (9.6, 18.4), (6.9, 12.3), (12.2, 12.3)]
    im = Image.new('RGBA', (int(16 * s), int(23 * s)), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    big = [((x + 1.5) * s, (y + 1.5) * s) for x, y in pts]
    sh = Image.new('RGBA', im.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).polygon([(x + s * 0.6, y + s * 1.0) for x, y in big], fill=(0, 0, 0, 110))
    sh = sh.filter(ImageFilter.GaussianBlur(s * 0.9))
    im = Image.alpha_composite(im, sh)
    d = ImageDraw.Draw(im)
    d.polygon(big, fill=(255, 255, 255, 255))
    inner = [((x * 0.86 + 1.5 + 0.9), (y * 0.86 + 1.5 + 1.25)) for x, y in pts]
    d.polygon([(x * s, y * s) for x, y in inner], fill=(10, 10, 12, 255))
    return im
CURSOR = make_cursor()

def caption_img(text):
    tw = F_CAP.getbbox(text)
    w = tw[2] - tw[0] + 64; h = 76
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, w - 1, h - 1), radius=h // 2, fill=(18, 18, 22, 205))
    d.text((32 - tw[0], (h - (tw[3] - tw[1])) / 2 - tw[1] - 1), text, font=F_CAP, fill=(255, 255, 255, 255))
    return im
_capcache = {}

# ---------------- 片头 / 片尾卡 ----------------
ICON = Image.open(os.path.join(HERE, 'icon.png')).convert('RGBA')

def title_card(bg, lines, icon_size=200):
    """bg: PIL RGB 1920x1080 背景帧"""
    b = bg.resize((W // 4, H // 4), Image.BILINEAR).filter(ImageFilter.GaussianBlur(10)).resize((W, H), Image.BICUBIC)
    b = Image.blend(b, Image.new('RGB', (W, H), (14, 16, 24)), 0.55).convert('RGBA')
    ic = ICON.resize((icon_size, icon_size), Image.LANCZOS)
    shadow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    y = H // 2 - 250
    sx = (W - icon_size) // 2
    ImageDraw.Draw(shadow).rounded_rectangle((sx + 6, y + 18, sx + icon_size - 6, y + icon_size + 14), radius=44, fill=(0, 0, 0, 150))
    shadow = shadow.filter(ImageFilter.GaussianBlur(22))
    b = Image.alpha_composite(b, shadow)
    b.alpha_composite(ic, (sx, y))
    d = ImageDraw.Draw(b)
    yy = y + icon_size + 46
    for txt, fpath, size, col in lines:
        f = font(fpath, size)
        bb = f.getbbox(txt)
        d.text(((W - (bb[2] - bb[0])) / 2 - bb[0], yy - bb[1]), txt, font=f, fill=col)
        yy += (bb[3] - bb[1]) + int(size * 0.62)
    return b.convert('RGB')

def privacy(im, e):
    """把桌面上没藏住的窗口（源坐标 PRIV）磨砂虚化；面板盖住的部分保持清晰"""
    if not PRIV: return im
    x0, y0, x1, y1 = PRIV
    reg = im.crop((x0, y0, x1, y1))
    bl = reg.resize((max(1, (x1 - x0) // 10), max(1, (y1 - y0) // 10)), Image.BILINEAR).filter(ImageFilter.GaussianBlur(2.5)).resize(reg.size, Image.BICUBIC)
    bl = Image.blend(bl, Image.new('RGB', reg.size, (236, 238, 242)), 0.18)
    m = Image.new('L', reg.size, 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle((0, 0, reg.width - 1, reg.height - 1), radius=22, fill=255)
    if e >= st['t'] + 0.22:
        d.rounded_rectangle((PX - x0, PY - y0, PX + PW - x0, PY + PH - y0), radius=24, fill=0)
    reg.paste(bl, (0, 0), m)
    im = im.copy(); im.paste(reg, (x0, y0))
    return im

# ---------------- 渲染 ----------------
def src_reader():
    cmd = ['ffmpeg', '-v', 'error', '-i', SRC, '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-']
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, bufsize=10**8)
    idx = -1; frame = None
    while True:
        want = yield frame
        while idx < want:
            buf = p.stdout.read(SW * SH * 3)
            if len(buf) < SW * SH * 3: break
            frame = buf; idx += 1

def grab_frame_at(src_t):
    cmd = ['ffmpeg', '-v', 'error', '-ss', f'{max(0, src_t):.3f}', '-i', SRC, '-frames:v', '1', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-']
    b = subprocess.run(cmd, capture_output=True).stdout
    return Image.frombytes('RGB', (SW, SH), b)

def main_render():
    t_from, t_to = 0.0, TOTAL
    if PREVIEW: t_to = min(TOTAL, PREVIEW)
    if ONLY:
        a, b = ONLY.split(':'); t_from, t_to = float(a), float(b)
    nframes = int((t_to - t_from) * FPS)
    enc = subprocess.Popen(['ffmpeg', '-v', 'error', '-y', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{W}x{H}', '-r', str(FPS), '-i', '-',
                            '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '17', '-pix_fmt', 'yuv420p', '-movflags', '+faststart',
                            OUT + '.video.mp4'], stdin=subprocess.PIPE)
    rd = src_reader(); next(rd)
    intro_bg = privacy(grab_frame_at(segs[0][0] + OFF), 0)
    INTRO_CARD = title_card(intro_bg, [
        ('今日签 · 山人', FSERIF, 92, (255, 255, 255)),
        ('住在 Mac 菜单栏里的隐士高人', FSANSM, 38, (220, 224, 235)),
        ('每天一支签 · 十二时辰吉凶 · 黄历 · 问山人', FSANSM, 28, (170, 176, 192)),
    ])
    outro_bg = privacy(grab_frame_at(T_END - 0.5 + OFF), T_END)
    OUTRO_CARD = title_card(outro_bg, [
        ('今日签 · 山人', FSERIF, 88, (255, 255, 255)),
        ('即将在 GitHub 开源 · 免费使用', FSANSM, 40, (225, 229, 240)),
        ('关注我，开源第一时间告诉你', FSANSM, 32, (180, 186, 202)),
        ('签文原创 · 黄历本地推算 · 仅供娱乐参考', FSANSM, 22, (130, 136, 150)),
    ], icon_size=180)

    cam = None; vel = [0, 0, 0]
    cam2 = None
    last_img = None
    for fi in range(nframes):
        t = t_from + fi / FPS
        e = out2ev(t)
        src_t = e + OFF
        tgt = target_at(e)
        # 平滑镜头：双重指数平滑，起步柔、收尾稳
        if cam is None:
            cam = list(target_at(out2ev(t_from))); cam2 = list(cam)
            if t_from > 0:
                # 预热
                pass
        k = 1 - math.exp(-1 / FPS / 0.30)
        if in_fast(e): k = 1 - math.exp(-1 / FPS / 0.15)
        for i in range(3):
            cam[i] += (tgt[i] - cam[i]) * k
            cam2[i] += (cam[i] - cam2[i]) * k
        cx, cy, ch = clamp_cam(cam2)
        cw = ch * 16 / 9
        x0, y0 = cx - cw / 2, cy - ch / 2
        zoom = H / ch

        if t < MAIN_END or last_img is None:
            buf = rd.send(int(round(src_t * 60)))
            if buf is not None:
                srcim = privacy(Image.frombytes('RGB', (SW, SH), buf), e)
            img = srcim.resize((W, H), Image.BICUBIC, box=(x0, y0, x0 + cw, y0 + ch))
            # 聚焦：面板以外压暗 + 虚化
            panel_on = e >= st['t'] + 0.3 and e <= scene_t('end') + 0.6
            amt = max(0.0, min(1.0, (1080 - ch) / 260)) if panel_on else 0.0
            if amt > 0.01:
                blur = img.resize((W // 6, H // 6), Image.BILINEAR).filter(ImageFilter.GaussianBlur(3)).resize((W, H), Image.BILINEAR)
                dark = Image.blend(blur, Image.new('RGB', (W, H), (10, 12, 18)), 0.35 * amt)
                mask = Image.new('L', (W, H), int(255 * (1 - amt)))
                r = [(PX - x0) * zoom, (PY - y0) * zoom, (PX + PW - x0) * zoom, (PY + PH - y0) * zoom]
                ImageDraw.Draw(mask).rounded_rectangle(r, radius=24 * zoom, fill=255)
                img = Image.composite(img, dark, mask)
            img = img.convert('RGBA')
            ov = Image.new('RGBA', (W, H), (0, 0, 0, 0))
            od = ImageDraw.Draw(ov)
            # 点击波纹
            for c in CLICKS:
                dt = e - c['t']
                if 0 <= dt < 0.5 and not in_fast(c['t']):
                    kk = dt / 0.5
                    rr = (8 + 26 * ease(min(1, kk * 1.3))) * zoom
                    px, py = (c['x'] - x0) * zoom, (c['y'] - y0) * zoom
                    a = int(200 * (1 - kk))
                    od.ellipse((px - rr, py - rr, px + rr, py + rr), outline=(20, 20, 24, a), width=max(2, int(3 * zoom)))
                    od.ellipse((px - rr * 0.55, py - rr * 0.55, px + rr * 0.55, py + rr * 0.55), fill=(20, 20, 24, int(a * 0.25)))
            img = Image.alpha_composite(img, ov)
            # 光标
            if e < T_END - 0.2 and t >= INTRO - 0.4:
                mx, my = cursor_at(e)
                press = any(0 <= e - c['t'] < 0.16 for c in CLICKS) or any(a <= e <= b for a, b in DOWNS)
                size = 24 * (zoom ** 0.75) * (0.88 if press else 1.0) * 1.15
                cimg = CURSOR.resize((max(4, int(size * 16 / 23)), max(6, int(size))), Image.LANCZOS)
                img.alpha_composite(cimg, (int((mx - x0) * zoom - size * 0.08), int((my - y0) * zoom - size * 0.07)))
            # 字幕
            capa = None
            for c0, c1, txt in CAPS:
                o0, o1 = ev2out(c0), ev2out(c1)
                if o0 is None or o1 is None: continue
                if o0 - 0.01 <= t <= o1:
                    a = min(1, (t - o0) / 0.25, (o1 - t) / 0.25)
                    capa = (txt, max(0, a))
            if capa and t >= INTRO + 0.2:
                txt, a = capa
                if txt not in _capcache: _capcache[txt] = caption_img(txt)
                ci = _capcache[txt]
                if a < 1:
                    ci = ci.copy(); al = ci.split()[3].point(lambda v: int(v * a)); ci.putalpha(al)
                img.alpha_composite(ci, ((W - ci.width) // 2, H - 150 + int((1 - a) * 12)))
            # 加速标记
            if in_fast(e):
                tag = _capcache.get('__fast')
                if tag is None:
                    f = font(FSANS, 30); tw = f.getbbox('▶▶ ×%d' % round(FAST_X))
                    tag = Image.new('RGBA', (tw[2] + 40, 54), (0, 0, 0, 0))
                    dd = ImageDraw.Draw(tag); dd.rounded_rectangle((0, 0, tag.width - 1, 53), radius=27, fill=(18, 18, 22, 190))
                    dd.text((20, 27 - (tw[3] + tw[1]) / 2), '▶▶ ×%d' % round(FAST_X), font=f, fill=(255, 255, 255, 255))
                    _capcache['__fast'] = tag
                img.alpha_composite(tag, (W - tag.width - 48, 44))
            frame = img.convert('RGB')
        else:
            frame = last_img

        # 片头
        if t < INTRO:
            a = 1.0 if t < INTRO - 0.7 else max(0.0, (INTRO - t) / 0.7)
            card = INTRO_CARD
            if t < 0.5: card = Image.blend(Image.new('RGB', (W, H), (0, 0, 0)), INTRO_CARD, t / 0.5)
            frame = Image.blend(frame, card, a)
        # 片尾
        if t >= MAIN_END - 0.8:
            a = min(1.0, (t - (MAIN_END - 0.8)) / 0.8)
            card = OUTRO_CARD
            if t > TOTAL - 0.6: card = Image.blend(OUTRO_CARD, Image.new('RGB', (W, H), (0, 0, 0)), (t - (TOTAL - 0.6)) / 0.6)
            frame = Image.blend(frame, card, a)
        if t < MAIN_END: last_img = frame
        enc.stdin.write(frame.tobytes())
        if fi % 300 == 0: print(f'frame {fi}/{nframes}  t={t:.1f}', flush=True)
    enc.stdin.close(); enc.wait()

# ---------------- 声音 ----------------
SR = 48000
def readwav(name):
    with wave.open(os.path.join(HERE, 'audio', name)) as w:
        x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32) / 32768
        return x.reshape(-1, 2)
def build_audio(t_from, t_to):
    n = int((t_to - t_from) * SR) + SR
    mix = np.zeros((n, 2), np.float32)
    def put(name, t_out, vol):
        if t_out is None or t_out < t_from or t_out > t_to: return
        s = readwav(name) * vol
        i = int((t_out - t_from) * SR); j = min(n, i + len(s))
        mix[i:j] += s[:j - i]
    music = readwav('music.wav')
    L = min(len(music), n)
    off = int(t_from * SR)
    seg = music[off:off + L]
    mix[:len(seg)] += seg * 0.30
    put('chime.wav', 0.35, 0.35)
    put('whoosh.wav', INTRO - 0.6, 0.35)
    for e in EV:
        if in_fast(e['t']) and e['type'] not in ('answer.end',): continue
        to = ev2out(e['t'])
        ty = e['type']
        if ty == 'click':
            put('click.wav', to, 0.55)
            if e.get('id') == 'status': put('pop.wav', (to or 0) + 0.25, 0.5)
        elif ty == 'key': put('key.wav', to, 0.35)
        elif ty == 'wheel':
            for k in range(7): put('tick.wav', (to or 0) + k * 0.055, 0.32 * (1 - k * 0.1))
        elif ty == 'swipe': put('swipe.wav', to, 0.55)
        elif ty == 'down' and False: pass
        elif ty == 'flip':
            put('flip.wav', to, 0.7); put('reveal.wav', (to or 0) + 0.15, 0.45)
        elif ty == 'success': put('success.wav', to, 0.6)
        elif ty == 'theme': put('whoosh.wav', to, 0.4)
        elif ty == 'scroll': put('swipe.wav', to, 0.25)
        elif ty == 'paste': put('key.wav', to, 0.5)
        elif ty == 'answer.end': put('chime.wav', to, 0.4)
    # 拨时辰：每跨一个时辰一声 tick
    pr = scene_t('probe')
    if pr:
        dn = find('down', after=pr - 1); up = find('up', after=pr)
        if dn and up:
            for k in range(1, 9):
                put('tick.wav', ev2out(dn['t'] + (up['t'] - dn['t']) * k / 9), 0.3)
    # 拨牌：每张一声
    for e in EV:
        if e['type'] == 'down' and not in_fast(e['t']):
            up = find('up', after=e['t'])
            if up and up['t'] - e['t'] < 0.8:
                for k in range(3): put('tick.wav', ev2out(e['t'] + (up['t'] - e['t']) * (k + 1) / 4), 0.25)
    # 渐出
    fo = int((TOTAL - t_from - 1.5) * SR)
    if 0 < fo < n:
        ramp = np.linspace(1, 0, min(n - fo, int(1.5 * SR)))
        mix[fo:fo + len(ramp)] *= ramp[:, None]; mix[fo + len(ramp):] = 0
    peak = np.max(np.abs(mix)) + 1e-9
    if peak > 0.95: mix *= 0.95 / peak
    mix = mix[:int((t_to - t_from) * SR)]
    with wave.open(OUT + '.audio.wav', 'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((mix * 32767).astype(np.int16).tobytes())

if __name__ == '__main__':
    print(f'total {TOTAL:.1f}s  main_end {MAIN_END:.1f}  segs {[(round(a,1),round(b,1),round(c,2)) for a,b,c in segs]}', flush=True)
    t_from, t_to = 0.0, TOTAL
    if PREVIEW: t_to = min(TOTAL, PREVIEW)
    if ONLY:
        a, b = ONLY.split(':'); t_from, t_to = float(a), float(b)
    build_audio(t_from, t_to)
    main_render()
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', OUT + '.video.mp4', '-i', OUT + '.audio.wav', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '192k',
                    '-shortest', '-movflags', '+faststart', OUT], check=True)
    os.remove(OUT + '.video.mp4'); os.remove(OUT + '.audio.wav')
    print('done', OUT)
