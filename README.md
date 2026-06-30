# mixhouse.ma

Mixhouse Flutter application for Android, iPhone, iPad, desktop, and web.

## Build

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk
```

The production API defaults to `https://mixhouse.ma/api`. Override it when needed:

```bash
flutter run --dart-define=API_URL=http://localhost:8000/api
```

## Codemagic iOS

Connect this repository in Codemagic, select the Flutter workflow, configure Apple signing, then build the `ios` target.
