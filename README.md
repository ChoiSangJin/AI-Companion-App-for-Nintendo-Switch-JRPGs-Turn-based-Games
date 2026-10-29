# Switch 공략 컴패니언

Nintendo Switch 1·2 JRPG/턴제 게임용 개인 Android 앱입니다. Flutter Material 3 다크 UI이며 서버·로그인 없이 동작합니다. 게임을 직접 추가하고 규칙을 입력한 뒤, AI 검색 / 공략 변환 / 내 공략집 탭을 사용합니다.

- 게임 선택과 규칙, 공략, 체크 상태는 기기에 JSON으로 저장합니다.
- API 키는 Android 보안 저장소에 저장하며 Android 백업을 비활성화했습니다.
- Gemini 검색에는 Google Search grounding을 사용하며 출처와 검색 제안을 표시합니다. 검색 도구와 responseSchema의 모델별 충돌을 피하기 위해 JSON 프롬프트 및 검증 파서를 사용합니다.
- 공략 붙여넣기는 검색 없이 순서가 있는 체크리스트로 변환하여 자동 저장합니다.
- 저장된 공략은 오프라인에서 조회·검색·수정·삭제하고 완료 항목을 숨길 수 있습니다. 게임은 상단에서 선택하며 길게 누르거나 삭제 버튼으로 게임과 관련 공략을 삭제합니다.
- 프리셋 게임은 없습니다. API 키와 모델은 설정에서 입력합니다. 기본 모델은 `gemini-2.5-flash`이며 사용 가능한 Google 검색 지원 모델로 변경할 수 있습니다.

## 개발

최신 Flutter stable, Java 17, Android SDK가 필요합니다. Android 최소 버전과 타겟은 Flutter stable 기본값을 따릅니다. `android`는 Flutter의 stable Android Kotlin 템플릿 기준입니다 (AGP 9.1.0 / Gradle 9.3.1).

```sh
flutter pub get
# pubspec.lock에 해석된 의존성 버전이 포함되어 있습니다.
dart format lib test
flutter analyze
flutter test
flutter run
```

`lib/models`는 데이터 모델, `lib/services/gemini.dart`는 REST 요청·파서, `lib/services/storage.dart`는 로컬 저장소, `lib/main.dart`는 UI입니다. 테스트에는 영속성, 손상된 데이터 보호, 요청 컨텍스트, JSON 파서, API 오류, 출처 없는 응답 거부와 게임 추가 UI가 포함됩니다.

AI 호출을 제외한 공략집은 네트워크가 필요하지 않습니다. Gemini 키는 앱에서만 입력하며 저장소·CI에 넣지 않습니다. 실제 Gemini API 검증에는 사용자의 유효한 키와 사용량이 필요합니다. 모델 가용성·쿼터·Google 검색 지원은 계정과 모델에 따라 다릅니다.

## Android APK 배포

`.github/workflows/ci.yml`은 PR과 main/기능 브랜치에서 분석·테스트·ARM64 디버그 빌드를 실행합니다. `.github/workflows/release.yml`은 `v*` 태그 또는 수동 실행으로 **릴리즈 키로 서명한 ARM64 APK**와 SHA-256 체크섬을 GitHub Releases에 게시합니다. Play Store 배포는 포함하지 않습니다.

동일한 키를 계속 보관해야 기존 앱을 업데이트할 수 있습니다. 다음 GitHub Actions repository secrets가 필요합니다. 비밀 값은 채팅이나 저장소에 올리지 마세요.

| Secret | 용도 |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | 릴리즈 JKS 파일의 Base64 |
| `ANDROID_STORE_PASSWORD` | JKS 암호 |
| `ANDROID_KEY_ALIAS` | 서명 키 alias |
| `ANDROID_KEY_PASSWORD` | 서명 키 암호 |

기존 키가 없다면 안전한 로컬 디렉터리에서 생성하고 백업합니다 (대화형 암호 입력).

```sh
keytool -genkeypair -keystore release.jks -alias switch-companion \
  -keyalg RSA -keysize 3072 -validity 10000 \
  -dname "CN=Switch Companion"
# GitHub Settings > Secrets and variables > Actions에 위 네 가지를 등록합니다.
# macOS: base64 -i release.jks | pbcopy
# Linux: base64 -w 0 release.jks (출력을 공개 로그에 남기지 마세요)
```

`pubspec.yaml`의 버전과 태그를 일치시켜 배포합니다. 첫 릴리즈는 `v1.0.0`입니다. 수동 실행 시에도 main에 포함된 커밋을 대상으로 선택하세요.

```sh
git tag v1.0.0
git push origin v1.0.0
```

빌드 명령은 `flutter build apk --release --target-platform android-arm64 --split-per-abi`이며 산출물은 `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`입니다. 로컬 릴리즈 빌드에는 `ANDROID_KEYSTORE_PATH` (절대 경로), `ANDROID_STORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`가 필요합니다. 서명 설정 없이 릴리즈 배포를 진행하지 않습니다.

## 데이터와 제한

게임·규칙·검색어·붙여넣은 공략은 요청 시 Google Gemini에 전송되며 사용료가 발생할 수 있습니다. 로컬 API 키는 보안 저장소에 있지만 기기를 완전히 신뢰할 수 없는 환경에서는 노출될 수 있습니다. AI 답변의 정확성이나 스포일러 차단은 보장되지 않습니다. 원문의 스포일러는 직접 제거하고 출처를 확인하세요. `shared_preferences`는 개인용 소규모 공략집 용도이며 대용량 DB나 클라우드 백업을 제공하지 않습니다. 앱 삭제 시 데이터가 사라집니다. 기기 성능에 따른 0.1초 조회 보장은 측정 전에는 주장하지 않습니다.
