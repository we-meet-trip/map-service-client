#!/usr/bin/env bash
# 웹앱을 만들어 게시 디렉터리에 넣는다. 웹 빌드는 반드시 이 스크립트로 한다.
#
# 그냥 `flutter build web` 을 돌리면 안 되는 이유: 실행 설정 파일이 자산으로
# 통째로 실린다. 그 파일에는 서버에서만 써야 할 키가 함께 있어서, 산출물을
# 올리는 순간 주소만 알면 누구나 내려받을 수 있다. 그래서 빌드하는 동안만
# 지도 식별자 한 줄짜리 설정으로 바꿔 끼운다.
#
# 설정 파일을 아예 비우지 않는 이유: 앱은 시작할 때 그 파일을 반드시 읽고,
# 없으면 첫 화면을 그리기 전에 멈춘다. 파일은 있되 서버용 키만 빠진 상태여야
# 한다. 키가 빠진 기능은 각자 "설정되지 않았습니다" 경로로 접힌다.
#
# 게시 디렉터리에는 서버 주소 파일과 링크 검증 파일이 이미 들어 있다. 그 둘은
# 이 스크립트가 만드는 것이 아니므로 덮어쓰지 않는다.
set -uo pipefail

CLIENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$CLIENT_DIR/.env"
ENV_BACKUP="$CLIENT_DIR/.env.build-backup"
OUT_DIR="$CLIENT_DIR/build/web"
HOSTING_DIR="$CLIENT_DIR/hosting"

fail() { echo "✗ $*"; exit 1; }

cd "$CLIENT_DIR" || fail "앱 디렉터리로 이동 실패"

echo "== [1/5] 실행 설정 확인 =="
[ -f "$ENV_FILE" ] || fail "$ENV_FILE 없음"
naver_key="$(grep -E '^NAVER_MAP_CLIENT_ID=' "$ENV_FILE" | head -1 | cut -d= -f2- | tr -d '\r')"
[ -n "$naver_key" ] || fail "NAVER_MAP_CLIENT_ID 가 비어 있다 — 지도가 뜨지 않는다"
[ -d "$HOSTING_DIR" ] || fail "$HOSTING_DIR 없음"
echo "  ✓ 지도 식별자 확인"

# 어떤 경로로 끝나든 원래 설정으로 되돌린다. 여기서 실패하면 다음 네이티브
# 빌드가 키 없는 설정으로 만들어져, 앱이 조용히 반쪽으로 동작한다.
restore_env() {
  if [ -f "$ENV_BACKUP" ]; then
    mv -f "$ENV_BACKUP" "$ENV_FILE"
    echo "  ✓ 실행 설정 원복"
  fi
}
trap restore_env EXIT INT TERM

echo "== [2/5] 웹 전용 설정으로 교체 =="
cp -p "$ENV_FILE" "$ENV_BACKUP" || fail "설정 백업 실패"
printf '# 웹 빌드 전용. tool/build_web.sh 가 빌드 동안만 만들어 쓴다.\n# 지도 식별자만 남긴다 — 서버용 키는 브라우저에 실리면 안 된다.\nNAVER_MAP_CLIENT_ID=%s\n' \
  "$naver_key" > "$ENV_FILE" || fail "설정 교체 실패"
echo "  ✓ 지도 식별자만 남김"

echo "== [3/5] 웹 빌드 =="
flutter build web --release 2>&1 | tail -4
[ "${PIPESTATUS[0]}" -eq 0 ] || fail "웹 빌드 실패"
[ -f "$OUT_DIR/index.html" ] || fail "$OUT_DIR/index.html 없음"

echo "== [4/5] 게시 디렉터리에 설치 =="
# --delete 로 옛 산출물을 치우되, 이 스크립트가 만들지 않는 두 항목은 남긴다.
rsync -a --delete \
  --exclude 'app_config.json' \
  --exclude '.well-known/' \
  "$OUT_DIR/" "$HOSTING_DIR/" || fail "게시 디렉터리 설치 실패"
echo "  ✓ $HOSTING_DIR 갱신 (주소 파일·링크 검증 파일 보존)"

restore_env
trap - EXIT INT TERM

echo "== [5/5] 유출 검사 =="
RESOURCE_DIR="$HOSTING_DIR" bash "$CLIENT_DIR/tool/check_web_secrets.sh" || exit 1
echo "  ✓ 서버용 키 없음"

echo ""
echo "== ✅ 웹앱 준비 완료 =="
echo "   게시 디렉터리: $HOSTING_DIR"
echo "   배포: (cd $CLIENT_DIR && firebase deploy --only hosting)"
