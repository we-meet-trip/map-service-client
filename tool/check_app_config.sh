#!/usr/bin/env bash
# 호스팅 배포 직전에 앱이 읽을 주소 파일을 본다. 있는지, 그리고 그 안의
# 주소가 실제로 답하는지까지 본다.
#
# 배포는 산출물 디렉터리 내용으로 사이트를 통째로 바꾼다. 주소 파일이 없는
# 상태로 올리면 폰이 읽을 곳이 사라지고, 그때부터 앱은 마지막에 받아 둔 옛
# 주소로만 버틴다. 배포 자체는 성공했다고 나오므로 무엇이 잘못됐는지 드러나지
# 않는다. 그래서 여기서 멈춘다.
#
# 판정 대상은 배포될 디렉터리다. 그 경로는 배포 도구가 환경변수로 알려 주며,
# 없을 때만 설정 파일의 기본 위치를 쓴다.
#
# 검사 내용을 배포 설정에 문자열로 적지 않고 이 파일로 뺀 이유: 배포 도구가
# 명령 문자열을 자체적으로 훑어 보기 때문에, 따옴표나 묶음 기호가 든 문장은
# 원래 뜻과 다르게 실행될 수 있다.
set -uo pipefail

dir="${RESOURCE_DIR:-hosting}"
target="$dir/app_config.json"

if [ ! -f "$target" ]; then
  echo "✗ $target 없음 — 이대로 배포하면 앱이 읽는 주소 파일이 사라진다."
  echo "  배포는 map-service-infra/scripts/map-serve.sh 로 한다(주소를 쓴 뒤 올린다)."
  exit 1
fi

url="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("api_base_url") or "")' "$target" 2>/dev/null)"

if [ -z "$url" ]; then
  echo "✗ $target 의 주소가 비어 있다."
  exit 1
fi

case "$url" in
  https://*) ;;
  *) echo "✗ 주소가 https 가 아니다: $url"; exit 1 ;;
esac

# 파일이 있고 모양도 맞는데 그 끝에 아무것도 없는 경우가 실제로 있었다. 잠깐
# 열었다 닫는 임시 주소를 적어 두고 그대로 굳으면, 앱은 옛 주소로 버티다가
# 조용히 멈춘다. 배포는 성공으로 나온다. 그래서 한 번 물어본다.
if ! curl -fsS -m 5 "$url/healthz" >/dev/null 2>&1; then
  echo "✗ $url 이 답하지 않는다 — 죽은 주소를 올리려 하고 있다."
  echo "  서버를 먼저 띄우거나, 주소를 고친 뒤 다시 하라."
  exit 1
fi

exit 0
