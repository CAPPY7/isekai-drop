# Tech choice: which toolkit builds the one shared app?

Checked on 16 Oct 2026 against current official docs. A "toolkit" (framework)
is the set of building blocks used to write the app once and run it on many
devices.

## What we need
One shared screen design (UI) for **Android, iPhone/iPad, Windows, macOS and
Linux**, built for free on GitHub Actions, with small native add-ons where a
platform requires them.

## The options

| Option | Android | iOS | Windows | macOS | Linux | Notes |
|---|---|---|---|---|---|---|
| **Flutter 3.47.7 (Dart)** | Stable | Stable | Stable | Stable | Stable | All 5 official in one project. Docs: docs.flutter.dev/reference/supported-platforms |
| Compose Multiplatform (Kotlin) | Stable | Stable | Stable (JVM) | Stable (JVM) | Stable (JVM) | Desktop runs on a bundled Java runtime (bigger, slower start). Docs: kotlinlang.org/docs/multiplatform/supported-platforms.html |
| React Native | Stable | Stable | Separate Microsoft project | Separate Microsoft project | No official support | Fails the Linux requirement. Docs: reactnative.dev/docs/out-of-tree-platforms |
| .NET MAUI | Stable | Stable | Stable | Stable (Mac Catalyst) | No official support | Fails the Linux requirement. |

## Recommendation: Flutter (same as the specification)
1. It is the only option where all five platforms are official, in one project,
   compiled to native machine code (no Java or browser engine at run time).
2. Its own drawing engine makes the premium dark design look the same everywhere.
3. Dart (Flutter's language) can do fast file and network work (sockets, TLS,
   streaming), and Flutter has a standard way to call native code where needed.
4. Free builds for every platform on GitHub Actions are well proven.

Because this matches the specification's direction and costs nothing, no
decision is needed from you here.

## Versions verified today
- Flutter **3.47.7** stable (released 8 Oct 2026), Dart **3.13.5**.
- Java 17 (Temurin) for Android builds.
- GitHub Actions: `actions/checkout@v7.0.1`, `actions/setup-java@v6.1.0`,
  `subosito/flutter-action@v2.23.0`, `actions/upload-artifact@v7.0.2`,
  `actions/download-artifact@v8.0.2`, `softprops/action-gh-release@v3.0.3`.
- Lints: `flutter_lints` 6.0.0. Icons: `flutter_launcher_icons` 0.14.4.
