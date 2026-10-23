"""共通アイコン C案(窓と帯): 窓の絵(Canvaで作成)に、枠・帯・双葉を重ねて3枚を作る。
使い方(リポジトリの直下から):
  python3 -I color_sort_app/tool/make_icon.py docs/icon/window.png color_sort/assets/art
  cd color_sort_app && dart run flutter_launcher_icons   # その後、iOSの project.pbxproj の
  #   ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS の差分は戻す
次のゲームでは、窓の絵(window.png)と、縁の色(RIM)を替える。背景・帯・双葉は共通。"""
import sys
from PIL import Image, ImageDraw, ImageFilter

src, out = sys.argv[1], sys.argv[2]
S = 1024
SS = 2  # 2倍で描いて縮める(縁をなめらかに)
W = S * SS

CREAM = (255, 246, 229)
RIM = (126, 184, 240)     # 窓の縁(色ソートは水色)
BAND = (186, 224, 190)    # 薄い緑の帯
WHITE = (255, 255, 255)

def circle_mask(d):
    m = Image.new('L', (d, d), 0)
    ImageDraw.Draw(m).ellipse((0, 0, d - 1, d - 1), fill=255)
    return m

def draw_sprout(f, cx, cy, h):
    """白い双葉: 茎の先から、左右に斜め上へ伸びる2枚の葉。太めで、小さくしても潰れない。"""
    d = ImageDraw.Draw(f)
    stem = max(4, h // 7)
    top = cy - h // 5
    d.rounded_rectangle((cx - stem // 2, top, cx + stem // 2, cy + h // 2), radius=stem // 2, fill=WHITE)
    L = int(h * 0.95)
    leaf = Image.new('RGBA', (2 * L, 2 * L), (0, 0, 0, 0))
    ImageDraw.Draw(leaf).ellipse((L, L - int(L * 0.30), 2 * L, L + int(L * 0.30)), fill=WHITE)
    right = leaf.rotate(38, resample=Image.BICUBIC, center=(L, L))
    left = right.transpose(Image.FLIP_LEFT_RIGHT)
    f.alpha_composite(right, (cx - L, top - L))
    f.alpha_composite(left, (cx - L, top - L))

def fg_layer():
    f = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(f)
    cx = W // 2
    # 安全域は、円形に切られても欠けない、中心から半径341px(1024の約66%)の円の内側。窓も帯も双葉もこの内側に収める。
    win_d = int(486 * SS)
    win_cy = int(430 * SS)
    # 窓の縁(外)
    rim_d = win_d + 30 * SS
    d.ellipse((cx - rim_d // 2, win_cy - rim_d // 2, cx + rim_d // 2, win_cy + rim_d // 2), fill=RIM + (255,))
    # 窓の中の絵(円形に切り抜き)
    art = Image.open(src).convert('RGB').resize((win_d, win_d), Image.LANCZOS)
    f.paste(art, (cx - win_d // 2, win_cy - win_d // 2), circle_mask(win_d))
    # 帯(角丸)
    bw, bh = int(300 * SS), int(100 * SS)
    by = int(706 * SS)
    d.rounded_rectangle((cx - bw // 2, by, cx + bw // 2, by + bh), radius=bh // 2, fill=BAND + (255,))
    # 双葉(帯の中央)
    h = int(62 * SS)
    draw_sprout(f, cx, by + bh // 2 + int(8 * SS), h)
    return f.resize((S, S), Image.LANCZOS)

def bg_layer():
    """クリーム色の、ほんのり中心が明るい背景(無地に近い。窓や帯は入れない)。"""
    inner, outer = (255, 250, 238), (252, 235, 208)
    g = Image.radial_gradient('L').resize((S, S), Image.BICUBIC)  # 中心0 → 外255
    b = Image.composite(Image.new('RGB', (S, S), outer), Image.new('RGB', (S, S), inner), g)
    return b

fg = fg_layer()
bg = bg_layer()
# iOS・従来のアイコン(app_icon.png)は、角丸でしか切られず安全域が要らないので、前景を1.22倍に大きくして重ねる。
full = bg.convert('RGBA')
big = fg.resize((int(S * 1.22), int(S * 1.22)), Image.LANCZOS)
off = (S - big.width) // 2
full.alpha_composite(big, (off, off + 8)) if off >= 0 else full.alpha_composite(big.crop((-off, -off, -off + S, -off + S)), (0, 8))
fg.save(f'{out}/app_icon_fg.png')
bg.save(f'{out}/app_icon_bg.png')
full.convert('RGB').save(f'{out}/app_icon.png')
print('ok')
