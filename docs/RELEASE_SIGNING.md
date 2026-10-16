# Real release key (prepared, NOT active)

Today every APK is signed with the throwaway **dev** key (fingerprint 5b36eeb0…57c1). Its passwords are in the repo on purpose: anyone with repo access could sign an "Isekai Drop" update. Fine for testing, not for friends and family.

What is ready (Phase 7):
- `android/app/build.gradle.kts` uses a release key **only** when the environment variable `ISEKAI_RELEASE_KEYSTORE` is set. Otherwise it uses the dev key, exactly as before.
- `.github/workflows/android-release.yml` runs **only** when started by hand. It reads 4 secrets, writes the keystore to a temp file, builds, **fails if a secret is missing or the APK is dev-signed**, deletes the keystore, and creates a **draft** release that you publish yourself.
- Checked on the build box with a throwaway key that was deleted afterwards: with the variables set the APK was signed by that key; without them it was signed by the dev key 5b36eeb0…57c1.
- Normal test builds (`android.yml`) never read the secrets.

## IMPORTANT before switching
- Android only installs an update signed with the **same** key. Moving from the dev key to the release key means **everyone must uninstall the test app once** and install the release APK. Received files in Downloads stay, but **pairings and history are lost** (they live inside the app) and devices must pair again.
- If you **lose** the release key or its password, you can never update the app again: everyone would have to uninstall and reinstall. Keep 2 backups (e.g. a USB stick and a password manager).
- Never commit the key. Never paste it into chat.

## Step 1: choose how the key is made (your choice)
**Option A (recommended): you make it yourself on a computer with Java** (any PC; Android Studio includes Java):
1. Open a terminal and run (one line):
   `keytool -genkeypair -v -keystore isekai-release.jks -alias isekai -keyalg RSA -keysize 4096 -validity 10000`
2. Choose a strong password (store password = key password is simplest). Enter your name when asked (it is visible inside the certificate).
3. Save `isekai-release.jks` and the password in 2 safe places.
4. Make the text form: Windows PowerShell `[Convert]::ToBase64String([IO.File]::ReadAllBytes("isekai-release.jks")) | Set-Content key.b64`; macOS/Linux `base64 -w0 isekai-release.jks > key.b64` (macOS: `base64 -i isekai-release.jks -o key.b64`).

**Option B: I generate it on my build box**, give it to you to download as a backup, then delete my copy. Faster, but the key has existed on a machine you don't control, and you have to trust that I deleted it. Only if you say so.

**Option C: keep the dev key** for now (only you and close family, who accept the risk above).

## Step 2: add the 4 secrets (you, in the GitHub website; works on a phone)
Repo > Settings > Secrets and variables > Actions > New repository secret:
1. `ISEKAI_RELEASE_KEYSTORE_B64` = the whole content of key.b64
2. `ISEKAI_RELEASE_STORE_PASSWORD` = the password
3. `ISEKAI_RELEASE_KEY_ALIAS` = `isekai`
4. `ISEKAI_RELEASE_KEY_PASSWORD` = the password
This is a repository settings change. I don't do it: my access token is not meant for it, and you have not approved it.

## Step 3: build
Actions > "Android RELEASE (real key, manual only)" > Run workflow > tag `v0.7.0`. When it is green, open Releases, check the draft, and publish it. Write down the new SHA-256 fingerprint shown in the run log; it replaces 5b36eeb0…57c1 in the install instructions.
