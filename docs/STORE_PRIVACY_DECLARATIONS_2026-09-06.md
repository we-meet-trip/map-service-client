# MAP App Privacy / Data safety 답변 초안

작성·공식 문서 확인: 2026-09-07 KST. 기준 Client `bd819551e8bdf5fa754e5357b45bff26bdd0949a`.

**제출 상태: HOLD.** 아래는 실제 소스에서 확인한 전송 경로를 바탕으로 한 입력 초안이다. 플랫폼·SDK 최종 산출물, 공급자 계약과 보관, root 운영 증거가 필요한 답은 보류한다. 콘솔에 답을 입력하거나 제출하지 않았다. 공개 정책·계정·심사 준비 상태는 [스토어 준비 자료](STORE_READINESS_2026-09-06.md)를 따른다.

## 1. 답변 원칙

Apple은 앱과 통합 공급자가 요청의 실시간 처리보다 오래 접근할 수 있는 기기 외 전송을 수집으로 본다. 계정·기기에 연결되는 가명 식별자도 자동으로 익명 데이터가 되지 않는다. 선택 기능이라도 공개 제외의 모든 요건을 입증하지 못하면 선언한다. Google Play는 SDK를 포함한 기기 외 전송과 일시 처리도 설문에 포함한다. MAP이 보유하지 않는다는 이유만으로 Gemini·지도 SDK 수집을 제외하지 않는다. [Apple App Privacy](https://developer.apple.com/app-store/app-privacy-details/), [Google Play Data safety](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en)

아래 `필수`는 서비스 전체 이용의 필수와 기능 선택 이후 처리를 구분한다. 최종 콘솔의 유형·목적·선택 여부는 실제 출시 앱 전체 행위를 합쳐 입력해야 하며, 표의 `확인 필요`를 무수집·공유 없음·익명으로 바꾸지 않는다.

## 2. 소스별 데이터 흐름과 유형 초안

| 실제 데이터 / 근거 | 기기 외 전송·보관 범위 | Apple 유형·용도 초안 | Play 유형·용도 초안 | 선택·연결 판정 |
| --- | --- | --- | --- | --- |
| 이메일, 계정 ID·닉네임·인증 정보 — `lib/core/api/auth_api_service.dart`, `user_api_service.dart` | MAP 회원·인증 API, 선택한 Kakao/Apple 로그인. 세션·계정 데이터는 서버 보관 | Email Address, User ID; App Functionality | Email address, User IDs; Account management, App functionality, Fraud prevention/security | 계정 이용 필수. User-linked. 닉네임은 식별자이며 실명 수집과 동일시하지 않음 |
| 생년월일·연령/약관 동의 — `signup_step2_screen.dart`, `policy_account_screen.dart`, `service_consent_api_service.dart` | 가입/프로필 API 및 `/api/v1/consents`; 연령 게이트에서 서버 확인 | Other Data Types; App Functionality | Other personal info; Account management, App functionality, compliance | 동의·18세 조건 필수. 생년월일은 가입 건너뛰기와 기존 계정 보완 경로가 다르므로 출시 gate에서 요구 범위를 확인. User-linked |
| 성별·관심사·테마·프로필 URL — `auth_api_service.dart`, `user_api_service.dart` | 선택 프로필 및 추천 입력. 로컬 표시 정보와 서버 프로필은 구분 | Other Data Types / Other User Content; App Functionality, Product Personalization. 프로필 이미지 수집 경로는 사진 유형에도 반영 | Other personal info / Other user-generated content; App functionality, Personalization | 제공 여부는 선택, 제공하면 계정에 연결. 실제 화면에서 전송하는 필드 확인 |
| 정밀 GPS·출발/도착/선택 장소 좌표·일정 경로 — `lib/features/vision/screens/vision_screen.dart`, `lib/common/widgets/external_ai_consent.dart`, 일정·경로 API 호출 | MAP API·저장 일정/작업 및 기능별 공급자. Vision은 위치 전송 동의가 있을 때 원본 lat/lng를 MAP에 보냄 | Precise Location; App Functionality, Product Personalization. 실제 축소/IP 유래 위치는 Coarse Location 추가 여부 확인 | Precise location; App functionality, Personalization. Approximate location은 공급자·payload별 추가 확인 | 기기 위치 권한 및 기능별 선택. 저장 일정/작업은 계정 연결. 전부 일시 처리라고 답하지 않음 |
| 장소 검색어·선택·여행 날짜·예산·선호·일정 입력/결과 | MAP 일정·검색/추천 경로와 Gemini. 계정 일정·작업 보관 | Search History, Other User Content; App Functionality, Product Personalization | In-app search history, Other user-generated content; App functionality, Personalization | 검색·추천·저장을 사용하면 처리. 계정 연결. 실제 API/로그 보관과 검색 유형 범위 대조 |
| Vision 카메라 JPEG, 질문·음성 인식 텍스트, 최근 대화·기존 인식 결과 — `vision_models.dart`, `vision_screen.dart` | `frame_b64`, `voice_text`, `conversation_history` 등으로 MAP→인식/생성 처리. Gemini 안전 로그가 존재 | Photos or Videos, Other User Content; App Functionality. 인식된 환경·장소 특징은 Environment Scanning 해당 범위 확인 | Photos, Other user-generated content; App functionality | 기능·AI 전송 선택. 계정 인증 요청이므로 비연결 근거 없음. 사진 원본을 MAP 장기 DB에 저장하지 않는 것과 공급자 보관은 별개 |
| 음성 원본 — `speech_to_text`와 Vision 호출 | MAP 요청 모델에는 인식 텍스트가 있고 음성 파일 필드는 확인되지 않음. OS/선택 음성 인식 제공자의 원격 처리 가능성 확인 필요 | Audio Data 여부는 실제 iOS 제공자·OS 처리와 Apple의 자사 서비스 예외를 구분해 확정 | Voice or sound recordings 여부는 실제 Android 인식 제공자·옵션·외부 전송으로 확정 | 마이크 권한·음성 입력 선택. ‘전부 온디바이스’ 또는 양 플랫폼 동일 답변 금지 |
| 채팅 메시지·방 참가·읽음 — `lib/features/chat/screens/chat_room_detail_screen.dart`, REST/STOMP 경로 | MAP 채팅 서버 저장 및 방 참여자에게 전달 | Emails or Text Messages; App Functionality | Other in-app messages; App functionality | 채팅 기능 선택, 계정 연결. 서버가 읽을 수 있으므로 종단간 암호화로 수집 제외하지 않음 |
| 신고 사유·설명·대상 참조·처리 이력 — `moderation_api_service.dart`, `report_dialog.dart`, `moderation_center_screen.dart` | `/api/v1/moderation/reports`, 본인 신고/차단 API 및 운영자 검토 | Customer Support, Other User Content, User ID; App Functionality | Other user-generated content, User IDs; App functionality, Fraud prevention/security/compliance | 신고 선택, 계정 연결. 사진·전체 메시지 원본을 자동 첨부하는 UI가 아님. 상세 설명은 사용자가 입력한 자료 |
| 지원·삭제 요청 메일 — `hosting/legal/support.html`, `delete-account.html` | 사용자가 메일을 발송하면 MAP 지원 계정/메일 제공자가 접수 | Customer Support, Email Address; App Functionality 초안. 공개 제외 요건을 자동 적용하지 않음 | Email address, Other user-generated content; Account management, App functionality | 선택 요청. 실제 운영 보관·처리 절차 확인 필요 |
| 지도 SDK의 IP·기기/SDK 정보·가명 SDK 식별자·사용/오류 정보 | Google Maps SDK 직접 수집. MAP 서버 수집 여부와 독립 | Device ID, Product Interaction, Crash Data, Performance Data, Other Diagnostic Data 및 IP 사용 목적에 따른 유형 후보 | Device or other IDs, App interactions, Crash logs, Diagnostics 등 후보 | 기본 수집의 optional 여부·user linkage·목적을 최종 플랫폼/버전 공식 표와 대조. 자체 광고 SDK 부재만으로 제외하지 않음 |

위 타입은 코드 분석 결과를 콘솔 범주에 대응한 초안이다. 자유 입력란에 사용자가 임의로 쓰는 모든 민감 항목을 별도 수집 기능으로 가정하지 않는다. 이름·전화·주소·사진을 명시적으로 요구하거나 전송하는 별도 기능이 있는지는 각각 확인한다.

### 로컬 프로필과 정밀 위치의 경계

- `lib/data/local/profile_local_store.dart`는 환경·사용자별 Hive 키로 휴대전화·영문 이름·집/기타 주소·사진 경로 등을 저장한다. `profile_edit_screen.dart`의 해당 로컬 편집만 보고 서버가 이 필드를 모두 수집한다고 쓰지 않는다. 반대로 가입 이메일·프로필 API·주소 검색·일정 선택을 통한 전송을 로컬 저장으로 숨기지 않는다. 주소 검색의 공급자 전송과 주소를 일정에 사용하는 경로는 출시 네트워크 검사에 포함한다.
- Vision 동의 화면의 ‘약 100m’는 Gemini에 전달할 정보를 설명하는 UI 문구다. Client→MAP은 원본 좌표를 보낸다. 위경도 소수점 3자리 정도도 Apple의 precise 정의에 해당할 수 있으므로 ‘100m = coarse’로 자동 대응하지 않는다. 서버→Gemini 실제 주소/좌표 payload와 보관을 별도로 확인한다.
- 사진·질문 자체에 장소나 신원이 포함될 수 있다. 위치 선택 해제가 이미지·자유 입력의 정보를 제거하는 것은 아니다.

## 3. 공급자 수집·공유와 목적

| 공급자·경로 | 확인한 내용 | 최종 선언을 위한 미완 |
| --- | --- | --- |
| MAP / GCP / 자체 OSRM | 회원·일정·채팅·신고 API, 자체 도보·자전거 라우팅. root 문서의 확인된 백업 지역은 미국 | 배포·백업의 계약 법인/지역, 항목별 보관, 내부 전송 보호, 삭제 재적용과 최소 권한. NCP 운영으로 표시하지 않음 |
| Gemini | 기능별 동의 후 일정 입력, 사진/질문·문맥, 장소명·공개 블로그 발췌의 리뷰 요약. paid billing 조건은 기존 root 확인을 참조 | 최종 실제 공급자 요청에서 식별자·위치 축소, 메타데이터, 국외 이전 고지와 사용자의 거부·삭제 경로 |
| Google Maps Android/iOS | 직접 SDK 수집은 선언 범위. Android 공식 표에 기기·SDK 메타데이터, IP, 가명 식별자, 오류·사용 정보가 있음 | 최종 AAB/IPA 안의 버전·설정에 맞는 수집 유형/목적/연결성. Android 설명을 iOS에 그대로 복사하지 않음 |
| Kakao / Apple 로그인 | 선택한 로그인 제공자의 인증과 MAP 계정 연동 | 실제 요청 scope, 프로필/이메일·토큰 보관, 로그인 제공자의 독립 목적, Apple 탈퇴 revoke 증거 |
| Kakao 주소·ODsay 교통 / Naver 검색 / KMA·대기 | 주소·경로·검색어·지역 등 기능에 따른 API 호출은 공개 정책에 기술됨 | 각 서버 요청의 실제 필드, 계정/IP 전달 여부, 저장·계약·공유 예외. 리뷰 요약의 공개 글 출처와 사용자 선택 정보를 구분 |
| OS 음성 인식 / 이메일 서비스 | 플랫폼·사용자 선택 제공자에 따라 외부 처리 가능 | 음성 provider/locale/on-device 옵션과 실제 네트워크, 메일 운영자의 보관·접근 절차 |

Gemini 유료 조건에서 입력·출력이 제품 개선에 쓰이지 않는다는 설명은 무보관 약속이 아니다. 공식 안전성 정책에는 프롬프트·문맥·출력의 55일 보관과 탐지 시 권한 있는 담당자의 검토가 있다. 따라서 Vision 사진·대화나 일정 입력을 공급자까지 포함해 일시 처리라고 선언하지 않는다. 국가별 처리·계약 법인 등의 확정은 별도 필요하다. [Gemini API 약관](https://ai.google.dev/gemini-api/terms), [안전성 모니터링](https://ai.google.dev/gemini-api/docs/usage-policies)

Google Play의 공유 여부는 외부 전송 여부와 별도다. 개발자의 지시를 따르는 서비스 제공자 처리에는 공유 예외가 있을 수 있지만, 공급자의 독립 목적까지 모두 그 예외로 처리할 수 없다. 각 행의 실제 계약·목적을 확인하기 전 ‘공유 없음’은 보류한다. 사용자 채팅 상대에게 전달되는 데이터도 사용자가 예상한 행위에 따른 예외 조건을 따로 확인한다. [Data safety 공유 정의](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en)

## 4. 최상위 콘솔 질문의 준비 답변

| 질문 | 준비 답변 | 확정 조건 |
| --- | --- | --- |
| 개인정보 수집 여부 | **예** | 회원·일정·채팅 및 공급자 흐름이 존재; ‘수집하지 않음’ 사용 불가 |
| 데이터 유형 | 위 표의 확인된 유형 선택, 후보는 공급자/산출물 대조 | 데이터 유형마다 목적·선택·연결·공유 답변을 완성 |
| Apple 사용자 연결 | 계정·일정·메시지·신고는 **연결됨** | SDK 수집도 장치 식별자를 포함하므로 익명 근거 없이 ‘연결 안 됨’ 선택 금지 |
| Apple tracking | 자체 코드에서 광고/광고 측정 기능은 확인되지 않음. **최종 답 보류** | 로그인·지도 등 공급자가 교차 회사 광고 측정/브로커 결합에 쓰는지 확인. AI 외부 전송 자체를 tracking과 동일시하지 않음 |
| Play 데이터 공유 | **최종 답 보류** | 위 공급자별 서비스 제공자/사용자 주도 예외와 독립 목적 판정 |
| Play 필수/선택 | 계정·연령 동의는 필수; AI·채팅·선택 프로필·권한은 기능별 선택 초안 | 지도 SDK 자동 수집과 필수 서비스 경로를 포함해 같은 유형 전체를 판정 |
| Play 일시 처리 | 계정·저장 일정·채팅·신고·Gemini 입력은 **아니오** | 일회 조회의 임시 처리만 입증된 경로에 한해 별도 판정 |
| Play 전송 중 암호화 | **최종 답 보류** | 출시 앱→모든 API/SDK 및 서버→공급자의 TLS/민감정보 보호를 root가 확인. 외부 HTTPS만으로 내부 HTTP·오류 경로까지 PASS로 쓰지 않음 |
| 삭제 요청 방법 | 앱 내 탈퇴 + 앱 외 이메일 요청 URL 준비 | 공개 URL이 실제 삭제 안내여야 하고 계정 소유 확인·삭제/예외 회신 운영 검사 필요 |
| 독립 보안 검토 | **완료 답변 없음** | Trivy/일반 CI를 Play의 지정 독립 검증 완료로 표시하지 않음 |
| 자체 실사용자 학습 | **HOLD 유지** | capture/export 불가; 외부 AI 동의와 별개. 모델 학습 해제 근거로 이 문서를 사용하지 않음 |

## 5. SDK privacy manifest와 네이티브 제출 gate

기준 d04b79d 실제 iOS artifact의 GoogleMaps **8.4.0**에는 Google 자체 privacy manifest가 없었다. 후속 source는 GoogleMaps **9.4.0** / Google-Maps-iOS-Utils **6.1.0** 및 최소 iOS15로 고정했다. 원격 resolver34090060334가 두 pod만 변경하고 설치된 Google 원본 manifest SHA·선언을 검증했다. 잠금 파일 SHA256은 `f886c7470cce7882e1d9cead0e7050b54773351044b946947a0a6c5e4707bdbb`다. 새로 빌드한 앱 내부 vendor manifest 검사는 별도 필수 gate이며 plugin manifest로 대신하지 않는다. [정확 공급자·버전 계약](IOS_VENDOR_PRIVACY_2026-09-06.md). 최종 `pubspec.lock`, resolved Android dependencies, `Podfile.lock` 및 실제 IPA/xcarchive 내부를 함께 보존한다. [Maps Android 수집 안내](https://developers.google.com/maps/documentation/android-sdk/play-data-disclosure), [Maps iOS 개인정보 안내](https://developers.google.com/maps/documentation/ios-sdk/apple-privacy-policy)

원격 설치 원본 Maps9.4.0 manifest에서 확인한 App Privacy 보조 입력은 다음과 같다. 이 표는 공급자 선언이며 MAP 자체 계정·채팅·위치 수집을 제외하는 근거가 아니다. 전체 앱의 추적·공유·보관 답변은 위 표의 미완 조건을 유지한다.

| Google iOS SDK 선언 유형 | 사용자 연결 | 목적 | 해당 유형 tracking 선언 |
| --- | --- | --- | --- |
| Device ID | 예 | Analytics, App Functionality | 아니오 |
| Other Data Types | 예 | Analytics | 아니오 |
| Crash Data / Performance Data / Product Interaction | 아니오 | Analytics | 아니오 |

Required Reason API는 vendor 원본의 DiskSpace(85F4.1/E174.1), FileTimestamp(C617.1), SystemBootTime(35F9.1), UserDefaults(1C8F.1/CA92.1)를 그대로 검증한다. 이 vendor 이유 코드를 MAP의 별도 사용 이유로 복사하지 않는다.

Apple의 지정 SDK 목록에는 Flutter, geolocator_apple, image_picker_ios 등이 포함된다. 최종 배포물의 해당 SDK 및 재포장·전이 의존성에 대한 privacy manifest, 필요한 서명, Required Reason API 사용 이유를 확인한다. 빈 `PrivacyInfo.xcprivacy`나 타 SDK의 이유 코드를 복사해 검사를 통과시켜서는 안 된다. 선언은 실제 호출·사용 목적과 일치해야 한다. [Apple SDK 요구사항](https://developer.apple.com/support/third-party-SDK-requirements/)

native 담당자 인계 검사:

1. 최종 SHA·archive/AAB/IPA digest와 test/prod 환경·bundle/package·인증서 대응을 고정한다.
2. iOS 앱과 각 framework/bundle의 `PrivacyInfo.xcprivacy`를 열어 수집·tracking domains·Required Reason API와 Xcode privacy report를 대조한다. manifest 존재만을 수집 선언 완성으로 취급하지 않는다.
3. Android 최종 의존성/manifest의 권한·map SDK·인식 제공자와 실제 트래픽에서 데이터 항목만 확인한다. 원문 이미지·위치·토큰을 증거에 남기지 않는다.
4. 계정/권한 거부, AI 거부, 위치 선택 해제, 동의 철회, 계정 전환의 payload 차이를 합성 자료로 확인한다. 이미 유료 검증한 추천·Vision을 재확인 목적으로 반복하지 않는다.
5. Android 16 KB 정렬과 `libapp.so` GNU_RELRO는 독립 판정이다. 기존 산출물의 정렬 PASS로 RELRO 부재를 지우지 않는다.

## 6. 보관·삭제·정책 불일치 미완

다음은 소스 정책과 기존 root 근거에 기술된 상태다. 이번 문서 작업에서 서버·DB를 변경하거나 삭제 실행하지 않았다.

| 항목 | 현재 기술된 기준 | 출시 전 필요한 검증 |
| --- | --- | --- |
| 회원·일정·작업·본인 채팅 | 탈퇴 시 서비스 데이터 삭제, 다른 참여자 메시지 보존, 소유 방 종료 | 일반/Apple 계정 성공·revoke 실패 경로, 연관 행·캐시 정리와 권한 차단 |
| 채팅 | 여행 종료 후 7일은 읽기 전용 전환 | 7일 후 메시지 삭제로 잘못 안내하지 않음 |
| 신고 | 완료 후 90일 상세·참조 제거, 365일 메타데이터 삭제; 탈퇴 시 관련 상세 제거 | scheduler 실제 실행·UTC 기준·재시도와 삭제 결과; 테스트 파일 존재는 실행 근거가 아님 |
| 백업 | 확인된 미국 원격 백업은 자동 만료 미설정 | 실제 보존 기간·자동 만료·복원 시 삭제 재적용을 root가 구현·검증한 뒤 정책 변경 |
| 보안·문의 기록 | 일괄 파기 기한 미확정 | 항목별 필요 기간·접근·삭제·예외 고지 확정 |
| Gemini | 안전성 목적 55일 공급자 보관 | MAP 탈퇴가 공급자 자료 즉시 삭제를 보장하지 않음. 사용자 문의 처리 계약 확인 |
| 위치 이용/제공사실 자료 | 기록 항목·기간·열람/파기 체계 정식 검증 미완 | 위치정보법 제19조상 약관 주소·연락처, 기록 근거·기간 등 실제 충족 |
| 국외 이전 | 미국 백업 확인; Gemini 처리 국가 범위·법인·연락처·근거·거부 절차 미확정 | 구체 고지·적법한 처리 근거와 기능별 동의 UI 정합성 검토 |
| 공개 정책 | HTTP 200이어도 소스와 본문 불일치, 지원/삭제 fallback 가능성 | 공개 본문·링크·버전·주소를 root가 실제 확인 후 콘솔 URL 확정 |

## 7. 이 자료에서 실제 확인한 것

`graphify` AST 인덱스와 query로 개인정보·권한·동의·신고 경로를 좁힌 뒤 위 Client 소스를 읽었다. 법·스토어·공급자 공식 문서를 2026-09-07에 대조했다. HTML과 Markdown 로컬 구조/링크 검사는 별도 실행 기록으로 남긴다. 새 paid AI 호출, 계정 생성, 메일·초대 전송, 앱 빌드·설치, 공개 배포, DB 변경, 콘솔 제출은 이 자료 작업의 실행 결과에 포함되지 않는다.
