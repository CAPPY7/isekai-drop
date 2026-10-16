# Third-party notices

Only permissive licences (Apache 2.0, MIT, BSD or similar) are allowed.

## Shipped inside the app
| Component | Version | Licence |
|---|---|---|
| Flutter SDK and engine (includes Skia/Impeller, Dart runtime) | 3.47.7 / Dart 3.13.5 | BSD-3-Clause (engine includes further permissive notices, shown by Flutter's built-in licence page) |
| Material Icons (via `uses-material-design`) | bundled with Flutter | Apache 2.0 |
| shared_preferences (+ _android, _foundation, _linux, _windows, _web, _platform_interface) | 2.5.6 | BSD-3-Clause |
| file_selector (+ _android, _ios, _linux, _macos, _windows, _web, _platform_interface) | 1.1.0 | BSD-3-Clause (file_selector_android also lists Apache 2.0) |
| desktop_drop | 0.8.0 | Apache 2.0 |
| universal_platform | 1.1.0 | MIT |
| cross_file, path, path_provider_linux/_windows/_platform_interface, xdg_directories, plugin_platform_interface, platform, file, ffi, async, collection, characters, meta, vector_math, web, http, http_parser, typed_data, source_span, string_scanner, term_glyph, flutter_web_plugins | latest resolved in pubspec.lock | BSD-3-Clause |
| material_color_utilities | 0.13.0 | Apache 2.0 |

Licence check: run on 16 Oct 2026 against pub.dev licence tags for every
package in `flutter pub deps --no-dev`. No GPL/AGPL/MPL packages.
`file_picker` was tried and rejected because its Linux part pulls in `dbus`
(MPL-2.0, not permissive).

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
