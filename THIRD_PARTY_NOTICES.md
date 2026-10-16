# Third-party notices

Only permissive licences (Apache 2.0, MIT, BSD or similar) are allowed.

## Shipped inside the app
| Component | Version | Licence |
|---|---|---|
| Flutter SDK and engine (includes Skia/Impeller, Dart runtime) | 3.47.7 / Dart 3.13.5 | BSD-3-Clause (engine includes further permissive notices, shown by Flutter's built-in licence page) |
| Material Icons (via `uses-material-design`) | bundled with Flutter | Apache 2.0 |

## Used only to build/test (not shipped)
| Component | Version | Licence |
|---|---|---|
| flutter_test | SDK | BSD-3-Clause |
| flutter_lints | 6.0.0 | BSD-3-Clause |
| flutter_launcher_icons | 0.14.4 | MIT |

## Build tools (GitHub Actions)
actions/checkout, actions/setup-java, actions/upload-artifact,
actions/download-artifact (MIT); subosito/flutter-action (MIT);
softprops/action-gh-release (MIT).
