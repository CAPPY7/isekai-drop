// E2 (0.12.1): screen texts. `tr(context)` gives the texts for the chosen
// language; English when none is set up (for example a bare MaterialApp in
// tests). Hindi and Kannada texts are assistant translations that still
// need a native-speaker check (see the "@@x-review" note in their .arb).
import 'package:flutter/widgets.dart';

import 'app_localizations.dart';
import 'app_localizations_en.dart';

export 'app_localizations.dart';

final AppLocalizations _english = AppLocalizationsEn();

AppLocalizations tr(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations) ?? _english;

/// Language choices in Settings ("system" follows the phone/PC).
const kLanguageCodes = ['system', 'en', 'hi', 'kn'];

/// Each language's name in its own script (not translated).
const kLanguageNames = {
  'en': 'English',
  'hi': 'हिन्दी (Hindi)',
  'kn': 'ಕನ್ನಡ (Kannada)',
};

/// E1 text errors in the chosen language (engine reasons, see
/// explainTextError for the English source).
String textErrorText(AppLocalizations l, String reason) => switch (reason) {
  'empty' => l.textErrEmpty,
  'too_long' => l.textErrTooLong,
  'declined' => l.textErrDeclined,
  'old_peer' => l.textErrOldPeer,
  'no_address' => l.textErrNoAddress,
  'not_trusted' => l.textErrNotTrusted,
  'expired' => l.textErrExpired,
  _ => l.textErrFailed,
};
