# Third-party notices

Only permissive licences (Apache 2.0, MIT, BSD or similar) are allowed.

## Shipped inside the app
| Component | Version | Licence |
|---|---|---|
| Flutter SDK and engine (includes Skia/Impeller, Dart runtime, BoringSSL used for TLS) | 3.47.7 / Dart 3.13.5 | BSD-3-Clause (engine includes further permissive notices, shown by Flutter's built-in licence page) |
| Material Icons (via `uses-material-design`) | bundled with Flutter | Apache 2.0 |
| archive | 4.5.2 | MIT |
| args | 2.7.0 | BSD-3-Clause |
| async | 2.13.1 | BSD-3-Clause |
| basic_utils | 5.8.2 | MIT |
| characters | 1.4.1 | BSD-3-Clause |
| code_assets | 1.2.1 | BSD-3-Clause |
| collection | 1.19.1 | BSD-3-Clause |
| convert | 3.1.2 | BSD-3-Clause |
| cross_file | 0.3.5+5 | BSD-3-Clause |
| crypto | 3.0.7 | BSD-3-Clause |
| desktop_drop | 0.8.0 | Apache-2.0 |
| ffi | 2.2.0 | BSD-3-Clause |
| ffi_leak_tracker | 0.1.2 | BSD-3-Clause |
| file | 7.0.1 | BSD-3-Clause |
| file_selector | 1.1.0 | BSD-3-Clause |
| file_selector_android | 0.5.2+11 | Apache-2.0 |
| file_selector_ios | 0.5.3+6 | BSD-3-Clause |
| file_selector_linux | 0.9.4+1 | BSD-3-Clause |
| file_selector_macos | 0.9.5+1 | BSD-3-Clause |
| file_selector_platform_interface | 2.7.0 | BSD-3-Clause |
| file_selector_web | 0.9.5 | BSD-3-Clause |
| file_selector_windows | 0.9.3+6 | BSD-3-Clause |
| flutter_secure_storage | 11.2.0 | BSD-3-Clause |
| flutter_secure_storage_darwin | 0.4.3 | BSD-3-Clause |
| flutter_secure_storage_linux | 3.0.3 | BSD-3-Clause |
| flutter_secure_storage_platform_interface | 2.1.1 | BSD-3-Clause |
| flutter_secure_storage_web | 2.1.1 | BSD-3-Clause |
| flutter_secure_storage_windows | 4.2.2 | BSD-3-Clause |
| hooks | 2.0.2 | BSD-3-Clause |
| http | 1.6.0 | BSD-3-Clause |
| http_parser | 4.1.2 | BSD-3-Clause |
| jni | 1.1.0 | BSD-3-Clause |
| jni_flutter | 1.0.4+1 | BSD-3-Clause |
| jni_util | 1.0.0 | BSD-3-Clause |
| json_annotation | 4.12.0 | BSD-3-Clause |
| logging | 1.3.0 | BSD-3-Clause |
| material_color_utilities | 0.13.0 | Apache-2.0 |
| meta | 1.18.3 | BSD-3-Clause |
| mobile_scanner | 7.4.2 | BSD-3-Clause |
| multicast_dns | 0.3.3+1 | BSD-3-Clause |
| objective_c | 9.5.0 | BSD-3-Clause |
| package_config | 3.0.0 | BSD-3-Clause |
| path | 1.9.1 | BSD-3-Clause |
| path_provider | 2.1.6 | BSD-3-Clause |
| path_provider_android | 2.3.1 | BSD-3-Clause |
| path_provider_foundation | 2.6.0 | BSD-3-Clause |
| path_provider_linux | 2.2.2 | BSD-3-Clause |
| path_provider_platform_interface | 2.1.3 | BSD-3-Clause |
| path_provider_windows | 2.3.0 | BSD-3-Clause |
| platform | 3.2.0 | BSD-3-Clause |
| plugin_platform_interface | 2.1.8 | BSD-3-Clause |
| pointycastle | 4.0.0 | MIT |
| posix | 6.5.2 | MIT |
| pub_semver | 2.2.1 | BSD-3-Clause |
| qr | 3.0.2 | BSD-3-Clause |
| qr_flutter | 4.1.0 | BSD-3-Clause |
| record_use | 0.6.0 | BSD-3-Clause |
| shared_preferences | 2.5.6 | BSD-3-Clause |
| shared_preferences_android | 2.4.28 | BSD-3-Clause |
| shared_preferences_foundation | 2.5.7 | BSD-3-Clause |
| shared_preferences_linux | 2.4.1 | BSD-3-Clause |
| shared_preferences_platform_interface | 2.4.2 | BSD-3-Clause |
| shared_preferences_web | 2.4.3 | BSD-3-Clause |
| shared_preferences_windows | 2.4.1 | BSD-3-Clause |
| source_span | 1.10.2 | BSD-3-Clause |
| string_scanner | 1.4.1 | BSD-3-Clause |
| term_glyph | 1.2.2 | BSD-3-Clause |
| typed_data | 1.4.0 | BSD-3-Clause |
| universal_platform | 1.1.0 | MIT |
| vector_math | 2.4.0 | BSD-3-Clause |
| web | 1.1.1 | BSD-3-Clause |
| win32 | 6.4.0 | BSD-3-Clause |
| xdg_directories | 1.1.0 | BSD-3-Clause |
| yaml | 3.1.4 | MIT |
| AndroidX CameraX (camera-camera2, camera-lifecycle, via mobile_scanner, Android) | 1.6.1 | Apache 2.0 |
| kotlinx-coroutines-android (via mobile_scanner, Android) | 1.11.0 | Apache 2.0 |
| **Google ML Kit Barcode Scanning** `com.google.mlkit:barcode-scanning` (bundled model, Android only, via mobile_scanner) | 17.3.0 | **Not open source.** Free to use under the Google APIs Terms of Service and ML Kit Terms (https://developers.google.com/ml-kit/terms). Runs fully on the device; Isekai Drop sends no images. Per Google's ML Kit terms and Play data disclosure (checked 2026-10-16), ML Kit sends usage and performance metrics, device information (maker, model, OS), app package/version and a per-installation identifier to Google over HTTPS when internet is available. Camera images and scan results are NOT sent. The owner accepted this choice. |
| flutter, flutter_web_plugins, sky_engine | Flutter SDK 3.47.7 | BSD-3-Clause (part of the Flutter SDK row above) |
| Apple frameworks (Network/NetService, UIKit) and Android platform APIs (NsdManager, MediaStore, WifiManager) | OS | Part of the operating system, not shipped by us |

Licence check: regenerated 16 Oct 2026 (Phase 7) from `flutter pub deps --no-dev` (77 packages). Each licence was classified from the package's own LICENSE file in the pub cache. Result: only MIT, BSD-2/3-Clause and Apache-2.0. **No GPL / LGPL / AGPL / MPL.**
`file_picker` was rejected in Phase 2 (its Linux part needs `dbus`, MPL-2.0).
Full licence texts are shown in the app (Flutter's built-in licence page).

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

### QR scanning on Apple platforms
On iPhone/iPad and Mac, mobile_scanner uses Apple's built-in Vision and
AVFoundation frameworks (part of the operating system). ML Kit is used only on Android.
