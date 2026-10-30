# 팔데아 플래너

포켓몬스터 스칼렛·바이올렛 본편을 위한 **오프라인 개인 공략 현황판**입니다. 키울 파티와 다음 진화 조건, 진행할 목표와 개인 할 일을 한곳에 모읍니다. AI·API 키·로그인·서버 없이 시작합니다.

## v2.0.0에서 바뀐 점

- 앱 이름·아이콘·화면을 팔데아 전용으로 새로 구성했습니다. 밝은 필드 노트 디자인과 스칼렛·바이올렛 테마를 사용합니다.
- Gemini 호출·모델 설정·웹뷰·기존 AI 의존성을 제거했습니다. Android 릴리스에는 인터넷 권한이 없으며 외부 상세 자료만 별도 브라우저에서 엽니다.
- **내 현황판:** 다음 진행 목표, 6마리 파티의 포획·진화 다음 단계, 개인 할 일을 표시합니다.
- **파티 찾기:** 한국어·영문 이름, 진화형, 타입, 전국도감 번호로 선별 카드를 찾고 고정합니다. 첫 파트너에 맞는 스토리용 편성 예시, 시기·버전 전용 필터를 제공합니다.
- **진행 루트:** 체육관 8·주인 5·스타단 5를 레벨 기준으로 섞은 추천 순서입니다. 직접 체크·되돌리기·완료 숨기기·준비할 일 고정이 가능합니다.
- 18타입 상성 계산은 이중 타입·4배 약점·무효를 반영합니다. 테라스탈 후 방어 타입은 직접 선택하고 특성·도구·기술 예외는 계산하지 않습니다.
- 파티 메모, 수동 할 일, 완료한 할 일, 전체 JSON 백업·복원을 제공합니다. 게임과 진행도를 자동 연동하지 않습니다.

## 수록 범위

본편 스토리용 **24개 육성 경로**를 두 버전에 걸쳐 선별했습니다. 버전 전용을 제외하면 각 버전의 후보 수는 더 적으며, 선택하지 않은 첫 파트너는 추천 목록에서 제외됩니다. 전체 400종 도감·상세 지도·대전 최적화·DLC·HOME·교환 공략을 제공하는 버전이 아닙니다.

빠모트의 1,000보, 저승갓숭의 분노의주먹 20회, 버전별 카르본 진화 아이템 등 특수 조건을 카드에 표시합니다. 파티에 넣으면 포획 전 상태로 시작하고, 선택한 첫 파트너는 입수 완료로 시작합니다. 체크는 실제 게임 진행에 맞춰 직접 해야 합니다. 상세 카드에서 이전 단계로 되돌리거나 파티에서 제외할 수 있습니다.

출현 위치는 간략한 탐색 힌트입니다. 정확한 서식 범위·출현율·기술은 게임 도감과 카드의 Serebii 상세 자료를 확인하세요. 추천 파티는 편성 예시이며 유일한 정답이 아닙니다. 18개 주요 목표 이후의 이야기 결말은 표시하지 않습니다.

## 설치와 기존 사용자

[최신 APK 릴리스](https://github.com/ChoiSangJin/AI-Companion-App-for-Nintendo-Switch-JRPGs-Turn-based-Games/releases/latest)에서 `app-arm64-v8a-release.apk`를 설치합니다. Android 7.0 이상 ARM64 기기 대상입니다.

기존 앱과 동일한 application ID(`com.choisangjin.switchcompanion`)와 서명을 사용하므로 기존 앱 위에 업데이트합니다. 앱을 삭제할 필요가 없습니다.

- 새 기록: SharedPreferences의 `paldea.planner.v1`에 스칼렛·바이올렛 프로필을 따로 저장합니다.
- 이전 기록: `companion.v1`을 수정·삭제하지 않습니다. 설정의 **이전 앱 기록 열람**에서 게임·목표·공략을 읽거나 원본을 복사할 수 있습니다. 새 파티로 자동 변환하지 않습니다.
- 기존 API 키를 읽거나 전송하지 않습니다. 새 앱에 API 키 입력 화면이나 Google 요청 코드가 없습니다.
- 새 기록이 손상되면 빈 기록으로 덮어쓰지 않고 복구 안내 화면을 표시합니다. 이전 기록이 손상된 경우 새 플래너 사용을 막지 않습니다.
- 앱 삭제·기기 변경 전 **기록·앱 안내 → 전체 기록 백업**으로 JSON을 따로 보관하세요. 복원은 확인 후 두 프로필을 교체하며, 검증·저장 실패 시 현재 기록을 유지합니다.

## 데이터 출처와 유지보수

`assets/data/paldea.json`은 앱에 포함된 고정 스냅샷입니다. 실행 중 API를 호출하거나 업데이트하지 않습니다.

- 한국어 이름·폼별 타입·기초 진화 조건·18타입 상성: [PokéAPI 공개 CSV](https://github.com/PokeAPI/pokeapi/tree/master/data/v2/csv). 데이터 라이선스는 앱과 `assets/data/POKEAPI-LICENSE.txt`에 포함했습니다.
- 출현 힌트·파티 예시·진행 순서·준비 팁: 직접 편집한 본편 공략 카드입니다. PokéAPI가 추천 공략을 제공하는 것으로 표시하지 않습니다.
- 외부 상세 참고: 카드별 Serebii 도감과 [체육관](https://www.serebii.net/scarletviolet/gyms.shtml), [주인](https://www.serebii.net/scarletviolet/titanpokemon.shtml), [스타단](https://www.serebii.net/scarletviolet/teamstar.shtml) 자료.
- 기준 날짜·원본 다운로드 체크섬은 `assets/data/provenance.json`에 기록합니다. 포켓몬 이미지·로고는 배포하지 않으며 앱 아이콘은 별도로 제작한 노트·경로 디자인입니다.

로컬에 PokéAPI의 `LICENSE.md`와 `data/v2/csv` 중 아래 파일을 준비한 뒤 재생성·대조할 수 있습니다.

```sh
python3 tools/build_paldea_catalog.py --source-dir /path/to/pokeapi-csv
python3 tools/verify_paldea_data.py --source-dir /path/to/pokeapi-csv
```

필요한 CSV: `pokemon_species_names.csv`, `pokemon_types.csv`, `type_efficacy.csv`. 검증에는 `pokemon_evolution.csv`도 필요합니다. 이름·폼 타입·레벨 진화 조건과 진행 항목 수·정렬을 대조합니다. 출현 힌트·편성 예시는 별도 편집 검토가 필요합니다.

## 개발과 검증

Flutter stable / Dart 3.10 이상, Android SDK와 JDK를 사용합니다.

```sh
flutter pub get

dart format lib test
flutter analyze
flutter test

dart run flutter_launcher_icons
```

테스트는 버전별 저장·진화 되돌리기·6마리 제한·버전 전용 제한·할 일 중복 방지·연속 저장과 버전 전환·실패 시 상태 유지·백업 복원·이전 기록 보존·작은 화면과 큰 글씨·타입 상성을 다룹니다. 출시 전에는 서명·버전 코드·패키지·아이콘·ARM64 구성·인터넷 권한 부재를 확인합니다.

## 서명과 배포

업데이트에는 기존 키스토어를 유지해야 합니다. 비밀 자료를 저장소에 넣지 않습니다.

```sh
# 환경에 안전하게 바인딩한 서명 설정 사용
# ANDROID_KEYSTORE_PATH, ANDROID_STORE_PASSWORD,
# ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

CI는 포맷·정적 분석·테스트·Android 빌드를 실행합니다. 서명 비밀이 Actions에 등록된 환경에서는 `release.yml`을 사용할 수 있습니다. 현재 배포는 로컬에서 서명한 공개 APK를 임시 `deploy-artifacts/v2.0.0` 브랜치에 준비하고 `publish-signed-apk.yml`으로 체크섬·서명·패키지·버전·ARM64 구성을 재검증해 게시합니다. 비밀 키는 임시 브랜치에 포함하지 않으며 배포 후 그 브랜치를 정리합니다.

현재 버전은 `2.0.0+8`이며 ARM64 APK의 versionCode는 `2008`입니다. 이름 변경 후에도 application ID와 서명 인증서는 유지합니다.

독립 제작 비공식 팬 도구이며 Nintendo·Game Freak·The Pokémon Company와 제휴하지 않았습니다. Pokémon 및 캐릭터 이름의 권리는 각 권리자에게 있습니다.
