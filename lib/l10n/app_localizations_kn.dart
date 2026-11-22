// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Kannada (`kn`).
class AppLocalizationsKn extends AppLocalizations {
  AppLocalizationsKn([String locale = 'kn']) : super(locale);

  @override
  String get aboutApp => 'Isekai Drop ಬಗ್ಗೆ';

  @override
  String aboutSubtitle(String version) {
    return 'Isekai Drop $version - ಬಿಲ್ಡ್, ಕೀಲಿ, ಅಪ್‌ಡೇಟ್, ಪರವಾನಗಿಗಳು';
  }

  @override
  String get aboutThisDevice => 'ಈ ಸಾಧನದ ಬಗ್ಗೆ';

  @override
  String get aboutTitle => 'ಮಾಹಿತಿ';

  @override
  String get accept => 'ಸ್ವೀಕರಿಸಿ';

  @override
  String get addedToQueue =>
      'ಸರತಿಗೆ ಸೇರಿಸಲಾಗಿದೆ. ಈಗಿನ ಕಳುಹಿಸುವಿಕೆ ಮುಗಿದಾಗ ಪ್ರಾರಂಭವಾಗುತ್ತದೆ.';

  @override
  String get advanced => 'ಸುಧಾರಿತ';

  @override
  String andMore(String count) {
    return '...ಮತ್ತು ಇನ್ನೂ $count';
  }

  @override
  String get anyFilesIos =>
      'ಯಾವುದೇ ಬಗೆಯ ಫೈಲ್‌ಗಳು. iPhone/iPad ನಲ್ಲಿ ಇನ್ನೂ ಫೋಲ್ಡರ್ ಆರಿಸಲು ಆಗುವುದಿಲ್ಲ - ಒಳಗಿನ ಫೈಲ್‌ಗಳನ್ನು ಆರಿಸಿ.';

  @override
  String get anyFilesOrFolder =>
      'ಯಾವುದೇ ಬಗೆಯ ಫೈಲ್‌ಗಳು, ಅಥವಾ ಇಡೀ ಫೋಲ್ಡರ್ (ಒಳಗಿನ ಫೋಲ್ಡರ್‌ಗಳೂ ಉಳಿಯುತ್ತವೆ).';

  @override
  String get appTitle => 'Isekai Drop';

  @override
  String appVersion(String version) {
    return 'Isekai Drop $version';
  }

  @override
  String get appearance => 'ನೋಟ';

  @override
  String get askAlwaysAllow => 'ಈ ಸಾಧನಕ್ಕೆ ಯಾವಾಗಲೂ ಅನುಮತಿಸಿ';

  @override
  String get askAlwaysAllowHelp =>
      'ಇದರಿಂದ ಫೈಲ್‌ಗಳು ಈ ಪ್ರಶ್ನೆ ಇಲ್ಲದೆ ಬರುತ್ತವೆ. ಸೆಟ್ಟಿಂಗ್‌ಗಳು > ವಿಶ್ವಾಸಾರ್ಹ ಸಾಧನಗಳು ಇಲ್ಲಿ ಆಫ್ ಮಾಡಿ.';

  @override
  String get askCodeCheck =>
      'ಐಚ್ಛಿಕ ಪರಿಶೀಲನೆ: ಇನ್ನೊಂದು ಪರದೆಯಲ್ಲೂ ಇದೇ ಕೋಡ್ ಕಾಣಿಸುತ್ತದೆ';

  @override
  String askFilesTitle(String name) {
    return '$name ನಿಮಗೆ ಫೈಲ್‌ಗಳನ್ನು ಕಳುಹಿಸಲು ಬಯಸುತ್ತದೆ';
  }

  @override
  String askFromTrusted(String platform, String name) {
    return 'ವಿಶ್ವಾಸಾರ್ಹ $platform ಸಾಧನ \"$name\" ಇಂದ.';
  }

  @override
  String get askKeyWarning =>
      'ಎಚ್ಚರಿಕೆ: ಈ ಐಡಿ ಇರುವ ಸಾಧನವನ್ನು ಮೊದಲು ಬೇರೆ ಕೀಲಿಯೊಂದಿಗೆ ಜೋಡಿಸಲಾಗಿತ್ತು. ನೀವು ಅದರಲ್ಲಿ Isekai Drop ಮರುಸ್ಥಾಪಿಸಿದ್ದರೆ ಅಥವಾ ರೀಸೆಟ್ ಮಾಡಿದ್ದರೆ ಮಾತ್ರ ಸ್ವೀಕರಿಸಿ. ಸ್ವೀಕರಿಸಿದರೆ ಹಳೆಯ ಕೀಲಿ ಬದಲಾಗುತ್ತದೆ.';

  @override
  String askPairConnect(String platform, String name) {
    return '$platform ಸಾಧನ \"$name\" ಸಂಪರ್ಕಿಸಲು ಬಯಸುತ್ತದೆ.';
  }

  @override
  String get askPairHelp =>
      'ಜೋಡಿಸಲು ಸ್ವೀಕರಿಸಿ: ಎರಡೂ ಸಾಧನಗಳು ಒಂದನ್ನೊಂದು ನೆನಪಿಡುತ್ತವೆ, ಮುಂದಿನ ಬಾರಿ ನೇರವಾಗಿ ಸಾಮಾನ್ಯ ಪ್ರಶ್ನೆ ಬರುತ್ತದೆ. ನೀವು ಇದನ್ನು ಪ್ರಾರಂಭಿಸದಿದ್ದರೆ, ನಿರಾಕರಿಸಿ ಒತ್ತಿ.';

  @override
  String askPairTitle(String name) {
    return '$name ಅನ್ನು ಸ್ವೀಕರಿಸುವುದೇ?';
  }

  @override
  String askPairWithFiles(
    String platform,
    String name,
    String count,
    String size,
  ) {
    return '$platform ಸಾಧನ \"$name\" ನಿಮಗೆ $count ಫೈಲ್(ಗಳು), $size ಕಳುಹಿಸಲು ಬಯಸುತ್ತದೆ.';
  }

  @override
  String askReplaces(String name) {
    return 'ನೀವು ಮೊದಲು \"$name\" ಎಂಬ ಸಾಧನವನ್ನು ಬೇರೆ ಕೀಲಿಯೊಂದಿಗೆ ಜೋಡಿಸಿದ್ದೀರಿ. ಬಹುಶಃ ಅದರಲ್ಲಿ Isekai Drop ಮರುಸ್ಥಾಪನೆ ಅಥವಾ ರೀಸೆಟ್ ಆಗಿದೆ. ಅದು ನಿಜವಾದರೆ ಮಾತ್ರ ಸ್ವೀಕರಿಸಿ; ಸ್ವೀಕರಿಸಿದರೆ ಹಳೆಯ ಜೋಡಣೆ ಬದಲಾಗುತ್ತದೆ.';
  }

  @override
  String askResume(String size) {
    return 'ನಿಂತುಹೋದ ವರ್ಗಾವಣೆ ಮುಂದುವರಿಯುತ್ತದೆ: $size ಈಗಾಗಲೇ ಇಲ್ಲಿದೆ.';
  }

  @override
  String askTextBody(String count, String platform, String name) {
    return '$platform ಸಾಧನ \"$name\" ಇಂದ ಒಂದು ಚಿಕ್ಕ ಪಠ್ಯ ($count ಅಕ್ಷರಗಳು). ನೀವು ಸ್ವೀಕರಿಸಿದ ನಂತರ ಕಾಣಿಸುತ್ತದೆ.';
  }

  @override
  String askTextTitle(String name) {
    return '$name ನಿಮಗೆ ಒಂದು ಪಠ್ಯ ಕಳುಹಿಸಲು ಬಯಸುತ್ತದೆ';
  }

  @override
  String get autoReceive => 'ಪರಿಶೀಲಿತ ಸಾಧನಗಳಿಂದ ಸ್ವಯಂ-ಸ್ವೀಕಾರ';

  @override
  String get autoReceiveBody =>
      '\"ಪರಿಶೀಲಿಸಲಾಗಿದೆ\" ಎಂದು ಗುರುತಿಸಿದ ಸಾಧನಗಳು ನಿಮ್ಮನ್ನು ಕೇಳದೆ ಈ ಸಾಧನಕ್ಕೆ ಫೈಲ್ ಕಳುಹಿಸಬಹುದು. ಫೈಲ್‌ಗಳು ಈಗಲೂ ಸಾಮಾನ್ಯ ಫೋಲ್ಡರ್‌ಗೆ ಮಾತ್ರ ಹೋಗುತ್ತವೆ ಮತ್ತು ಹಾನಿಗಾಗಿ ಪರಿಶೀಲಿಸಲ್ಪಡುತ್ತವೆ. ಇದನ್ನು ಯಾವಾಗ ಬೇಕಾದರೂ ಆಫ್ ಮಾಡಬಹುದು.';

  @override
  String get autoReceiveInfo =>
      'ಆಫ್: ಪ್ರತಿ ಬಾರಿ ನಿಮ್ಮನ್ನು ಕೇಳಲಾಗುತ್ತದೆ (ಶಿಫಾರಸು). ಆನ್: \"ಪರಿಶೀಲಿಸಲಾಗಿದೆ\" ಸಾಧನಗಳು ಮಾತ್ರ ಕೇಳದೆ ಕಳುಹಿಸಬಹುದು. \"ವಿಶ್ವಾಸಾರ್ಹ\" ಸಾಧನಗಳಿಗೆ ಯಾವಾಗಲೂ ಕೇಳಲಾಗುತ್ತದೆ, ನಿರ್ಬಂಧಿತವನ್ನು ಯಾವಾಗಲೂ ನಿರಾಕರಿಸಲಾಗುತ್ತದೆ.';

  @override
  String get autoReceiveOff =>
      'ಆಫ್: ಪ್ರತಿ ಬಾರಿ ನಿಮ್ಮನ್ನು ಕೇಳಲಾಗುತ್ತದೆ (ಶಿಫಾರಸು)';

  @override
  String get autoReceiveTitle => 'ಸ್ವಯಂ-ಸ್ವೀಕಾರ ಆನ್ ಮಾಡುವುದೇ?';

  @override
  String get benchmarkLog => 'ಬೆಂಚ್‌ಮಾರ್ಕ್ ಲಾಗ್';

  @override
  String get benchmarkSub => 'ಅಳೆದ ಓಟಗಳು, ಮಧ್ಯಮ/ಕನಿಷ್ಠ/ಗರಿಷ್ಠ, CSV ರಫ್ತು';

  @override
  String get blockDevice => 'ಈ ಸಾಧನವನ್ನು ನಿರ್ಬಂಧಿಸಿ';

  @override
  String get blockedNote =>
      'ನಿರ್ಬಂಧಿಸಲಾಗಿದೆ. ಸೆಟ್ಟಿಂಗ್‌ಗಳು > ವಿಶ್ವಾಸಾರ್ಹ ಸಾಧನಗಳು ಇಲ್ಲಿ ತೆರವುಗೊಳಿಸಿ.';

  @override
  String get buildLoading => 'ಬಿಲ್ಡ್: ...';

  @override
  String get buildLocal => 'ಬಿಲ್ಡ್: ಸ್ಥಳೀಯ ಬಿಲ್ಡ್ (GitHub ನಿಂದ ಅಲ್ಲ)';

  @override
  String buildNumber(String number) {
    return 'ಬಿಲ್ಡ್ $number';
  }

  @override
  String get cancel => 'ರದ್ದುಮಾಡಿ';

  @override
  String get cannotRetry =>
      'ಮರುಪ್ರಯತ್ನ ಸಾಧ್ಯವಿಲ್ಲ: ಸಾಧನ ಅಥವಾ ಒಂದು ಫೈಲ್ ಈಗ ಲಭ್ಯವಿಲ್ಲ.';

  @override
  String get chooseFiles => 'ಕಳುಹಿಸಲು ಫೈಲ್‌ಗಳನ್ನು ಆರಿಸಿ';

  @override
  String get clear => 'ತೆರವುಗೊಳಿಸಿ';

  @override
  String get clearFinished => 'ಮುಗಿದವನ್ನು ತೆರವುಗೊಳಿಸಿ';

  @override
  String get clearHistory => 'ಇತಿಹಾಸ ತೆರವುಗೊಳಿಸಿ';

  @override
  String get clearHistoryBody =>
      'ಎಲ್ಲಾ ನಮೂದುಗಳು ಹೋಗುತ್ತವೆ. ನಿಮ್ಮ ಫೈಲ್‌ಗಳು ಅಳಿಯುವುದಿಲ್ಲ.';

  @override
  String get clearHistoryTitle => 'ಇತಿಹಾಸ ತೆರವುಗೊಳಿಸುವುದೇ?';

  @override
  String get clearSelectionBody =>
      'ಇದು ಪಟ್ಟಿಯಿಂದ ಎಲ್ಲಾ ಫೈಲ್‌ಗಳನ್ನು ತೆಗೆಯುತ್ತದೆ. ನಿಮ್ಮ ಫೈಲ್‌ಗಳು ಅಳಿಯುವುದಿಲ್ಲ.';

  @override
  String get clearSelectionTitle => 'ಆಯ್ಕೆ ತೆರವುಗೊಳಿಸುವುದೇ?';

  @override
  String get close => 'ಮುಚ್ಚಿ';

  @override
  String get connectDevice => 'ಸಾಧನವನ್ನು ಸಂಪರ್ಕಿಸಿ';

  @override
  String get connection => 'ಸಂಪರ್ಕ';

  @override
  String get continueLabel => 'ಮುಂದುವರಿಸಿ';

  @override
  String continuedEarlier(String size) {
    return 'ಹಿಂದಿನ ಪ್ರಯತ್ನದಿಂದ ಮುಂದುವರಿಸಲಾಗಿದೆ: $size ಈಗಾಗಲೇ ಇತ್ತು.';
  }

  @override
  String get copied => 'ನಕಲಿಸಲಾಗಿದೆ';

  @override
  String get copy => 'ನಕಲಿಸಿ';

  @override
  String get copyLink => 'ಲಿಂಕ್ ನಕಲಿಸಿ';

  @override
  String get decline => 'ನಿರಾಕರಿಸಿ';

  @override
  String get delete => 'ಅಳಿಸಿ';

  @override
  String get deleteEntry => 'ನಮೂದು ಅಳಿಸಿ';

  @override
  String get deleteEntryBody =>
      'ಇತಿಹಾಸದ ನಮೂದು ಮಾತ್ರ ಹೋಗುತ್ತದೆ. ನಿಮ್ಮ ಫೈಲ್‌ಗಳು ಅಳಿಯುವುದಿಲ್ಲ.';

  @override
  String get deleteEntryTitle => 'ಈ ನಮೂದನ್ನು ಅಳಿಸುವುದೇ?';

  @override
  String get deleteOldNames => 'ಹಳೆಯ ಹೆಸರುಗಳನ್ನು ಅಳಿಸಿ';

  @override
  String deviceKey(String key) {
    return 'ಸಾಧನದ ಕೀಲಿ: $key';
  }

  @override
  String get deviceKeySecure => 'ಸಾಧನದ ಕೀಲಿ: ಸುರಕ್ಷಿತ ಸಂಗ್ರಹದಲ್ಲಿ ಇಡಲಾಗಿದೆ';

  @override
  String get deviceName => 'ಸಾಧನದ ಹೆಸರು';

  @override
  String get deviceNameLabel => 'ಇತರ ಸಾಧನಗಳಿಗೆ ಕಾಣುವ ಹೆಸರು';

  @override
  String get diagnostics => 'ರೋಗನಿರ್ಣಯ ಮಾಹಿತಿ';

  @override
  String get diagnosticsSub => 'ಸಂಪರ್ಕ, ಲಿಂಕ್ ವೇಗ, ವೇಗ ಪರೀಕ್ಷೆ, ಕೊನೆಯ ದೋಷ';

  @override
  String didNotFinish(String count, String size) {
    return '$count ಫೈಲ್(ಗಳು), $size - ಪೂರ್ಣವಾಗಲಿಲ್ಲ';
  }

  @override
  String get discoveryOn => 'ಆನ್';

  @override
  String discoveryState(String state) {
    return 'ಹುಡುಕಾಟ: $state';
  }

  @override
  String get dragFilesHere => 'ಫೈಲ್‌ಗಳನ್ನು ಇಲ್ಲಿಗೆ ಎಳೆಯಿರಿ, ಅಥವಾ';

  @override
  String get encryptionNote =>
      'ಎನ್‌ಕ್ರಿಪ್ಶನ್: TLS 1.3, ಎರಡೂ ಸಾಧನಗಳ ಕೀಲಿಗಳನ್ನು ಪರಿಶೀಲಿಸಲಾಗುತ್ತದೆ.';

  @override
  String engineVersion(String version) {
    return 'ಎಂಜಿನ್: $version';
  }

  @override
  String filesAndSize(String count, String size) {
    return '$count ಫೈಲ್(ಗಳು) · $size';
  }

  @override
  String get folderNotOpened => 'ಫೋಲ್ಡರ್ ತೆರೆಯಲು ಆಗಲಿಲ್ಲ.';

  @override
  String get folderPickFailed =>
      'ಫೋಲ್ಡರ್ ಇಲ್ಲಿ ತೆರೆಯಲು ಆಗಲಿಲ್ಲ. ಬದಲಿಗೆ ಫೈಲ್‌ಗಳನ್ನು ಆರಿಸಿ ನೋಡಿ.';

  @override
  String fromName(String name) {
    return '$name ಇಂದ';
  }

  @override
  String get getStarted => 'ಪ್ರಾರಂಭಿಸಿ';

  @override
  String get helpGuides => 'ಸಹಾಯ ಮತ್ತು ಮಾರ್ಗದರ್ಶಿಗಳು';

  @override
  String get helpGuidesSub => 'ಹಾಟ್‌ಸ್ಪಾಟ್, ಅನುಮತಿಗಳು, ಸಮಸ್ಯೆ ಪರಿಹಾರ';

  @override
  String historyEntries(String count) {
    return 'ಇತಿಹಾಸ ನಮೂದುಗಳು: $count';
  }

  @override
  String historyLine(String outcome, String count, String size) {
    return '$outcome - $count ಫೈಲ್(ಗಳು), $size';
  }

  @override
  String get historyNoteNames =>
      'ಈ ಸಾಧನದಲ್ಲಿ ಮಾತ್ರ ಉಳಿಸಲಾಗಿದೆ. ಫೈಲ್‌ಗಳ ವಿಷಯವನ್ನು ಎಂದಿಗೂ ಇಡುವುದಿಲ್ಲ; ಫೈಲ್ ಹೆಸರುಗಳನ್ನು ಇಡಲಾಗುತ್ತದೆ (ಸೆಟ್ಟಿಂಗ್‌ಗಳಲ್ಲಿ ಆಫ್ ಮಾಡಿ).';

  @override
  String get historyNoteNoNames =>
      'ಈ ಸಾಧನದಲ್ಲಿ ಮಾತ್ರ ಉಳಿಸಲಾಗಿದೆ. ಫೈಲ್‌ಗಳ ವಿಷಯವನ್ನು ಎಂದಿಗೂ ಇಡುವುದಿಲ್ಲ; ಫೈಲ್ ಹೆಸರುಗಳನ್ನು ಉಳಿಸುವುದಿಲ್ಲ.';

  @override
  String get historyUnavailable => 'ಇತಿಹಾಸ ಲಭ್ಯವಿಲ್ಲ';

  @override
  String get historyUnavailableBody =>
      'ಈ ಸಾಧನಕ್ಕೆ ತನ್ನ ಇತಿಹಾಸ ಫೈಲ್ ತೆರೆಯಲು ಆಗಲಿಲ್ಲ.';

  @override
  String get homeFooter =>
      'ಫೈಲ್‌ಗಳು ನೇರವಾಗಿ ನಿಮ್ಮ ಸಾಧನಗಳ ನಡುವೆ ಎನ್‌ಕ್ರಿಪ್ಟ್ ಆಗಿ ಹೋಗುತ್ತವೆ. ಏನೂ ಅಪ್‌ಲೋಡ್ ಆಗುವುದಿಲ್ಲ.';

  @override
  String get homeReadyHelp =>
      'ಸ್ವೀಕರಿಸಲು Isekai Drop ತೆರೆದಿಡಿ. ನಿಮ್ಮನ್ನು ಯಾವಾಗಲೂ ಮೊದಲು ಕೇಳಲಾಗುತ್ತದೆ.';

  @override
  String get howToUpdate => 'ಅಪ್‌ಡೇಟ್ ಮಾಡುವುದು ಹೇಗೆ';

  @override
  String get interruptedSends => 'ನಿಂತುಹೋದ ಕಳುಹಿಸುವಿಕೆಗಳು';

  @override
  String jobProgress(String status, String percent, String size) {
    return '$status - $size ನಲ್ಲಿ $percent%';
  }

  @override
  String get keepOldNames => 'ಹಳೆಯ ಹೆಸರುಗಳನ್ನು ಇಡಿ';

  @override
  String get keyHelp =>
      'ನಿಮ್ಮ ಇತರ ಸಾಧನಗಳು ಈ ಸಾಧನವನ್ನು ಈ ಕೀಲಿಯಿಂದ ಗುರುತಿಸುತ್ತವೆ. ಆ್ಯಪ್ ಮರುಸ್ಥಾಪನೆ ಅಥವಾ ರೀಸೆಟ್ ಆದಾಗ ಮಾತ್ರ ಇದು ಬದಲಾಗುತ್ತದೆ.';

  @override
  String get language => 'ಭಾಷೆ';

  @override
  String get languageNote =>
      'ಹಿಂದಿ ಮತ್ತು ಕನ್ನಡ ಯಂತ್ರ/ಸಹಾಯಕ ಅನುವಾದಗಳು; ಇನ್ನೂ ಸ್ಥಳೀಯ ಭಾಷಿಕರು ಪರಿಶೀಲಿಸಿಲ್ಲ.';

  @override
  String get languageSystem => 'ಸಾಧನದಂತೆಯೇ';

  @override
  String get latestTestBuild => 'ಹೊಸ ಪರೀಕ್ಷಾ ಬಿಲ್ಡ್';

  @override
  String get licences => 'ಪರವಾನಗಿಗಳು';

  @override
  String get licencesSub => 'ಸೇರಿಸಿದ ತಂತ್ರಾಂಶಗಳ ಪೂರ್ಣ ಪರವಾನಗಿ ಪಠ್ಯ';

  @override
  String get licencesTitle => 'ಮುಕ್ತ ಮೂಲ ಪರವಾನಗಿಗಳು';

  @override
  String get manage => 'ನಿರ್ವಹಿಸಿ';

  @override
  String get modeFiles => 'ಫೈಲ್‌ಗಳು';

  @override
  String get modeText => 'ಪಠ್ಯ';

  @override
  String moved(String size) {
    return 'ವರ್ಗಾಯಿಸಿದ್ದು: $size';
  }

  @override
  String nameNearby(String name) {
    return '$name  (ಹತ್ತಿರದಲ್ಲಿ)';
  }

  @override
  String nameNearbyAsk(String name) {
    return '$name  (ಹತ್ತಿರದಲ್ಲಿ, ಒಮ್ಮೆ ಸ್ವೀಕರಿಸಲು ಕೇಳುತ್ತದೆ)';
  }

  @override
  String get navConnect => 'ಸಂಪರ್ಕಿಸಿ';

  @override
  String get navHistory => 'ಇತಿಹಾಸ';

  @override
  String get navHome => 'ಮುಖಪುಟ';

  @override
  String get navSend => 'ಕಳುಹಿಸಿ';

  @override
  String get navSettings => 'ಸೆಟ್ಟಿಂಗ್‌ಗಳು';

  @override
  String get nearbyDevices => 'ಹತ್ತಿರದ ಸಾಧನಗಳು';

  @override
  String nearbySeen(String count) {
    return 'ಕಂಡ ಹತ್ತಿರದ ಸಾಧನಗಳು: $count';
  }

  @override
  String get needsPairingAgain => 'ಮತ್ತೆ ಜೋಡಿಸಬೇಕು';

  @override
  String get newKeyTitle => 'ಈ ಸಾಧನಕ್ಕೆ ಹೊಸ ಕೀಲಿ ಇದೆ';

  @override
  String get next => 'ಮುಂದೆ';

  @override
  String get noAnalytics =>
      'Isekai Drop ನಲ್ಲಿ ಸ್ವತಃ ಯಾವುದೇ ಅನಾಲಿಟಿಕ್ಸ್, ಕ್ಲೌಡ್ ಅಥವಾ ಕ್ರ್ಯಾಶ್ ವರದಿ ಇಲ್ಲ. Android ನಲ್ಲಿ QR ಸ್ಕ್ಯಾನರ್ (Google ML Kit) Google ಗೆ ತನ್ನ ಬಳಕೆಯ ಅಂಕಿಅಂಶಗಳನ್ನು ಕಳುಹಿಸುತ್ತದೆ - Privacy ನೋಡಿ.';

  @override
  String get noTransfers => 'ಇನ್ನೂ ಯಾವುದೇ ವರ್ಗಾವಣೆ ಇಲ್ಲ';

  @override
  String get noTransfersInfo => 'ಮುಗಿದ ವರ್ಗಾವಣೆಗಳು ಇಲ್ಲಿ ಕಾಣಿಸುತ್ತವೆ.';

  @override
  String get notNow => 'ಈಗ ಬೇಡ';

  @override
  String get notReady => 'ಸಿದ್ಧವಿಲ್ಲ';

  @override
  String get notRunning => 'ಚಾಲನೆಯಲ್ಲಿಲ್ಲ';

  @override
  String get notifBody =>
      'Isekai Drop ಅಧಿಸೂಚನೆಯಲ್ಲಿ ವರ್ಗಾವಣೆ ಎಷ್ಟು ಆಗಿದೆ ಎಂದು ತೋರಿಸುತ್ತದೆ ಮತ್ತು ಬರುವ ಫೈಲ್‌ಗಳ ಬಗ್ಗೆ ಕೇಳುತ್ತದೆ. ಆಗ ಬೇರೆ ಆ್ಯಪ್‌ಗೆ ಹೋದರೂ ವರ್ಗಾವಣೆ ಮುಂದುವರಿಯುತ್ತದೆ. ಫೈಲ್ ಅಥವಾ ಸಾಧನದ ಹೆಸರುಗಳು ಕಾಣಿಸುವುದಿಲ್ಲ.';

  @override
  String get notifTitle => 'ವರ್ಗಾವಣೆ ಅಧಿಸೂಚನೆಗಳನ್ನು ತೋರಿಸುವುದೇ?';

  @override
  String get openInBrowser => 'ಬ್ರೌಸರ್‌ನಲ್ಲಿ ತೆರೆಯಿರಿ';

  @override
  String get openLink => 'ಲಿಂಕ್ ತೆರೆಯಿರಿ';

  @override
  String get openSource => 'ಮುಕ್ತ ಮೂಲ ತಂತ್ರಾಂಶ';

  @override
  String get opening => 'ತೆರೆಯುತ್ತಿದೆ...';

  @override
  String get outcomeCancelled => 'ರದ್ದಾಗಿದೆ';

  @override
  String get outcomeCompleted => 'ಪೂರ್ಣಗೊಂಡಿದೆ';

  @override
  String get outcomeFailed => 'ವಿಫಲವಾಗಿದೆ';

  @override
  String get pairAgain => 'ಮತ್ತೆ ಜೋಡಿಸಿ';

  @override
  String get pickFiles => 'ಫೈಲ್‌ಗಳನ್ನು ಆರಿಸಿ';

  @override
  String get pickFolder => 'ಫೋಲ್ಡರ್ ಆರಿಸಿ';

  @override
  String get pickerFailed =>
      'ಫೈಲ್ ಆಯ್ಕೆ ತೆರೆಯಲು ಆಗಲಿಲ್ಲ. ದಯವಿಟ್ಟು ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.';

  @override
  String get ready => 'ಸಿದ್ಧ';

  @override
  String get receiveTrusted => 'ವಿಶ್ವಾಸಾರ್ಹ ಸಾಧನಗಳಿಂದ ಫೈಲ್ ಸ್ವೀಕರಿಸಿ';

  @override
  String get receiveTrustedInfo =>
      'ಆಫ್ ಇದ್ದಾಗ ಪ್ರತಿ ಕೊಡುಗೆಯನ್ನು ನಿರಾಕರಿಸಲಾಗುತ್ತದೆ. ಅಪರಿಚಿತ ಸಾಧನಗಳು ಎಂದಿಗೂ ಕಳುಹಿಸಲಾರವು; ಮೊದಲು ಜೋಡಿಸಬೇಕು.';

  @override
  String get receiveTrustedOff => 'ಆಫ್: ಪ್ರತಿ ಕೊಡುಗೆಯನ್ನು ನಿರಾಕರಿಸಲಾಗುತ್ತದೆ';

  @override
  String receivedFrom(String name) {
    return '$name ಇಂದ ಸ್ವೀಕರಿಸಲಾಗಿದೆ';
  }

  @override
  String receivedGoTo(String place) {
    return 'ಸ್ವೀಕರಿಸಿದ ಫೈಲ್‌ಗಳು ಇಲ್ಲಿಗೆ ಹೋಗುತ್ತವೆ: $place';
  }

  @override
  String get receiving => 'ಸ್ವೀಕರಿಸುವಿಕೆ';

  @override
  String receivingPort(String port) {
    return 'ಈ ಪೋರ್ಟ್‌ನಲ್ಲಿ ಸ್ವೀಕರಿಸುತ್ತಿದೆ: $port';
  }

  @override
  String rejectedPeerBody(String name, String paired) {
    return '\"$name\" ಸಂಪರ್ಕಿಸಲು ಪ್ರಯತ್ನಿಸಿತು, ಆದರೆ ಜೋಡಿಸುವಾಗ \"$paired\" ಗೆ ಇದ್ದ ಕೀಲಿಗಿಂತ ಬೇರೆ ಕೀಲಿಯೊಂದಿಗೆ. ಬಹುಶಃ ಅದರಲ್ಲಿ Isekai Drop ಮರುಸ್ಥಾಪನೆ ಅಥವಾ ರೀಸೆಟ್ ಆಗಿದೆ. ಈ ಸಾಧನ ಅದನ್ನು ನಿರಾಕರಿಸಿತು. ಅದು ನಿಜವಾದರೆ ಮಾತ್ರ ಮತ್ತೆ ಜೋಡಿಸಿ.';
  }

  @override
  String get remove => 'ತೆಗೆಯಿರಿ';

  @override
  String removeFromList(String name) {
    return '$name ಅನ್ನು ಪಟ್ಟಿಯಿಂದ ತೆಗೆಯಿರಿ';
  }

  @override
  String get removeSendBody =>
      'ಇದನ್ನು ಇನ್ನು ಮರುಪ್ರಯತ್ನಕ್ಕೆ ತೋರಿಸುವುದಿಲ್ಲ. ನಿಮ್ಮ ಫೈಲ್‌ಗಳು ಅಳಿಯುವುದಿಲ್ಲ.';

  @override
  String get removeSendTitle => 'ಈ ಕಳುಹಿಸುವಿಕೆಯನ್ನು ತೆಗೆಯುವುದೇ?';

  @override
  String get rename => 'ಹೆಸರು ಬದಲಿಸಿ';

  @override
  String get requestExpired =>
      'ವಿನಂತಿಯ ಸಮಯ ಮುಗಿಯಿತು - ಯಾರೂ ಸಮಯಕ್ಕೆ ಉತ್ತರಿಸಲಿಲ್ಲ.';

  @override
  String get retry => 'ಮರುಪ್ರಯತ್ನಿಸಿ';

  @override
  String get save => 'ಉಳಿಸಿ';

  @override
  String get saveNames => 'ಇತಿಹಾಸದಲ್ಲಿ ಫೈಲ್ ಹೆಸರುಗಳನ್ನು ಉಳಿಸಿ';

  @override
  String get saveNamesInfo =>
      'ಹೆಸರುಗಳನ್ನು ಈ ಸಾಧನದಲ್ಲಿ ಮಾತ್ರ ಇಡಲಾಗುತ್ತದೆ, ಲಾಗ್‌ಗಳಲ್ಲಿ ಎಂದಿಗೂ ಬರೆಯುವುದಿಲ್ಲ. ಫೈಲ್‌ಗಳ ವಿಷಯವನ್ನು ಎಂದಿಗೂ ಉಳಿಸುವುದಿಲ್ಲ.';

  @override
  String get saveNamesSummary => 'ಈ ಸಾಧನದಲ್ಲಿ ಮಾತ್ರ ಇಡಲಾಗುತ್ತದೆ';

  @override
  String savedTo(String place) {
    return 'ಇಲ್ಲಿ ಉಳಿಸಲಾಗಿದೆ: $place';
  }

  @override
  String get savedTrusted => 'ಉಳಿಸಿದ ವಿಶ್ವಾಸಾರ್ಹ ಸಾಧನಗಳು';

  @override
  String get security => 'ಭದ್ರತೆ';

  @override
  String sendFilesTo(String count, String name) {
    return '$name ಗೆ $count ಫೈಲ್(ಗಳು) ಕಳುಹಿಸಿ';
  }

  @override
  String get sendText => 'ಪಠ್ಯ ಕಳುಹಿಸಿ';

  @override
  String sendTextTo(String name) {
    return '$name ಗೆ ಪಠ್ಯ ಕಳುಹಿಸಿ';
  }

  @override
  String sendToName(String name) {
    return '$name ಗೆ ಕಳುಹಿಸಿ';
  }

  @override
  String sentTo(String name) {
    return '$name ಗೆ ಕಳುಹಿಸಲಾಗಿದೆ';
  }

  @override
  String get sharedFromApp => 'ಬೇರೆ ಆ್ಯಪ್‌ನಿಂದ ಹಂಚಲಾಗಿದೆ';

  @override
  String shortKey(String key) {
    return 'ಚಿಕ್ಕ ರೂಪ: $key';
  }

  @override
  String get showFolder => 'ಫೋಲ್ಡರ್ ತೋರಿಸಿ';

  @override
  String get skip => 'ಬಿಟ್ಟುಬಿಡಿ';

  @override
  String get slide1Text => 'ಫೋನ್ ಮತ್ತು ಪಿಸಿ. ಖಾತೆ ಇಲ್ಲ, ಕ್ಲೌಡ್ ಇಲ್ಲ.';

  @override
  String get slide1Title => 'ಎರಡೂ ಸಾಧನಗಳಲ್ಲಿ Isekai Drop ತೆರೆಯಿರಿ';

  @override
  String get slide2Text =>
      'ಎರಡೂ ಸಾಧನಗಳು ಒಂದೇ ನೆಟ್‌ವರ್ಕ್‌ನಲ್ಲಿರಲಿ (ಅಥವಾ ಒಂದು ಹಾಟ್‌ಸ್ಪಾಟ್ ಹಂಚಲಿ). ಮೊದಲ ಬಾರಿ QR ಕೋಡ್‌ನಿಂದ ಒಮ್ಮೆ ಸಂಪರ್ಕಿಸಿ.';

  @override
  String get slide2Title => 'ಒಂದೇ ವೈ-ಫೈ ಬಳಸಿ';

  @override
  String get slide3Text =>
      'ಫೈಲ್‌ಗಳು ನೇರವಾಗಿ ನಿಮ್ಮ ಸಾಧನಗಳ ನಡುವೆ ಹೋಗುತ್ತವೆ, ಎನ್‌ಕ್ರಿಪ್ಟ್ ಮಾಡಿ ಪರಿಶೀಲಿಸಿ.';

  @override
  String get slide3Title => 'ಫೈಲ್‌ಗಳನ್ನು ಆರಿಸಿ ಕಳುಹಿಸಿ';

  @override
  String get starting => 'ಪ್ರಾರಂಭವಾಗುತ್ತಿದೆ...';

  @override
  String stepFilesCount(String count, String size) {
    return '1. ಫೈಲ್‌ಗಳು: $count, $size';
  }

  @override
  String stepOf(String step, String total) {
    return 'ಹಂತ $step / $total';
  }

  @override
  String get stepPickDevice => '2. ಸಾಧನ ಆರಿಸಿ';

  @override
  String get stepPickFiles => '1. ಫೈಲ್‌ಗಳನ್ನು ಆರಿಸಿ';

  @override
  String get stepTextOrLink => '1. ಪಠ್ಯ ಅಥವಾ ಲಿಂಕ್';

  @override
  String get stopNamesBody =>
      'ಹೊಸ ಇತಿಹಾಸ ನಮೂದುಗಳಲ್ಲಿ ಫೈಲ್ ಹೆಸರುಗಳು ಇರುವುದಿಲ್ಲ. ಈಗಾಗಲೇ ಉಳಿಸಿದ ಹೆಸರುಗಳನ್ನೂ ಅಳಿಸಬೇಕೇ?';

  @override
  String get stopNamesTitle => 'ಫೈಲ್ ಹೆಸರುಗಳನ್ನು ಉಳಿಸುವುದನ್ನು ನಿಲ್ಲಿಸುವುದೇ?';

  @override
  String get testBuildNote => 'ಇದು ಪರೀಕ್ಷಾ ಬಿಲ್ಡ್, ಸಾರ್ವಜನಿಕ ಬಿಡುಗಡೆ ಅಲ್ಲ.';

  @override
  String get textAskNote =>
      'ಇನ್ನೊಂದು ಸಾಧನ ತೋರಿಸುವ ಮೊದಲು ಕೇಳುತ್ತದೆ. ಲಿಂಕ್‌ಗಳು ತಾವಾಗಿಯೇ ಎಂದಿಗೂ ತೆರೆಯುವುದಿಲ್ಲ.';

  @override
  String get textErrDeclined => 'ಇನ್ನೊಂದು ಸಾಧನ ಪಠ್ಯವನ್ನು ನಿರಾಕರಿಸಿತು.';

  @override
  String get textErrEmpty => 'ಮೊದಲು ಪಠ್ಯ ಬರೆಯಿರಿ.';

  @override
  String get textErrExpired => 'ಇನ್ನೊಂದು ಸಾಧನದಲ್ಲಿ ಯಾರೂ ಉತ್ತರಿಸಲಿಲ್ಲ.';

  @override
  String get textErrFailed =>
      'ಪಠ್ಯ ಕಳುಹಿಸಲು ಆಗಲಿಲ್ಲ. ದಯವಿಟ್ಟು ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.';

  @override
  String get textErrNoAddress =>
      'ಇನ್ನೊಂದು ಸಾಧನ ಸಿಗಲಿಲ್ಲ. ಅದು ಅದೇ ನೆಟ್‌ವರ್ಕ್‌ನಲ್ಲಿದೆ ಮತ್ತು Isekai Drop ತೆರೆದಿದೆ ಎಂದು ನೋಡಿ.';

  @override
  String get textErrNotTrusted =>
      'ಇನ್ನೊಂದು ಸಾಧನ ಈಗ ಈ ಸಾಧನವನ್ನು ನಂಬುವುದಿಲ್ಲ. ಮತ್ತೆ ಜೋಡಿಸಿ.';

  @override
  String get textErrOldPeer =>
      'ಇನ್ನೊಂದು ಸಾಧನದಲ್ಲಿ ಪಠ್ಯ ಸ್ವೀಕರಿಸಲಾಗದ ಹಳೆಯ Isekai Drop ಇದೆ. ಆ ಆ್ಯಪ್ ಅನ್ನು ಅಪ್‌ಡೇಟ್ ಮಾಡಿ.';

  @override
  String get textErrTooLong =>
      'ಪಠ್ಯ ತುಂಬಾ ಉದ್ದವಾಗಿದೆ. 8 KB (ಸುಮಾರು 8000 ಅಕ್ಷರಗಳು) ವರೆಗೆ ಕಳುಹಿಸಬಹುದು.';

  @override
  String textFrom(String name) {
    return '$name ಇಂದ ಪಠ್ಯ';
  }

  @override
  String get textHint => 'ಪಠ್ಯ ಅಥವಾ ಲಿಂಕ್ ಬರೆಯಿರಿ ಅಥವಾ ಅಂಟಿಸಿ';

  @override
  String get textPairedOnly =>
      'ಪಠ್ಯವನ್ನು ಜೋಡಿಸಿದ ಸಾಧನಗಳಿಗೆ ಮಾತ್ರ ಕಳುಹಿಸಬಹುದು. ಮೊದಲು ಜೋಡಿಸಿ (ಫೈಲ್ ಕಳುಹಿಸಿ, ಅಥವಾ ಸಂಪರ್ಕಿಸಿ ಬಳಸಿ).';

  @override
  String textSentTo(String name) {
    return '$name ಗೆ ಪಠ್ಯ ಕಳುಹಿಸಲಾಗಿದೆ.';
  }

  @override
  String get theme => 'ಥೀಮ್';

  @override
  String get themeDark => 'ಡಾರ್ಕ್';

  @override
  String get themeLight => 'ಲೈಟ್';

  @override
  String get themeSystem => 'ಸಿಸ್ಟಮ್';

  @override
  String get thisDevice => 'ಈ ಸಾಧನ';

  @override
  String get thisDeviceKey => 'ಈ ಸಾಧನದ ಕೀಲಿ';

  @override
  String toName(String name) {
    return '$name ಗೆ';
  }

  @override
  String get transfersThisSession => 'ಈ ಬಾರಿಯ ವರ್ಗಾವಣೆಗಳು';

  @override
  String trustedCount(String count) {
    return 'ವಿಶ್ವಾಸಾರ್ಹ ಸಾಧನಗಳು: $count';
  }

  @override
  String get trustedDevices => 'ವಿಶ್ವಾಸಾರ್ಹ ಸಾಧನಗಳು';

  @override
  String get trustedDevicesSub =>
      'ಕೋಡ್ ಪರಿಶೀಲಿಸಿ, ಹೆಸರು ಬದಲಿಸಿ, ಹಿಂಪಡೆಯಿರಿ ಅಥವಾ ತೆಗೆಯಿರಿ';

  @override
  String get turnOn => 'ಆನ್ ಮಾಡಿ';

  @override
  String get unavailable => 'ಲಭ್ಯವಿಲ್ಲ';

  @override
  String get updateAndroid =>
      'Android: ಮೇಲಿನ ಲಿಂಕ್ ತೆರೆಯಿರಿ, isekai-drop-android-arm64.apk (ಅಥವಾ -universal.apk) ಡೌನ್‌ಲೋಡ್ ಮಾಡಿ ಈ ಆ್ಯಪ್‌ನ ಮೇಲೆಯೇ ಸ್ಥಾಪಿಸಿ. ನಿಮ್ಮ ಜೋಡಿಸಿದ ಸಾಧನಗಳು ಮತ್ತು ಇತಿಹಾಸ ಉಳಿಯುತ್ತವೆ.';

  @override
  String get updateBoth =>
      'ಎರಡೂ ಸಾಧನಗಳನ್ನು ಅಪ್‌ಡೇಟ್ ಮಾಡಿ: ತುಂಬಾ ಬೇರೆ ಆವೃತ್ತಿಗಳ ಸಾಧನಗಳು ಒಂದನ್ನೊಂದು ಅರ್ಥಮಾಡಿಕೊಳ್ಳದಿರಬಹುದು.';

  @override
  String get updateIos =>
      'iPhone/iPad: ಹೊಸ .ipa ಅನ್ನು ನಿಮ್ಮ Apple ID ಯಿಂದ ಮತ್ತೆ ಸಹಿ ಮಾಡಿ (NOT TESTED).';

  @override
  String get updateMac =>
      'Mac: isekai-drop-macos.dmg ಡೌನ್‌ಲೋಡ್ ಮಾಡಿ ಆ್ಯಪ್ ಅನ್ನು Applications ಗೆ ಎಳೆಯಿರಿ (Mac ನಲ್ಲಿ NOT TESTED).';

  @override
  String get updateWindows =>
      'Windows: isekai-drop-windows-setup.exe ಡೌನ್‌ಲೋಡ್ ಮಾಡಿ ಚಲಾಯಿಸಿ.';

  @override
  String get versionTitle => 'ಆವೃತ್ತಿ';

  @override
  String get visible => 'ಹತ್ತಿರದ ಸಾಧನಗಳಿಗೆ ಕಾಣಿಸಲಿ';

  @override
  String get visibleInfo =>
      'ಆಫ್: ಈ ಸಾಧನ ತನ್ನನ್ನು ಘೋಷಿಸುವುದನ್ನು ನಿಲ್ಲಿಸುತ್ತದೆ (Bonjour ಕೂಡ). ಜೋಡಿಸಿದ ಸಾಧನಗಳು ಮತ್ತು QR/ಬರೆದ ವಿಳಾಸದ ಸಂಪರ್ಕಗಳು ಈಗಲೂ ಕೆಲಸ ಮಾಡುತ್ತವೆ.';

  @override
  String get visibleSummary =>
      'ನಿಮ್ಮ ವೈ-ಫೈನಲ್ಲಿರುವ ಇತರರು ಈ ಸಾಧನವನ್ನು ಹುಡುಕಬಹುದು';
}
