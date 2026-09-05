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

echo "== [1/5] 실행 설정·소스 확인 =="
[ -f "$ENV_FILE" ] || fail "$ENV_FILE 없음"
naver_key="$(grep -E '^NAVER_MAP_CLIENT_ID=' "$ENV_FILE" | head -1 | cut -d= -f2- | tr -d '\r')"
[ -n "$naver_key" ] || fail "NAVER_MAP_CLIENT_ID 가 비어 있다 — 지도가 뜨지 않는다"
# 예비 식별자도 함께 넘긴다. 지도 식별자는 하나가 아니라 순서라, 아래 교체에서
# 이것이 빠지면 웹에서만 후보가 하나로 줄어 첫 값이 막혔을 때 되살릴 길이 없다.
naver_key_alt="$(grep -E '^NAVER_MAP_CLIENT_ID_FALLBACK=' "$ENV_FILE" | head -1 | cut -d= -f2- | tr -d '\r')"
[ -d "$HOSTING_DIR" ] || fail "$HOSTING_DIR 없음"
echo "  ✓ 지도 식별자 확인"
# 코드에 값으로 적힌 키는 아래 설정 바꿔 끼우기로 걸러지지 않는다. 빌드에 들어가기
# 전에 본다 — 산출물이 만들어진 뒤에 아는 것보다 되돌리기 쉽다.
RESOURCE_DIR="" bash "$CLIENT_DIR/tool/check_web_secrets.sh" || fail "코드에 적힌 키를 먼저 정리한다"
echo "  ✓ 소스에 적힌 키 없음"

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
printf '# 웹 빌드 전용. tool/build_web.sh 가 빌드 동안만 만들어 쓴다.\n# 지도 식별자만 남긴다 — 서버용 키는 브라우저에 실리면 안 된다.\nNAVER_MAP_CLIENT_ID=%s\nNAVER_MAP_CLIENT_ID_FALLBACK=%s\n' \
  "$naver_key" "$naver_key_alt" > "$ENV_FILE" || fail "설정 교체 실패"
echo "  ✓ 지도 식별자만 남김(1순위·예비)"

echo "== [3/5] 웹 빌드 =="
flutter build web --release 2>&1 | tail -4
[ "${PIPESTATUS[0]}" -eq 0 ] || fail "웹 빌드 실패"
[ -f "$OUT_DIR/index.html" ] || fail "$OUT_DIR/index.html 없음"

echo "== [4/5] 게시 디렉터리에 설치 =="
# 빌드가 만들지 않은 사본을 먼저 치운다.
#
# 파일 관리자가 남기는 중복본("main.dart 2.js" 같은)은 빌드 디렉터리에 그대로
# 남아 있다가 아래 복사를 타고 게시 디렉터리까지 따라간다. 그 사본은 옛 빌드의
# 내용이라, 그때 코드에 들어 있던 값이 지금 소스에서 사라졌어도 게시물에는
# 그대로 실린다. 실제로 그렇게 옛 키를 품은 사본이 따라간 적이 있다.
#
# 아래 유출 검사는 이것을 못 잡는다. 그 검사는 지금 실행 설정에 이름이 올라
# 있는 키만 대조하는데, 문제의 값은 이미 그 목록에서 빠진 뒤이기 때문이다.
# 빌드 도구는 이름에 공백과 숫자가 붙은 파일을 만들지 않으므로 그 모양만 지운다.
#
# 숫자 뒤를 열어 둔다. 확장자가 붙는 사본("main.dart 2.js")뿐 아니라 숫자로
# 끝나는 사본(".env 5")도 같은 방식으로 생기는데, 뒤에 점을 요구하면 후자를
# 놓친다. 실제로 그 틈으로 옛 설정 사본이 게시 디렉터리까지 따라갔다.
find "$OUT_DIR" -name "* [0-9]*" -type f -print -delete | sed 's|^|  치움: |'

# --delete 로 옛 산출물을 치우되, 이 스크립트가 만들지 않는 항목은 남긴다.
# legal/ 은 방침·약관 문서, dl/ 은 배포용 설치 파일이라 웹 빌드 산출물이 아니다.
rsync -a --delete \
  --exclude 'app_config.json' \
  --exclude '.well-known/' \
  --exclude 'legal/' \
  --exclude 'dl/' \
  --exclude 'invite/' \
  "$OUT_DIR/" "$HOSTING_DIR/" || fail "게시 디렉터리 설치 실패"
echo "  ✓ $HOSTING_DIR 갱신 (주소·링크 검증·방침·초대 파일 보존)"

restore_env
trap - EXIT INT TERM

echo "== [5/5] 유출 검사 =="
RESOURCE_DIR="$HOSTING_DIR" bash "$CLIENT_DIR/tool/check_web_secrets.sh" || exit 1
echo "  ✓ 서버용 키 없음"

echo ""
echo "== ✅ 웹앱 준비 완료 =="
echo "   게시 디렉터리: $HOSTING_DIR"
echo "   배포: (cd $CLIENT_DIR && firebase deploy --only hosting)"
