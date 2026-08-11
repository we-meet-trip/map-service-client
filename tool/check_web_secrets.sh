#!/usr/bin/env bash
# 호스팅 배포 직전에 서버용 키가 산출물에 섞여 있는지 본다.
#
# 웹 빌드는 실행 설정 파일을 자산으로 그대로 싣는다. 그 파일에는 지도 식별자
# 말고도 서버에서만 써야 할 키들이 함께 들어 있어서, 산출물을 통째로 올리면
# 누구나 주소만 알면 내려받을 수 있다. 한 번 나간 값은 되돌릴 수 없으므로
# 올리기 전에 막는다.
#
# 세 겹으로 본다.
#   0) 소스 대조 — 코드 안에 값으로 적힌 키를 찾는다. 산출물이 아니라 원본을
#      본다.
#   1) 값 대조 — 실행 설정 파일에서 서버용 키의 실제 값을 읽어 산출물 전체에서
#      찾는다. 어느 경로로 새든(자산이든 코드에 박혔든) 걸린다.
#   2) 이름 대조 — 실행 설정 파일을 못 읽는 환경에서 쓰는 보조 수단. 산출물
#      안의 설정 자산에 서버용 키 이름이 값과 함께 있으면 막는다.
#
# 0번이 필요한 이유. 1번과 2번은 실행 설정 파일에 이름이 올라 있는 키만 본다.
# 코드에 값을 직접 적으면 그 파일에 이름이 없으니 어느 겹에도 걸리지 않고,
# 그대로 산출물에 실려 나간다. 그래서 값의 모양만 보고 거르는 겹을 앞에 둔다.
#
# 지도 식별자는 검사 대상이 아니다. 웹 지도는 그 값을 스크립트 주소에 실어
# 보내므로 원래 공개되며, 방어는 발급처에 등록한 도메인 목록이 한다.
#
# 판정 대상 경로는 배포 도구가 환경변수로 알려 준다. 검사 내용을 배포 설정에
# 문자열로 적지 않고 이 파일로 뺀 이유는 옆의 check_app_config.sh 와 같다.
set -uo pipefail

client_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dir="${RESOURCE_DIR:-hosting}"
env_file="$client_dir/.env"

# 서버에서만 써야 하는 키. 이 목록에 없는 값은 검사하지 않는다.
SERVER_KEYS=(KAKAO_REST_API_KEY VISION_SERVER_HOST)

# 값이 적혀 있을 만한 원본 위치.
#
# 화면 코드와 웹 껍데기만으로는 모자란다. 네이티브 설정도 값을 받는 자리다 —
# 안드로이드 매니페스트와 gradle 설정, 애플 plist 와 프로젝트 설정은 키를
# 문자열로 적어 넣게 되어 있고, 그렇게 적힌 값은 앱에 그대로 실린다. 도구와
# 테스트도 본다. 한 번 부르려고 값을 적어 두었다가 지우지 않고 남기기 쉬운
# 자리라, 실제로 값이 가장 오래 남는 곳이다.
SOURCE_DIRS=(lib web android ios tool test)

# 사람이 값을 적는 자리가 아닌 것은 뺀다. 보는 범위를 넓히면 기계가 만든
# 파일까지 딸려 들어오는데, 거기서 나오는 적중은 전부 헛것이면서 빌드는
# 똑같이 멈춘다. 그물이 자주 헛걸리면 결국 검사를 끄게 되므로 여기서 거른다.
#   - 받아 온 의존성과 빌드 산출물: 남의 코드이거나 다시 만들면 그만인 파일이다.
#     .symlinks 는 꾸러미 보관소를 가리키는 이음줄이라, 따라 들어가면 이
#     저장소 밖까지 훑는다.
#   - 도구가 다시 써 내는 파일: 플러그인 등록 파일은 긴 클래스 이름이, 편집기가
#     남기는 작업공간 점검 파일은 숫자가 섞인 항목 이름이 아래 모양에 걸린다.
#     사람이 고쳐도 다음 빌드에 되돌아가므로 검사할 뜻이 없다.
#   - 잠금 파일: 받아 온 꾸러미의 검사값 목록이라 긴 16진 문자열이 정상적으로
#     들어 있다.
# 애플 프로젝트 파일은 빼지 않는다. 그 안을 채우는 객체 번호는 24자리여서
# 아래 길이 기준 밑으로 떨어지고, 프로젝트 설정에 값을 적어 넣는 일은 실제로
# 있으므로 그건 걸려야 한다.
EXCLUDES=(
  --exclude-dir=.git
  --exclude-dir=.dart_tool
  --exclude-dir=build
  --exclude-dir=.gradle
  --exclude-dir=.kotlin
  --exclude-dir=Pods
  --exclude-dir=.symlinks
  --exclude-dir=ephemeral
  --exclude-dir=xcuserdata
  --exclude-dir=DerivedData
  '--exclude=GeneratedPluginRegistrant.*'
  --exclude=IDEWorkspaceChecks.plist
  '--exclude=*.lock'
)

# 키처럼 보이는 문자열의 모양. 근거는 둘이다 — 충분히 길다는 것과, 발급처가
# 앞에 붙여 주는 머리표.
#   - 16진 문자열: 발급처가 이 모양으로 주는 키가 많다. 색상값은 여덟 자를
#     넘지 않아 길이만으로 갈린다.
#   - 영숫자에 + / = 가 섞인 문자열: 첫 글자가 / 인 것은 뺀다. 그렇게 하지
#     않으면 화면 경로 문자열이 전부 걸린다.
#   - 주소 안에 값이 붙어 있는 경우: 이름=값 꼴을 그대로 본다. 값 자리에
#     변수를 끼워 넣은 것은 첫 글자가 달라 걸리지 않는다.
#   - 머리표가 붙는 키: 앞머리가 정해져 있어 길이나 놓인 자리를 따지지 않는다.
#     주소 한가운데에 있어도, 이름=값 꼴이 아니어도 걸린다.
#   - 8-4-4-4-12 마디로 끊긴 16진 문자열: 이 모양으로 발급되는 토큰이 있다.
#     마디 길이까지 우연히 맞는 일은 없다.
SOURCE_PATTERNS=(
  "['\"][0-9a-fA-F]{28,}['\"]"
  "['\"][A-Za-z0-9+][A-Za-z0-9+/]{26,}={0,2}['\"]"
  "(serviceKey|apiKey|api_key|appkey)=[A-Za-z0-9%+/=_-]{15,}"
  "AIza[0-9A-Za-z_-]{30,}"
  "(sk|pk|rk)_(live|test)_[0-9A-Za-z]{16,}"
  "gh[pousr]_[0-9A-Za-z]{30,}"
  "AKIA[0-9A-Z]{16}"
  "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"
)

# 따옴표·꺾쇠·빗금으로 끊긴 긴 토막. 위 모양들이 비워 두는 자리를 메운다.
#   - 주소 경로 한 칸에 박힌 키. 'http://호스트/키/json/…' 처럼 따옴표와 키
#     사이에 주소가 끼면, 따옴표에 붙어 있어야 하는 모양으로는 빗나간다.
#     값을 경로에 실어 받는 발급처가 있으므로 실제로 나오는 모양이다.
#   - 사이에 - 나 _ 가 섞인 키. 위 모양들은 영숫자만 상정한다.
#   - 설정 파일의 <string>값</string> 처럼 따옴표 없이 태그로 끊긴 자리.
# 이대로 두면 낱말을 이어 붙인 이름(화면 속성 이름, 클래스 이름)이 같은 길이로
# 걸린다. 그래서 맞은 부분만 떼어 내(-o) 숫자가 섞인 것만 남긴다. 발급된 키는
# 사실상 전부 숫자를 품고, 낱말을 이은 이름은 그렇지 않다는 데 기댄다.
LONG_TOKEN_PATTERN="['\"<>/][A-Za-z0-9_-]{27,}['\"<>/]"

found=0

# 0) 소스 대조
#
# 한 줄이 여러 모양에 함께 걸릴 수 있어 위치를 모아 두었다가 한 번만 알린다.
# 값 자체는 찍지 않는다. 찍으면 검사 결과가 새 유출 경로가 된다.
# 이진 파일(-I)은 건너뛴다. 그림과 글꼴 안의 바이트 더미는 어떤 모양이든 나온다.
source_hits=""
for sub in "${SOURCE_DIRS[@]}"; do
  [ -d "$client_dir/$sub" ] || continue
  for pattern in "${SOURCE_PATTERNS[@]}"; do
    hits="$(grep -rEnI "${EXCLUDES[@]}" -- "$pattern" "$client_dir/$sub" 2>/dev/null | cut -d: -f1,2)"
    [ -n "$hits" ] || continue
    source_hits="$source_hits$hits"$'\n'
  done
  # 떼어 낸 토막은 맨 뒤 칸에 온다. 경로에는 : 이 없어 칸이 밀리지 않는다.
  hits="$(grep -rEnoI "${EXCLUDES[@]}" -- "$LONG_TOKEN_PATTERN" "$client_dir/$sub" 2>/dev/null \
    | awk -F: '$NF ~ /[0-9]/ { print $1 ":" $2 }')"
  if [ -n "$hits" ]; then
    source_hits="$source_hits$hits"$'\n'
  fi
done
if [ -n "$source_hits" ]; then
  echo "✗ 키처럼 보이는 값이 코드에 적혀 있다."
  printf '%s' "$source_hits" | sort -u | sed "s|^$client_dir/|    |"
  found=1
fi

# 아래 두 겹은 산출물을 본다. 빌드 전에 부르면 볼 것이 없으므로 건너뛴다.
if [ -d "$dir" ]; then
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
fi

if [ "$found" -eq 0 ]; then
  exit 0
fi

echo ""
echo "  이대로 올리면 서버용 키가 공개된다. 배포를 중단한다."
echo "  웹 빌드는 tool/build_web.sh 로 한다(지도 식별자만 남긴 설정으로 빌드한다)."
echo "  코드에 값이 적혀 있다면 지우는 것만으로는 끝나지 않는다. 그 값은 이미"
echo "  이력에 남아 있으므로 발급처에서 다시 받고, 호출은 서버를 거치게 옮긴다."
exit 1
