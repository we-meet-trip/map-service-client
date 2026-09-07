# MAP 스토어 등록 준비 자료

작성·공식 문서 확인: 2026-09-07 KST. 작업 시작일에 맞춰 파일명은 유지한다.

**판정: 자료 준비 중이며 제출 가능 판정은 HOLD다.** 이 문서는 정책 HTML 소스, 입력 초안, 심사 시나리오를 정리한다. 계정 등록·결제, 공개 페이지 반영, 서버 전체 수용 검사, 최신 양 플랫폼 설치·심사 통과를 완료했다는 기록이 아니다.

## 1. 근거와 소유 범위

- 기준 Client: `origin/fix/client-origin-boundary-20260906`, `bd819551e8bdf5fa754e5357b45bff26bdd0949a`.
- 자료 worktree: `/tmp/map-client-store-materials-20260907-01`, branch `fix/store-materials-20260907-01`.
- 변경 범위: `hosting/legal/**`, 이 문서, [개인정보 선언 초안](STORE_PRIVACY_DECLARATIONS_2026-09-06.md). native/app ID 구현은 별도 담당자의 후속 commit을 통합해야 한다.
- 기존 실행 증거는 MAP 루트의 `evidence/runtime/native-signed-build-origin-20260906/`, `evidence/runtime/release3-postdeploy-verification-20260906.json`, `evidence/runtime/route-e2e-final-20260906.json`을 참조한다. 최신 GCP 읽기 전용 관찰은 `evidence/parallel/native-store/gcp-readonly-current-20260906.json`의 2026-09-07 04:52:35–40 UTC 기록이다. 이 자료 작업에서 재실행한 결과가 아니다.
- 최신 공개 자원 관찰은 MAP 루트 `evidence/parallel/native-store/public-resources-current-20260906.json`과 root 관찰을 따른다. HTTP 200만으로 정책·지원·삭제 페이지 정상 판정을 내리지 않는다.

## 2. 현재 확인 범위

| 영역 | 확보한 근거 | 남은 수용 조건 |
| --- | --- | --- |
| 정책 소스 | 개인정보·이용·위치·삭제 본문 및 새 지원 페이지, 5페이지 정책 탐색 링크 | 운영자 주소·국외 이전·백업 등 아래 미완 항목 확정, root 공개 반영 후 본문 SHA/표제/링크 실측 |
| 현재 공개 정책 | privacy/terms/location HTTP 200이지만 기준 소스와 SHA가 다르고 만 18세 문구가 확인되지 않음 | 승인된 소스와 공개 본문 동일성 검증 |
| 공개 삭제·지원 | 둘 다 2,226 bytes, 같은 SHA, 지원 이메일 미검출이라는 root 관찰 | SPA fallback 여부와 실제 삭제 요청·지원 본문 확인; 현재 완료로 인정하지 않음 |
| 공개 앱 연결 | AASA `applinks.details=[]`, assetlinks는 `kr.mapservice.client`만, app_config는 환경 표식 없이 test API | test/prod별 최종 ID·서명·도메인·origin·callback과 대응하는 공개 계약 |
| Android 기존 산출물 | bd819 signed run 34082864972, 1.0.0(359), 16 KB 정렬 검사 근거 있음 | 이 산출물은 test 환경인데 package가 `kr.mapservice.client`; 후속 분리 SHA로 새 검증. `libapp.so` GNU_RELRO 미구성은 별도 미완 |
| iOS 실행 | 기존 Booted MAP 1.0.0(1)은 source SHA 미확인 | 최종 signed IPA/서명·privacy manifest·SDK 확인 및 정확 SHA 설치 증거 |
| GCP 서비스 | 04:52 UTC 읽기 전용 관찰: 18/18 running, 구성된 10개 healthy, health/미인증 거부 12/12 PASS, 6서비스 SHA·digest가 R3와 일치. 기존 경로 6사례 개별 PASS | 최신 관찰의 release gate는 INCOMPLETE. Apple 필수 설정·callback 일치도는 이번 관찰에서 미수집. 전체 기능·사용자 데이터 보존 PASS로 바꾸지 않음 |
| 콘솔 | root가 양쪽 화면에서 정식 개발자 계정 일치 확인 | 아래 본인 입력 및 실제 등록 상태 재확인; app record/시험 트랙 미완 |

## 3. 콘솔 입력 초안과 본인 입력 경계

| 필드 | 준비 값 / 판정 |
| --- | --- |
| 앱 이름 | `MAP` — 콘솔의 이름 사용 가능 여부는 아직 확인하지 않음 |
| 운영팀 표시 | `이음잇다` — 법인·사업자등록 완료로 표시하지 않음 |
| 개발자 유형 | 개인; 운영자 류제무. Apple의 개인 판매자명은 법적 이름 기준이므로 팀명과 같다고 보장하지 않음 |
| 정식 개발자 로그인 | `decemryu77@gmail.com` |
| 공개 지원 / GCP 이메일 | `mapadmin26@gmail.com` — 정식 개발자 계정을 이 주소로 바꾸지 않음 |
| 공개 연락 전화 | `010-7721-3709` |
| 주 카테고리 후보 | Apple Travel / Google Play 여행 및 지역정보 — 실제 콘솔 항목 확인 후 입력 |
| Apple 부제 후보 | `여행 일정과 동행을 한곳에` |
| Play 짧은 설명 후보 | `여행 일정과 경로·날씨를 확인하고 동행과 대화하세요.` |
| 심사 연락처 | 운영자 이름·지원 이메일·전화는 위 값 사용 후보. 콘솔 요구 필드 및 실제 수신 가능 여부 확인 필요 |
| 앱 식별자 | 후속 native commit의 prod bundle ID/package 및 서명 확인 전 고정하지 않음 |

설명 초안:

> MAP은 여행 일정을 만들고 저장·편집하며 이동 경로와 날짜별 날씨를 확인하는 여행 앱입니다. 동행과 채팅하고 문제가 있는 콘텐츠를 신고하거나 상대를 차단할 수 있습니다. 외부 AI 전송에 동의하면 일정 추천, 장소 인식 답변, 리뷰 요약 기능을 이용할 수 있습니다. AI 답변과 경로·날씨 정보는 실제 현장 상황과 다를 수 있습니다. MAP은 만 18세 이상 이용자를 대상으로 합니다.

이 설명은 해당 기능의 최종 앱·서버 수용 검사 후 입력하는 초안이다. 무오류 경로, 기상 보장, 무수집, 즉시 완전 삭제, 출시 완료를 홍보 문구에 넣지 않는다.

root의 현재 화면 관찰은 Apple Developer Program 가입의 법적 이름·전화·주소 단계와 Play 개인 개발자 설정의 결제 프로필 선택 단계다. 기존 개인 Google One 결제 프로필 표시가 개발자 가입·결제 완료 또는 해당 프로필 선택 승인이라는 뜻은 아니다. 사용자가 이미 로그인·입력한 이력이 있으므로 계정이 없다고 단정하거나 로그인을 반복 요청하지 않는다.

### 실제 주소가 필요한 지점

1. Apple 개인 가입은 법적 이름·전화·주소 등 연락 정보를 요구하며 우편사서함 주소를 받지 않는다. 사용자가 현재 가입 화면에 실제 정보를 직접 입력해야 한다. [Apple 가입 안내](https://developer.apple.com/programs/enroll/)
2. Google Play 개인 계정의 법적 이름·주소는 연결된 Google Payments 프로필을 기준으로 확인된다. 공개 전 검증이 필요하다. 콘솔에 표시된 프로필을 사용자가 확인해야 하며, 개인 주소의 공개 범위는 해당 계정·국가 화면을 별도로 확인한다. [Google Play 개인 계정 정보](https://support.google.com/googleplay/android-developer/answer/13628312?hl=en-EN)
3. 위치정보법 제19조 제1항 제1호는 개인위치정보를 이용해 서비스를 제공하려는 위치기반서비스사업자의 약관에 상호·주소·전화번호 등 연락처를 명시하고 동의를 받도록 정한다. MAP의 해당 사업 구분·신고 의무와 기록 보존 체계를 확인하고 실제 약관 기재 주소를 확정해야 한다. 현재 약관의 ‘제한 시험’ 안내가 이 요건의 예외를 입증하지 않는다. 이메일을 물리적 주소로 대신하지 않는다. [현행 제19조](https://www.law.go.kr/LSW/lsLinkCommonInfo.do?lsJoLnkSeq=1032065431), [위치기반서비스사업 신고 안내](https://www.kmcc.go.kr/user.do?page=A04100213)

주소 원문·신분증·카드 정보는 채팅이나 Git에 수집하지 않는다. 공개 약관에 사용할 주소와 공개 범위는 사용자에게 필요한 이유를 안내한 뒤 확정한다. 현재 주소는 미제공이다.

## 4. 정책·지원 URL 준비

아래는 **현재 소스에 대응하는 후보 URL**이다. 실제 공개 본문을 root가 검증하기 전 콘솔 완료 근거로 사용하지 않는다. 개인정보 선언과 정책 본문이 다르면 먼저 그 차이를 해결한다.

| 콘솔 용도 | 후보 URL | 소스 |
| --- | --- | --- |
| 개인정보처리방침 | `https://mapcenter-b59ca.web.app/legal/privacy.html` | [privacy.html](../hosting/legal/privacy.html) |
| 이용약관 | `https://mapcenter-b59ca.web.app/legal/terms.html` | [terms.html](../hosting/legal/terms.html) |
| 위치기반서비스 약관 | `https://mapcenter-b59ca.web.app/legal/location-terms.html` | [location-terms.html](../hosting/legal/location-terms.html) |
| 앱 외 계정 삭제 / Privacy Choices 후보 | `https://mapcenter-b59ca.web.app/legal/delete-account.html` | [delete-account.html](../hosting/legal/delete-account.html) |
| Support URL | `https://mapcenter-b59ca.web.app/legal/support.html` | [support.html](../hosting/legal/support.html) |

지원 페이지는 앱 내 신고·차단 및 상태 확인, 신고 이의제기, 미설치 상태의 계정 삭제, AI 동의 철회·기전송 자료 문의, 이메일 복사 대안을 안내한다. 이메일 링크를 누르는 것과 요청을 실제 발송·접수하는 것을 구분한다. 이 작업에서 메일 발송·Firebase 배포는 하지 않는다. Google은 계정 생성 앱에 앱 안과 밖의 삭제 요청 경로를 요구하므로 두 경로의 실제 처리를 모두 확인해야 한다. [Google Play 계정 삭제 요건](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en)

## 5. 연령·UGC·생성형 AI 제출 답변 초안

- **대상 이용자:** 만 18세 이상만 선택한다. Apple 질문에는 실제 콘텐츠·채팅·UGC·접근 통제를 그대로 답하고, 필요하면 더 높은 등급으로 18+를 지정한다. 국가별 등급 결과를 모두 같은 숫자라고 표기하지 않는다. Play의 18+ 대상 설정과 IARC 콘텐츠 등급 설문은 별개다. [Apple 연령 등급](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/), [Play 대상 연령](https://support.google.com/googleplay/android-developer/answer/9867159?hl=en-GB), [Play 콘텐츠 등급](https://support.google.com/googleplay/android-developer/answer/9859655?hl=en)
- **UGC·사용자 간 대화:** 있음. 채팅 메시지·일정 관련 사용자 콘텐츠를 숨기지 않는다. 소스에 메시지 신고, 차단, 본인 신고 처리 상태, 이용약관의 금지행위·문의처가 있다. 필터링, 실제 운영자의 검토·조치·이의제기 응답까지 최신 서버와 앱에서 확인하기 전 ‘운영 완료’로 답하지 않는다. [Apple 심사 지침 §1.2](https://developer.apple.com/app-store/review/guidelines/), [Play UGC 정책](https://support.google.com/googleplay/android-developer/answer/9876937?hl=en)
- **생성형 AI:** 있음. 일정·Vision·리뷰 요약에서 Gemini 전송 전 기능별 명시적 동의 UI가 있으며 각 결과의 인앱 신고 경로가 있다. 이메일은 인앱 AI 신고를 대체하지 않는다. AI 신고 접수 번호·상태·운영 처리 연결을 검증한다. [Play AI 생성 콘텐츠 정책](https://support.google.com/googleplay/android-developer/answer/13985936?hl=en), [Apple 심사 지침 §5.1.2(i)](https://developer.apple.com/app-store/review/guidelines/)
- **연령 게이트:** `service_consent_screen.dart`, `service_consent_api_service.dart`, `policy_account_screen.dart`의 동의·생년월일 처리를 기준으로 under-18 차단과 과거 계정 보완을 검증한다. 체크박스가 신원·나이의 강한 검증을 완료했다는 뜻은 아니다. Gemini 역시 18세 미만 대상·접근 가능성이 높은 서비스 이용 제한을 명시하므로 스토어 표시만으로 계약 충족을 주장하지 않는다. [Gemini API 약관](https://ai.google.dev/gemini-api/terms)
- **학습:** 실사용자 capture/export와 자체 학습 HOLD를 유지한다. 외부 AI 기능 동의를 학습 동의로 사용하지 않는다.

## 6. 비특권 심사 계정과 심사 메모 초안

**심사 계정: 아직 미생성·미검증.** 실제 제출용 자격증명은 App Store Connect의 비공개 Review Information 또는 Play App access에만 입력한다. 문서·Git·스크린샷에는 저장하지 않는다. 관리자 계정, 운영자 개인 계정, production SSH/DB 권한, 실제 사용자 대화방을 심사에 제공하지 않는다.

준비 조건:

1. root가 승인한 심사 환경에 일반 사용자 A와 상대역 B를 준비한다. 합성 프로필·일정·메시지만 사용하고 자동 초대·메일 발송은 하지 않는다. A에게 관리자·학습 권한을 부여하지 않는다.
2. 일반 이메일 로그인으로 심사자가 별도 운영자 OTP·유료 가입·숨은 승인 없이 기능에 접근할 수 있는지 실제 확인한다. 가입·동의·연령 게이트는 면제하지 않는다. A의 만 18세 이상 시험 정보와 동의 상태를 기록하되 공개하지 않는다.
3. A에는 채팅·경로·저장·신고를 확인할 합성 자료를 둔다. 삭제 시험용 계정은 A와 별도로 준비하여 심사 접근 계정을 사전 삭제하지 않는다. Apple 가입·권한 철회는 실제 Apple 인증을 사용한 별도 허용 시험으로 검증한다.
4. 심사 기간의 서버 가용성, AI 공급자 사용 예산·쿼터, 지역 접근·로그인 조건을 root가 확인한다. 이 자료 작업에서는 기존 유료 AI 시험을 반복하지 않는다.
5. 검증한 앱 버전/빌드·SHA·환경·심사 계정 검사 시각을 비밀 없는 증거로 남긴다. 계정이 만료되거나 서버 gate가 실패하면 메모를 제출하지 않는다. Apple은 심사 접근 정보와 작동하는 서비스를 요구한다. [Apple 심사 지침 §2.1](https://developer.apple.com/app-store/review/guidelines/)

심사 메모 본문 후보(위 조건 통과 후 플랫폼에 맞춰 사용):

> MAP은 만 18세 이상 대상 여행 앱입니다. 제공한 일반 사용자 계정으로 이메일 로그인을 선택해주세요. 서비스 동의가 나타나면 약관·개인정보처리방침과 연령 조건을 확인한 뒤 진행할 수 있습니다. 홈에서 준비된 여행 일정을 열어 저장·편집, 경로와 날짜별 날씨를 확인하고, 동행 채팅에서 메시지 메뉴의 신고·차단을 확인할 수 있습니다. 마이페이지의 ‘신고 내역 및 차단 관리’에서 처리 상태를 확인합니다. AI 일정·Vision·리뷰 요약은 외부 전송 동의가 별도로 나타납니다. 위치 전송 선택과 휴대전화 권한은 별개이며 동의는 마이페이지에서 철회할 수 있습니다. 계정 삭제는 마이페이지 → 프로필 수정 → 탈퇴하기에 있습니다. 미설치 상태의 삭제 요청과 지원 연락처는 등록한 정책·지원 URL에서 확인할 수 있습니다.

실제 제공 계정, 합성 일정의 화면상 이름, 운영 검증 시각, 특수 접근 조건은 검증 후 비공개 콘솔 메모에 추가한다. 현재 이 값들을 임의 생성해 완료된 심사 메모로 제출하지 않는다.

## 7. 화면 캡처·설치 시나리오

모든 항목은 **촬영·실행 예정**이다. 최신 통합 SHA를 설치한 뒤 iOS와 Android를 순차 실행한다. 기기·OS·빌드·환경·UTC·증거 파일 SHA를 함께 기록한다. 원본 사용자 위치·대화·계정 식별자·키는 캡처하지 않고 합성 자료를 사용한다. 가상 UI로 실제 앱 스크린샷을 대신하지 않는다.

| 번호 | 화면 / 행동 | 확인할 내용 | 용도 |
| --- | --- | --- | --- |
| 01 | 첫 로그인과 동의 | 정책 링크 본문, 18세 미만 차단, 동의 거부 시 보호 기능 미접근 | 심사 증거 |
| 02 | 홈·여행 목록 | 실제 저장 일정 진입, 로딩·빈 상태 | 스토어 후보 |
| 03 | 일정 작성·편집 | 수동 순서 보존, 날짜·시간·교통수단 표시 | 스토어 후보 + 증거 |
| 04 | 경로 지도 | walk/bicycle 결과, 저장·재실행·명시적 최적화 | 스토어 후보 + 증거 |
| 05 | 날짜별 날씨 | 현재·여행 기간 전환, 미제공 기간 안내 | 스토어 후보 + 증거 |
| 06 | AI 일정·리뷰 동의 | 공급자·항목·거부 경로, 결과와 신고 버튼 | 심사 증거 |
| 07 | Vision 동의·권한 | 위치 전송 기본 해제, 카메라·마이크 거부/재허용, 결과 신고 | 심사 증거 |
| 08 | 동행 채팅 | REST 이력 + STOMP 송수신 + 재접속·읽음 | 스토어 후보 + 증거 |
| 09 | 메시지 신고·차단 | 접수 번호, 상대 메시지 숨김, 재시작 후 상태 | 심사 증거 |
| 10 | 신고 센터 | 본인 신고만 노출, 상태·차단 해제, 비특권 접근 | 심사 증거 |
| 11 | AI 동의 철회 | 향후 전송 중단·오래된 비동기 결과 미표시 | 심사 증거 |
| 12 | 로그아웃·계정 전환 | 이전 계정 메시지·캐시·권한 미노출 | 심사 증거 |
| 13 | 별도 계정 탈퇴 | Apple revoke 포함 성공·실패 표시, 삭제 요청 웹 접근 | 심사 증거 |
| 14 | 오프라인·초대 링크 | 네트워크 재연결, 권한 없는 초대, 환경 간 링크 차단 | 심사 증거 |

스토어용 캡처는 기능을 설명하는 02–05·08 중 실제 통과 화면부터 선정한다. 각 콘솔이 요구하는 현재 기기 크기·매수·파일 형식은 업로드 시 확인한다. 심사 증거 전체를 공개 스토어 이미지로 올리지 않는다.

## 8. 제출 전 남은 gate와 인계

- root 운영: GCP 전체 서비스 수용, 보안 B 패치 결과, DB 권한·백업 보존/삭제/복원, 위치정보 확인자료·국외 이전 고지 확정. 경로 개별 PASS와 전체 사용자 행 보존 FAIL/미확정은 구분한다.
- native 담당: test/prod ID와 서명 인증서·키 제한, Kakao/Apple callback, AASA/assetlinks/초대 landing, 양 플랫폼 정확 SHA 산출물, iOS SDK privacy manifest·Required Reason API, Android 16 KB와 GNU_RELRO 별도 판정, 실제 지도·로그인/탈퇴 검사.
- root 공개 자원: 정책/지원/삭제 실제 페이지 반영과 외부 접근·본문 SHA 검증. 이 작업은 배포 권한을 인수하지 않는다.
- 운영자 본인: 콘솔 법적 정보·주소·동의·결제/신원 확인. 가입 완료, app record 생성, 시험 트랙, 최종 제출, 심사 통과, 공개 출시는 각각 증거를 남긴다.
- Play 신규 개인 계정 조건이 적용되면 12명 이상이 연속 14일 참여한 비공개 테스트와 production access 신청을 준비한다. 실제 계정 생성일·콘솔 조건으로 적용 여부를 확인한다. 내부 테스트나 합성 계정을 이 인원·기간 증거로 바꾸지 않는다. [Google Play 테스트 요건](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en)
- root 서비스 gate가 전체 PASS가 아니면 artifact·시나리오 준비까지만 인정한다. develop/master 병합, NCP 생성·전환, DNS 변경, 최종 스토어 제출·공개는 이 자료로 승인되지 않는다.

## 9. 이 자료 작업의 검증

2026-09-07 이 worktree에서 Python 표준 라이브러리 `html.parser`·`pathlib`·`urllib.parse`로 실제 검사했다. HTML 5개 모두 구조 균형, `lang=ko`, 단일 title/h1/main/nav, 접근성 탐색 이름·포커스 스타일, 중복 ID 없음, 로컬 링크 대상 존재 검사를 PASS했다. 정책 탐색 연결은 25개이며 문서 링크 30개의 HTTPS 형식 또는 로컬 파일 존재도 PASS했다. 지원 페이지의 신고·삭제·AI 동의 설정·이메일 경로를 확인했다. 메일 발송이나 외부 요청은 하지 않았다.

공개 반영 시 비교할 지원 본문의 SHA-256은 `dbe747d28e274fe4b1d57be5616ba6953194b09cd6ac76b86b2c1bc032f58a56`이다. 나머지 4페이지 SHA는 commit 인계 기록에 남긴다. 로컬 검사는 공개 HTTP 응답, 메일 수신, 앱 실행, CI, 스토어 승인 근거가 아니다. 변경 공백 검사와 종료 시 `graphify update .` 결과는 정확 commit과 함께 인계한다. AST 방식만 사용하며 유료 semantic extraction은 사용하지 않는다.
