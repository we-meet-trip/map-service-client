#!/usr/bin/env bash
# 호스팅 배포 직전에 서버용 키가 산출물에 섞여 있는지 본다.
#
# 웹 빌드는 실행 설정 파일을 자산으로 그대로 싣는다. 그 파일에는 지도 식별자
# 말고도 서버에서만 써야 할 키들이 함께 들어 있어서, 산출물을 통째로 올리면
# 누구나 주소만 알면 내려받을 수 있다. 한 번 나간 값은 되돌릴 수 없으므로
# 올리기 전에 막는다.
#
# 두 겹으로 본다.
#   1) 값 대조 — 실행 설정 파일에서 서버용 키의 실제 값을 읽어 산출물 전체에서
#      찾는다. 어느 경로로 새든(자산이든 코드에 박혔든) 걸린다.
#   2) 이름 대조 — 실행 설정 파일을 못 읽는 환경에서 쓰는 보조 수단. 산출물
#      안의 설정 자산에 서버용 키 이름이 값과 함께 있으면 막는다.
#
# 지도 식별자는 검사 대상이 아니다. 웹 지도는 그 값을 스크립트 주소에 실어
# 보내므로 원래 공개되며, 방어는 발급처에 등록한 도메인 목록이 한다.
#
# 판정 대상 경로는 배포 도구가 환경변수로 알려 준다. 검사 내용을 배포 설정에
# 문자열로 적지 않고 이 파일로 뺀 이유는 옆의 check_app_config.sh 와 같다.
set -uo pipefail

dir="${RESOURCE_DIR:-hosting}"
env_file="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.env"

found=0

# 서버에서만 써야 하는 키. 지도 클라이언트 아이디처럼 웹에 있어야 정상인
# 값은 여기 넣지 않는다.
SERVER_KEYS=(KAKAO_REST_API_KEY VISION_SERVER_HOST)

# 목록이 낡는 것을 막는다.
#
# 이름만 적어 두면 환경파일에서 사라진 키가 목록에 남는데, 그런 키는 값이 비어
# 아래에서 건너뛴다. 그러면 검사가 도는 것처럼 보이면서 실제로는 그 항목을
# 아무것도 안 본다. 목록에 있는데 파일에 없으면 그 자체를 실패로 본다.
missing=""
for key in "${SERVER_KEYS[@]}"; do
  grep -qE "^$key=" "$env_file" 2>/dev/null || missing="$missing $key"
done
if [ -n "$missing" ]; then
  echo "✗ 검사 목록에 있는데 환경파일에 없는 키:$missing"
  echo "    목록이 낡았다. 이 상태로는 그 키를 검사하지 못한다."
  found=1
fi

# 그리고 환경파일에 없는 것도 본다. 발급처 키가 코드에 글자 그대로 박히면
# 환경파일에는 흔적이 없어 값 대조로는 영영 안 걸린다. 그 모양을 직접 찾는다.
LITERAL_PATTERNS=(
  # data.go.kr 계열 발급키: 64자 이상의 영숫자·기호 덩어리가 따옴표 안에 있는 것
  "SERVICE_KEY[[:space:]]*=[[:space:]]*['\"][A-Za-z0-9%+/=]{40,}"
  # 흔한 발급처 키 앞머리
  "AIza[0-9A-Za-z_-]{30,}"
)

# 산출물이 없으면 대조할 것이 없다. 그런데 여기서 그냥 빠져나가면 위에서 이미
# 잡아 둔 실패까지 통과로 뒤집힌다. 부르는 쪽 둘 다 실제 자리를 알려 주므로,
# 없다는 것은 자리를 잘못 짚었다는 뜻이기도 하다.
if [ ! -d "$dir" ]; then
  echo "✗ $dir 이 없다 — 대조할 산출물이 없다."
  found=1
fi

# 0) 코드에 글자 그대로 박힌 키
for pat in "${LITERAL_PATTERNS[@]}"; do
  if grep -rqE -- "$pat" "$dir" 2>/dev/null; then
    echo "✗ 발급처 키로 보이는 값이 $dir 안에 글자 그대로 들어 있다."
    grep -rlE -- "$pat" "$dir" 2>/dev/null | sed 's/^/    /'
    found=1
  fi
done

# 1) 값 대조
if [ -f "$env_file" ]; then
  for key in "${SERVER_KEYS[@]}"; do
    value="$(grep -E "^$key=" "$env_file" | head -1 | cut -d= -f2- | tr -d '\r')"
    # 너무 짧은 값은 우연히 일치할 수 있어 건너뛴다. 비어 있으면 검사할 것이 없다.
    [ "${#value}" -ge 8 ] || continue
    if grep -rqF -- "$value" "$dir" 2>/dev/null; then
      echo "✗ $key 의 값이 $dir 안에 들어 있다."
      grep -rlF -- "$value" "$dir" 2>/dev/null | sed 's/^/    /'
      found=1
    fi
  done
fi

# 2) 이름 대조
asset_env="$dir/assets/.env"
if [ -f "$asset_env" ]; then
  for key in "${SERVER_KEYS[@]}"; do
    if grep -qE "^$key=.+" "$asset_env" 2>/dev/null; then
      echo "✗ $asset_env 에 $key 가 값과 함께 들어 있다."
      found=1
    fi
  done
fi

if [ "$found" -eq 0 ]; then
  exit 0
fi

echo ""
echo "  이대로 올리면 서버용 키가 공개된다. 배포를 중단한다."
echo "  웹 빌드는 tool/build_web.sh 로 한다(지도 식별자만 남긴 설정으로 빌드한다)."
exit 1
