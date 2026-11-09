# 합체전서

**Persona 3 Reload · Persona 4 Golden · Persona 5 Royal · Shin Megami Tensei V Vengeance**의 악마/페르소나 전서와 합체 레시피를 확인하는 Android 앱입니다. 공략·스토리 현황판에서 전서와 조합 계산에 집중하는 앱으로 전환했습니다.

## 사용하는 흐름

1. 작품을 선택하고 한국어·영문 이름 또는 종족/아르카나로 검색합니다.
2. 만들 대상을 열어 일반·특수 합체 레시피를 확인합니다. 재료를 누르면 그 재료의 만드는 법으로 이동합니다.
3. 직접 등록한 전서 재료만 사용하거나 재료 기본 레벨의 상한으로 조합을 좁힙니다.
4. 만들고 싶은 대상을 **합체 목표 저장**으로 모아두고, 등록 표시는 작품별 **내 전서**에서 관리합니다.
5. 이미 가진 두 재료의 결과는 **합체 계산**에서 바로 확인합니다. P4 Golden에는 3신 합체 입력도 있습니다.

AI·API 키·로그인·서버 연결 없이 오프라인으로 작동합니다. 실제 게임과 등록 상태를 자동 연동하지 않습니다. 외부 원본 확인 링크는 별도 브라우저에서 엽니다.

## 지원 범위

| 작품 | 수록 전서 항목 | 계산 |
| --- | ---: | --- |
| Persona 3 Reload | 194 | 일반 2신·고정 특수 합체 |
| Persona 4 Golden | 205 | 일반 2신·일반 3신·고정 특수 합체 |
| Persona 5 Royal | 232 | 일반 2신·보마·고정 특수 합체 |
| Shin Megami Tensei V Vengeance | 275 | 일반 2신·정령 생성/랭크 조정·고정 특수 합체 |

합계 906개는 DLC를 모두 포함한 스냅샷 기준이며 현재 DLC 설정에서 제외된 항목은 일반 목록에 나오지 않습니다. 플레이어 동료 전용 페르소나, 게스트 인간·프로토 피엔드 에센스 등 소환 가능한 악마전서가 아닌 항목은 제외합니다. P4 Golden의 세계 아르카나와 12재료 특수 합체는 포함합니다. 일반판/FES/Portable/Episode Aigis나 SMT V 원판을 독립 지원 작품으로 섞지 않습니다.

페르소나 4 리메이크와 페르소나 6는 현재 추가하지 않습니다. 실제 데이터가 공개되면 별도 작품으로 등록하고 해당 버전의 합체 규칙을 검증한 뒤 확장합니다.

### 정확한 결과를 위한 설정

- **DLC:** 실제 설치·적용한 팩에 맞춰 설정합니다. DLC가 레벨 구간에 끼어들어 일반 합체 결과도 달라집니다. P3 Reload와 Vengeance 신규 DLC는 기본 제외, Royal은 원본 도구처럼 전체 포함입니다. P3R에서 동일 팩의 페르소나는 함께 설정하며 원본의 Persona 4 Set/Set 1 표기 차이는 하나로 묶었습니다.
- **P4G 3신:** 현재 레벨과 아르카나 우선순위로 높은 재료를 정합니다. 결과 평균에는 기본 레벨을 사용합니다. 역검색은 기본 레벨 기준이고, 육성 재료는 합체 계산에 현재 레벨을 입력합니다.
- **P5R 보마:** 일반 페르소나의 현재 레벨을 입력할 수 있습니다. 역검색 카드의 기본 레벨 조합과 달라질 수 있습니다.
- **해금:** 퀘스트·커뮤/코옵·회차 조건은 상세 화면에서 펼쳐 확인합니다. 조건 원문은 영어가 남아 있을 수 있습니다. 해금과 DLC는 다른 조건이며 앱은 게임의 실제 해금 상태를 판정하지 않습니다.
- **제외:** 합체 경보·사고 예측, 스킬 계승 최적화, 주인공 레벨·소환 비용·이벤트 판정은 제공하지 않습니다. 명시적으로 합체 사고 전용인 항목을 일반 결과로 제시하지 않습니다.

3신 역검색은 백그라운드에서 실행하고 우선 최대 100개를 찾습니다. 더 찾기와 등록 재료·레벨 필터로 범위를 조절합니다. 전체 조합 수를 계산하지 않은 상태에서 전체 검색 결과라고 표시하지 않습니다. 원본에서 빠진 SMT 종족 명칭과 아귀(Preta)는 한국어 용어표로 보완했습니다. 나머지 한국어 이름이 원본에 없으면 영문으로 표시하며 영문 ID도 함께 검색할 수 있습니다.

## 데이터 출처

사용자가 지정한 [aqiu384/megaten-database](https://github.com/aqiu384/megaten-database)는 게임 데이터 추출·자료 저장소입니다. 인증해서 호출하는 웹 API가 아닙니다. 연결된 [megaten-fusion-tool](https://github.com/aqiu384/megaten-fusion-tool)이 제공하는 정리된 JSON과 공개 합체 계산 규칙을 앱에 포함합니다.

- 합체 도구의 **Unlicense**를 `assets/megaten/UNLICENSE.txt`와 앱의 라이선스 화면에 포함했습니다.
- 원본 커밋·사용한 파일의 SHA-256·정규화 내용은 `assets/megaten/provenance.json`에 기록했습니다.
- 각 작품 JSON에 영문 ID, 원본 한국어 이름, 기초 능력치·내성·습득 스킬, 조건, 일반/특수/정령/보마 표를 보관합니다.
- 원본의 일반적인 합체 규칙을 Dart로 옮겼습니다. 모르는 표 항목이나 없는 레시피를 AI나 추측으로 채우지 않습니다.
- 데이터는 실행 중 갱신하지 않고 검토한 앱 업데이트로 제공합니다. 공식 게임 이미지·로고는 수록하지 않았으며 새 아이콘은 별도로 제작한 카드·전서 디자인입니다.

재생성 방법:

```sh
python3 tools/import_megaten.py --source /path/to/megaten-fusion-tool
# Node 24 이상: 원본 TypeScript 계산 함수를 직접 실행해 검증 자료 재생성
node tools/reference_fusions.cjs /path/to/megaten-fusion-tool
```

검증 자료는 원본 함수를 Node의 TypeScript 변환 기능으로 실행해 생성합니다. 일반 2신의 DLC 미포함·전체 포함·일부 포함 조합과 정령/보마 경계, P4G 기본·육성 레벨 3신을 Dart 결과와 비교합니다. 테스트 자료는 APK에 포함하지 않습니다.

## 설치·기록 보존

[최신 APK](https://github.com/ChoiSangJin/AI-Companion-App-for-Nintendo-Switch-JRPGs-Turn-based-Games/releases/latest)의 `app-arm64-v8a-release.apk`를 설치합니다. Android 7.0 이상 ARM64 기기용입니다.

기존 앱과 같은 application ID(`com.choisangjin.switchcompanion`)·서명을 유지하는 **3.0.0+9 / versionCode 2009** 업데이트입니다. 기존 앱 위에 설치하며 삭제할 필요가 없습니다.

- 새 기록은 `fusion.compendium.v1`에 작품별 전서 등록·합체 목표·DLC 상태로 저장합니다.
- 기존 `paldea.planner.v1`과 `companion.v1`은 읽기만 하고 수정·삭제하지 않습니다. 보관함의 기존 포켓몬 이름표에는 PokéAPI 라이선스를 함께 보존합니다. 설정의 이전 버전 보관함에서 읽거나 원본 백업을 복사할 수 있습니다.
- 새 전서는 기존 포켓몬 파티나 AI 공략을 자동으로 가져오지 않습니다. 이전 API 키를 읽거나 전송하지 않습니다.
- 설정에서 네 작품 전체를 백업·복원할 수 있습니다. 잘못된 백업·저장 실패 시 기존 상태를 유지하며, 손상된 현재 기록을 빈 기록으로 덮어쓰지 않습니다.
- DLC를 꺼도 해당 항목의 등록·목표는 유지하고 현재 조건에서 제외됐다고 표시합니다.

## 개발·출시 검증

```sh
flutter pub get
dart format lib test
flutter analyze
flutter test
dart run flutter_launcher_icons

# 안전하게 바인딩한 기존 서명 환경 사용:
# ANDROID_KEYSTORE_PATH, ANDROID_STORE_PASSWORD,
# ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

CI는 포맷·분석·테스트·Android 빌드를 확인합니다. 테스트에는 원본 계산 대조, 잘못된 추가 결과 방지, 특수·DLC·등록 필터, 현재 레벨, 작품별 저장, 동시 작업과 저장 실패, 백업 복원, 이전 기록 보존, 작은 화면·큰 글씨·키보드와 실제 UI 흐름이 포함됩니다.

서명 자료가 Actions에 바인딩된 환경에서는 `release.yml`을 사용합니다. 현재 배포는 로컬에서 서명한 공개 APK만 임시 `deploy-artifacts/v3.0.0` 브랜치에 올리고 `publish-signed-apk.yml`으로 서명·패키지·버전·이름·아이콘·ARM64·인터넷 권한 부재·체크섬을 재검증해 게시합니다. 배포된 파일을 다시 내려받아 원본과 비교한 뒤 임시 브랜치를 정리합니다. 비밀 키는 브랜치나 저장소에 넣지 않습니다.

독립 제작 비공식 도구이며 ATLUS·SEGA와 제휴하지 않았습니다. 게임명과 캐릭터 이름의 권리는 각 권리자에게 있습니다.
