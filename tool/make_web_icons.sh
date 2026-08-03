#!/usr/bin/env bash
# 홈 화면 아이콘을 브랜드 로고에서 만들어 web/icons 에 넣는다.
#
# 로고 원본은 배경이 없는 도형이라 그대로 쓰면 홈 화면에서 뒤가 비쳐 보인다.
# 그래서 첫 화면과 같은 바탕색을 깔고 그 위에 로고를 얹는다.
#
# 두 벌을 만든다.
#   보통 아이콘  — 로고를 크게 채운다.
#   잘려도 되는 아이콘 — 기기가 아이콘을 원형이나 둥근 사각형으로 잘라내는
#     경우가 있어, 가장자리가 잘려도 로고가 온전하도록 안쪽으로 더 들여 그린다.
#
# 브랜드가 바뀌면 이 스크립트를 다시 돌린다.
set -uo pipefail

CLIENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$CLIENT_DIR/assets/svg/union.svg"
OUT="$CLIENT_DIR/web/icons"
BG="#F9F8FA"   # 첫 화면 바탕색과 같게 맞춘다

fail() { echo "✗ $*"; exit 1; }

command -v rsvg-convert >/dev/null || fail "rsvg-convert 없음 → brew install librsvg"
[ -f "$SRC" ] || fail "$SRC 없음"
mkdir -p "$OUT"

# 바탕을 깔고 로고를 가운데 얹은 그림을 만들어 낸다. ratio 는 한 변에서 로고가
# 차지하는 비율이다.
render() {
  local size="$1" ratio="$2" dest="$3"
  local tmp; tmp="$(mktemp -t mapicon).svg"
  python3 - "$SRC" "$size" "$ratio" "$BG" > "$tmp" <<'PY'
import re, sys
src, size, ratio, bg = sys.argv[1], int(sys.argv[2]), float(sys.argv[3]), sys.argv[4]
raw = open(src, encoding="utf-8").read()
open_tag = re.search(r"<svg\b[^>]*>", raw)
view = re.search(r'viewBox="([^"]+)"', open_tag.group(0))
box = view.group(1) if view else "0 0 168 168"
inner = raw[open_tag.end():raw.rindex("</svg>")]
side = size * ratio
off = (size - side) / 2
print(f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
      f'width="{size}" height="{size}" viewBox="0 0 {size} {size}">')
print(f'<rect width="{size}" height="{size}" fill="{bg}"/>')
print(f'<svg x="{off}" y="{off}" width="{side}" height="{side}" viewBox="{box}">{inner}</svg>')
print('</svg>')
PY
  [ -s "$tmp" ] || fail "그림 만들기 실패($dest)"
  rsvg-convert -w "$size" -h "$size" "$tmp" -o "$dest" || fail "변환 실패($dest)"
  rm -f "$tmp"
  echo "  ✓ $(basename "$dest") ($size)"
}

echo "== 홈 화면 아이콘 생성 =="
render 192 0.72 "$OUT/Icon-192.png"
render 512 0.72 "$OUT/Icon-512.png"
# 잘려도 되는 아이콘은 안전 영역(가운데 원)을 벗어나지 않게 더 작게 그린다.
render 192 0.56 "$OUT/Icon-maskable-192.png"
render 512 0.56 "$OUT/Icon-maskable-512.png"
# 애플 기기가 쓰는 아이콘. 투명 부분을 검게 칠하므로 바탕이 반드시 있어야 한다.
render 180 0.72 "$OUT/apple-touch-icon.png"

echo "== ✅ 완료 =="
