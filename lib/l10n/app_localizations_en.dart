// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get aboutApp => 'About Isekai Drop';

  @override
  String aboutSubtitle(String version) {
    return 'Isekai Drop $version - build, key, updates, licences';
  }

  @override
  String get aboutThisDevice => 'About this device';

  @override
  String get aboutTitle => 'About';

  @override
  String get accept => 'Accept';

  @override
  String get addedToQueue =>
      'Added to the queue. It starts when the current send finishes.';

  @override
  String get advanced => 'Advanced';

  @override
  String andMore(String count) {
    return '...and $count more';
  }

  @override
  String get anyFilesIos =>
      'Files of any type. Folders cannot be picked on iPhone/iPad yet - pick the files inside instead.';

  @override
  String get anyFilesOrFolder =>
      'Files of any type, or a whole folder (its sub-folders are kept).';

  @override
  String get appTitle => 'Isekai Drop';

  @override
  String appVersion(String version) {
    return 'Isekai Drop $version';
  }

  @override
  String get appearance => 'Appearance';

  @override
  String get askAlwaysAllow => 'Always allow this device';

  @override
  String get askAlwaysAllowHelp =>
      'Files from it are received without this question. Turn off in Settings > Trusted devices.';

  @override
  String get askCodeCheck =>
      'Optional check: the other screen shows the same code';

  @override
  String askFilesTitle(String name) {
    return '$name wants to send you files';
  }

  @override
  String askFromTrusted(String platform, String name) {
    return 'From trusted $platform device \"$name\".';
  }

  @override
  String get askKeyWarning =>
      'WARNING: a device with this id was paired before with a DIFFERENT key. Accept only if you reinstalled or reset Isekai Drop on it. Accepting replaces the old key.';

  @override
  String askPairConnect(String platform, String name) {
    return '$platform device \"$name\" wants to connect.';
  }

  @override
  String get askPairHelp =>
      'Accept to pair: both devices remember each other, so next time files go straight to the usual question. If you did not start this, tap Decline.';

  @override
  String askPairTitle(String name) {
    return 'Accept $name?';
  }

  @override
  String askPairWithFiles(
    String platform,
    String name,
    String count,
    String size,
  ) {
    return '$platform device \"$name\" wants to send you $count file(s), $size.';
  }

  @override
  String askReplaces(String name) {
    return 'You paired a device named \"$name\" before, with a different key. This is probably that device after Isekai Drop was reinstalled or reset on it. Accept only if that is true; accepting replaces the old pairing.';
  }

  @override
  String askResume(String size) {
    return 'Continues an interrupted transfer: $size are already here.';
  }

  @override
  String askTextBody(String count, String platform, String name) {
    return 'A short text ($count characters) from $platform device \"$name\". It is shown after you accept.';
  }

  @override
  String askTextTitle(String name) {
    return '$name wants to send you a text';
  }

  @override
  String get autoReceive => 'Auto-receive from verified devices';

  @override
  String get autoReceiveBody =>
      'Devices marked \"Verified\" will be able to send files to this device without asking you. Files still go only to the normal receive folder and are still checked for damage. You can turn this off at any time.';

  @override
  String get autoReceiveInfo =>
      'Off: you are asked every time (recommended). On: only devices marked \"Verified\" can send without asking. \"Trusted\" and blocked devices are always asked or refused.';

  @override
  String get autoReceiveOff => 'Off: you are asked every time (recommended)';

  @override
  String get autoReceiveTitle => 'Turn on auto-receive?';

  @override
  String get benchmarkLog => 'Benchmark log';

  @override
  String get benchmarkSub => 'Measured runs, median/min/max, CSV export';

  @override
  String get blockDevice => 'Block this device';

  @override
  String get blockedNote =>
      'Blocked. Unblock it in Settings > Trusted devices.';

  @override
  String get buildLoading => 'Build: ...';

  @override
  String get buildLocal => 'Build: local build (not from GitHub)';

  @override
  String buildNumber(String number) {
    return 'Build $number';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get cannotRetry =>
      'Cannot retry: the device or a file is no longer available.';

  @override
  String get chooseFiles => 'Choose files to send';

  @override
  String get clear => 'Clear';

  @override
  String get clearFinished => 'Clear finished';

  @override
  String get clearHistory => 'Clear history';

  @override
  String get clearHistoryBody =>
      'All entries will be removed. Your files are not deleted.';

  @override
  String get clearHistoryTitle => 'Clear history?';

  @override
  String get clearSelectionBody =>
      'This removes all files from the list. Your files are not deleted.';

  @override
  String get clearSelectionTitle => 'Clear selection?';

  @override
  String get close => 'Close';

  @override
  String get connectDevice => 'Connect a device';

  @override
  String get connection => 'Connection';

  @override
  String get continueLabel => 'Continue';

  @override
  String continuedEarlier(String size) {
    return 'Continued an earlier attempt: $size were already there.';
  }

  @override
  String get copied => 'Copied';

  @override
  String get copy => 'Copy';

  @override
  String get copyLink => 'Copy link';

  @override
  String get decline => 'Decline';

  @override
  String get delete => 'Delete';

  @override
  String get deleteEntry => 'Delete entry';

  @override
  String get deleteEntryBody =>
      'Only the history entry is removed. Your files are not deleted.';

  @override
  String get deleteEntryTitle => 'Delete this entry?';

  @override
  String get deleteOldNames => 'Delete old names';

  @override
  String deviceKey(String key) {
    return 'Device key: $key';
  }

  @override
  String get deviceKeySecure => 'Device key: kept in secure storage';

  @override
  String get deviceName => 'Device name';

  @override
  String get deviceNameLabel => 'Name other devices will see';

  @override
  String get diagnostics => 'Diagnostics';

  @override
  String get diagnosticsSub => 'Connection, link speed, speed test, last error';

  @override
  String didNotFinish(String count, String size) {
    return '$count file(s), $size - did not finish';
  }

  @override
  String get discoveryOn => 'on';

  @override
  String discoveryState(String state) {
    return 'Discovery: $state';
  }

  @override
  String get dragFilesHere => 'Drag files here, or';

  @override
  String get encryptionNote =>
      'Encryption: TLS 1.3 with both devices\' keys checked.';

  @override
  String engineVersion(String version) {
    return 'Engine: $version';
  }

  @override
  String filesAndSize(String count, String size) {
    return '$count file(s) · $size';
  }

  @override
  String get folderNotOpened => 'The folder could not be opened.';

  @override
  String get folderPickFailed =>
      'The folder could not be opened here. Try picking files instead.';

  @override
  String fromName(String name) {
    return 'From $name';
  }

  @override
  String get getStarted => 'Get started';

  @override
  String get helpGuides => 'Help & guides';

  @override
  String get helpGuidesSub => 'Hotspot, permissions, troubleshooting';

  @override
  String historyEntries(String count) {
    return 'History entries: $count';
  }

  @override
  String historyLine(String outcome, String count, String size) {
    return '$outcome - $count file(s), $size';
  }

  @override
  String get historyNoteNames =>
      'Saved on this device only. File contents are never stored; file names are (turn off in Settings).';

  @override
  String get historyNoteNoNames =>
      'Saved on this device only. File contents are never stored; file names are not saved.';

  @override
  String get historyUnavailable => 'History is not available';

  @override
  String get historyUnavailableBody =>
      'This device could not open its history file.';

  @override
  String get homeFooter =>
      'Files go directly between your devices, encrypted. Nothing is uploaded.';

  @override
  String get homeReadyHelp =>
      'Keep Isekai Drop open to receive. You will always be asked first.';

  @override
  String get howToUpdate => 'How to update';

  @override
  String get interruptedSends => 'Interrupted sends';

  @override
  String jobProgress(String status, String percent, String size) {
    return '$status - $percent% of $size';
  }

  @override
  String get keepOldNames => 'Keep old names';

  @override
  String get keyHelp =>
      'Your other devices know this device by this key. It changes only if the app is reinstalled or reset.';

  @override
  String get language => 'Language';

  @override
  String get languageNote =>
      'Hindi and Kannada are machine/assistant translations and have not been checked by a native speaker yet.';

  @override
  String get languageSystem => 'Same as device';

  @override
  String get latestTestBuild => 'Latest test build';

  @override
  String get licences => 'Licences';

  @override
  String get licencesSub => 'Full licence texts of included software';

  @override
  String get licencesTitle => 'Open-source licences';

  @override
  String get manage => 'Manage';

  @override
  String get modeFiles => 'Files';

  @override
  String get modeText => 'Text';

  @override
  String moved(String size) {
    return 'Moved: $size';
  }

  @override
  String nameNearby(String name) {
    return '$name  (nearby)';
  }

  @override
  String nameNearbyAsk(String name) {
    return '$name  (nearby, asks once to accept)';
  }

  @override
  String get navConnect => 'Connect';

  @override
  String get navHistory => 'History';

  @override
  String get navHome => 'Home';

  @override
  String get navSend => 'Send';

  @override
  String get navSettings => 'Settings';

  @override
  String get nearbyDevices => 'Nearby devices';

  @override
  String nearbySeen(String count) {
    return 'Nearby devices seen: $count';
  }

  @override
  String get needsPairingAgain => 'Needs pairing again';

  @override
  String get newKeyTitle => 'This device has a new key';

  @override
  String get next => 'Next';

  @override
  String get noAnalytics =>
      'Isekai Drop itself has no analytics, no cloud, no crash reporting. On Android the QR scanner (Google ML Kit) sends Google its own usage metrics - see Privacy.';

  @override
  String get noTransfers => 'No transfers yet';

  @override
  String get noTransfersInfo => 'Finished transfers will be listed here.';

  @override
  String get notNow => 'Not now';

  @override
  String get notReady => 'Not ready';

  @override
  String get notRunning => 'not running';

  @override
  String get notifBody =>
      'Isekai Drop shows how far a transfer is, and asks you about incoming files, in a notification. Then transfers keep going when you switch to another app. No file names or device names are shown.';

  @override
  String get notifTitle => 'Show transfer notifications?';

  @override
  String get openInBrowser => 'Open in browser';

  @override
  String get openLink => 'Open link';

  @override
  String get openSource => 'Open-source software';

  @override
  String get opening => 'Opening...';

  @override
  String get outcomeCancelled => 'Cancelled';

  @override
  String get outcomeCompleted => 'Completed';

  @override
  String get outcomeFailed => 'Failed';

  @override
  String get pairAgain => 'Pair again';

  @override
  String get pickFiles => 'Pick files';

  @override
  String get pickFolder => 'Pick a folder';

  @override
  String get pickerFailed =>
      'The file picker could not open. Please try again.';

  @override
  String get ready => 'Ready';

  @override
  String get receiveTrusted => 'Receive files from trusted devices';

  @override
  String get receiveTrustedInfo =>
      'When off, every offer is declined. Unknown devices can never send; they must pair first.';

  @override
  String get receiveTrustedOff => 'Off: every offer is declined';

  @override
  String receivedFrom(String name) {
    return 'Received from $name';
  }

  @override
  String receivedGoTo(String place) {
    return 'Received files go to: $place';
  }

  @override
  String get receiving => 'Receiving';

  @override
  String receivingPort(String port) {
    return 'Receiving on port: $port';
  }

  @override
  String rejectedPeerBody(String name, String paired) {
    return '\"$name\" tried to connect, but with a different key than \"$paired\" had when you paired. Most likely Isekai Drop was reinstalled or reset on it. This device refused it. Pair again only if that is true.';
  }

  @override
  String get remove => 'Remove';

  @override
  String removeFromList(String name) {
    return 'Remove $name from list';
  }

  @override
  String get removeSendBody =>
      'It will no longer be offered for retry. Your files are not deleted.';

  @override
  String get removeSendTitle => 'Remove this send?';

  @override
  String get rename => 'Rename';

  @override
  String get requestExpired => 'Request expired - nobody answered in time.';

  @override
  String get retry => 'Retry';

  @override
  String get save => 'Save';

  @override
  String get saveNames => 'Save file names in History';

  @override
  String get saveNamesInfo =>
      'Names are kept on this device only and never written to logs. File contents are never saved.';

  @override
  String get saveNamesSummary => 'Kept on this device only';

  @override
  String savedTo(String place) {
    return 'Saved to: $place';
  }

  @override
  String get savedTrusted => 'Saved trusted devices';

  @override
  String get security => 'Security';

  @override
  String sendFilesTo(String count, String name) {
    return 'Send $count file(s) to $name';
  }

  @override
  String get sendText => 'Send text';

  @override
  String sendTextTo(String name) {
    return 'Send text to $name';
  }

  @override
  String sendToName(String name) {
    return 'Send to $name';
  }

  @override
  String sentTo(String name) {
    return 'Sent to $name';
  }

  @override
  String get sharedFromApp => 'Shared from another app';

  @override
  String shortKey(String key) {
    return 'Short: $key';
  }

  @override
  String get showFolder => 'Show folder';

  @override
  String get skip => 'Skip';

  @override
  String get slide1Text => 'Phones and PCs. No account and no cloud.';

  @override
  String get slide1Title => 'Open Isekai Drop on both devices';

  @override
  String get slide2Text =>
      'Both devices on one network (or one shares a hotspot). The first time, connect them once with a QR code.';

  @override
  String get slide2Title => 'Use the same Wi-Fi';

  @override
  String get slide3Text =>
      'Files go straight between your devices, encrypted and checked.';

  @override
  String get slide3Title => 'Pick files and send';

  @override
  String get starting => 'Starting...';

  @override
  String stepFilesCount(String count, String size) {
    return '1. Files: $count, $size';
  }

  @override
  String stepOf(String step, String total) {
    return 'Step $step of $total';
  }

  @override
  String get stepPickDevice => '2. Pick a device';

  @override
  String get stepPickFiles => '1. Pick files';

  @override
  String get stepTextOrLink => '1. Text or link';

  @override
  String get stopNamesBody =>
      'New history entries will not contain file names. Do you also want to delete the names already saved?';

  @override
  String get stopNamesTitle => 'Stop saving file names?';

  @override
  String get testBuildNote => 'A test build, not a public release.';

  @override
  String get textAskNote =>
      'The other device asks before showing it. Links are never opened by themselves.';

  @override
  String get textErrDeclined => 'The other device declined the text.';

  @override
  String get textErrEmpty => 'Type a text first.';

  @override
  String get textErrExpired => 'Nobody answered on the other device.';

  @override
  String get textErrFailed => 'The text could not be sent. Please try again.';

  @override
  String get textErrNoAddress =>
      'The other device was not found. Make sure it is on the same network with Isekai Drop open.';

  @override
  String get textErrNotTrusted =>
      'The other device does not trust this device any more. Pair again.';

  @override
  String get textErrOldPeer =>
      'The other device has an older Isekai Drop that cannot receive text. Update the other app.';

  @override
  String get textErrTooLong =>
      'The text is too long. Up to 8 KB (about 8000 letters) can be sent.';

  @override
  String textFrom(String name) {
    return 'Text from $name';
  }

  @override
  String get textHint => 'Type or paste a text or link';

  @override
  String get textPairedOnly =>
      'Text can be sent to paired devices only. Pair first (send a file, or use Connect).';

  @override
  String textSentTo(String name) {
    return 'Text sent to $name.';
  }

  @override
  String get theme => 'Theme';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get themeSystem => 'System';

  @override
  String get thisDevice => 'This device';

  @override
  String get thisDeviceKey => 'This device\'s key';

  @override
  String toName(String name) {
    return 'To $name';
  }

  @override
  String get transfersThisSession => 'Transfers this session';

  @override
  String trustedCount(String count) {
    return 'Trusted devices: $count';
  }

  @override
  String get trustedDevices => 'Trusted devices';

  @override
  String get trustedDevicesSub => 'Check codes, rename, revoke or remove';

  @override
  String get turnOn => 'Turn on';

  @override
  String get unavailable => 'unavailable';

  @override
  String get updateAndroid =>
      'Android: open the link above, download isekai-drop-android-arm64.apk (or -universal.apk) and install it over this app. Your paired devices and history stay.';

  @override
  String get updateBoth =>
      'Update both devices: devices with very different versions may not understand each other.';

  @override
  String get updateIos =>
      'iPhone/iPad: sign the new .ipa again with your own Apple ID (NOT TESTED).';

  @override
  String get updateMac =>
      'Mac: download isekai-drop-macos.dmg and drag the app to Applications (NOT TESTED on a Mac).';

  @override
  String get updateWindows =>
      'Windows: download isekai-drop-windows-setup.exe and run it.';

  @override
  String get versionTitle => 'Version';

  @override
  String get visible => 'Visible to nearby devices';

  @override
  String get visibleInfo =>
      'Off: this device stops announcing itself (and stops Bonjour). Paired devices and QR/typed-address connections still work.';

  @override
  String get visibleSummary => 'Others on your Wi-Fi can find this device';
}
