import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_kn.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
    Locale('kn'),
  ];

  /// No description provided for @aboutApp.
  ///
  /// In en, this message translates to:
  /// **'About Isekai Drop'**
  String get aboutApp;

  /// No description provided for @aboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Isekai Drop {version} - build, key, updates, licences'**
  String aboutSubtitle(String version);

  /// No description provided for @aboutThisDevice.
  ///
  /// In en, this message translates to:
  /// **'About this device'**
  String get aboutThisDevice;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @addedToQueue.
  ///
  /// In en, this message translates to:
  /// **'Added to the queue. It starts when the current send finishes.'**
  String get addedToQueue;

  /// No description provided for @advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advanced;

  /// No description provided for @andMore.
  ///
  /// In en, this message translates to:
  /// **'...and {count} more'**
  String andMore(String count);

  /// No description provided for @anyFilesIos.
  ///
  /// In en, this message translates to:
  /// **'Files of any type. Folders cannot be picked on iPhone/iPad yet - pick the files inside instead.'**
  String get anyFilesIos;

  /// No description provided for @anyFilesOrFolder.
  ///
  /// In en, this message translates to:
  /// **'Files of any type, or a whole folder (its sub-folders are kept).'**
  String get anyFilesOrFolder;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Isekai Drop'**
  String get appTitle;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'Isekai Drop {version}'**
  String appVersion(String version);

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @askAlwaysAllow.
  ///
  /// In en, this message translates to:
  /// **'Always allow this device'**
  String get askAlwaysAllow;

  /// No description provided for @askAlwaysAllowHelp.
  ///
  /// In en, this message translates to:
  /// **'Files from it are received without this question. Turn off in Settings > Trusted devices.'**
  String get askAlwaysAllowHelp;

  /// No description provided for @askCodeCheck.
  ///
  /// In en, this message translates to:
  /// **'Optional check: the other screen shows the same code'**
  String get askCodeCheck;

  /// No description provided for @askFilesTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} wants to send you files'**
  String askFilesTitle(String name);

  /// No description provided for @askFromTrusted.
  ///
  /// In en, this message translates to:
  /// **'From trusted {platform} device \"{name}\".'**
  String askFromTrusted(String platform, String name);

  /// No description provided for @askKeyWarning.
  ///
  /// In en, this message translates to:
  /// **'WARNING: a device with this id was paired before with a DIFFERENT key. Accept only if you reinstalled or reset Isekai Drop on it. Accepting replaces the old key.'**
  String get askKeyWarning;

  /// No description provided for @askPairConnect.
  ///
  /// In en, this message translates to:
  /// **'{platform} device \"{name}\" wants to connect.'**
  String askPairConnect(String platform, String name);

  /// No description provided for @askPairHelp.
  ///
  /// In en, this message translates to:
  /// **'Accept to pair: both devices remember each other, so next time files go straight to the usual question. If you did not start this, tap Decline.'**
  String get askPairHelp;

  /// No description provided for @askPairTitle.
  ///
  /// In en, this message translates to:
  /// **'Accept {name}?'**
  String askPairTitle(String name);

  /// No description provided for @askPairWithFiles.
  ///
  /// In en, this message translates to:
  /// **'{platform} device \"{name}\" wants to send you {count} file(s), {size}.'**
  String askPairWithFiles(
    String platform,
    String name,
    String count,
    String size,
  );

  /// No description provided for @askReplaces.
  ///
  /// In en, this message translates to:
  /// **'You paired a device named \"{name}\" before, with a different key. This is probably that device after Isekai Drop was reinstalled or reset on it. Accept only if that is true; accepting replaces the old pairing.'**
  String askReplaces(String name);

  /// No description provided for @askResume.
  ///
  /// In en, this message translates to:
  /// **'Continues an interrupted transfer: {size} are already here.'**
  String askResume(String size);

  /// No description provided for @askTextBody.
  ///
  /// In en, this message translates to:
  /// **'A short text ({count} characters) from {platform} device \"{name}\". It is shown after you accept.'**
  String askTextBody(String count, String platform, String name);

  /// No description provided for @askTextTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} wants to send you a text'**
  String askTextTitle(String name);

  /// No description provided for @autoReceive.
  ///
  /// In en, this message translates to:
  /// **'Auto-receive from verified devices'**
  String get autoReceive;

  /// No description provided for @autoReceiveBody.
  ///
  /// In en, this message translates to:
  /// **'Devices marked \"Verified\" will be able to send files to this device without asking you. Files still go only to the normal receive folder and are still checked for damage. You can turn this off at any time.'**
  String get autoReceiveBody;

  /// No description provided for @autoReceiveInfo.
  ///
  /// In en, this message translates to:
  /// **'Off: you are asked every time (recommended). On: only devices marked \"Verified\" can send without asking. \"Trusted\" and blocked devices are always asked or refused.'**
  String get autoReceiveInfo;

  /// No description provided for @autoReceiveOff.
  ///
  /// In en, this message translates to:
  /// **'Off: you are asked every time (recommended)'**
  String get autoReceiveOff;

  /// No description provided for @autoReceiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Turn on auto-receive?'**
  String get autoReceiveTitle;

  /// No description provided for @benchmarkLog.
  ///
  /// In en, this message translates to:
  /// **'Benchmark log'**
  String get benchmarkLog;

  /// No description provided for @benchmarkSub.
  ///
  /// In en, this message translates to:
  /// **'Measured runs, median/min/max, CSV export'**
  String get benchmarkSub;

  /// No description provided for @blockDevice.
  ///
  /// In en, this message translates to:
  /// **'Block this device'**
  String get blockDevice;

  /// No description provided for @blockedNote.
  ///
  /// In en, this message translates to:
  /// **'Blocked. Unblock it in Settings > Trusted devices.'**
  String get blockedNote;

  /// No description provided for @buildLoading.
  ///
  /// In en, this message translates to:
  /// **'Build: ...'**
  String get buildLoading;

  /// No description provided for @buildLocal.
  ///
  /// In en, this message translates to:
  /// **'Build: local build (not from GitHub)'**
  String get buildLocal;

  /// No description provided for @buildNumber.
  ///
  /// In en, this message translates to:
  /// **'Build {number}'**
  String buildNumber(String number);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @cannotRetry.
  ///
  /// In en, this message translates to:
  /// **'Cannot retry: the device or a file is no longer available.'**
  String get cannotRetry;

  /// No description provided for @chooseFiles.
  ///
  /// In en, this message translates to:
  /// **'Choose files to send'**
  String get chooseFiles;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @clearFinished.
  ///
  /// In en, this message translates to:
  /// **'Clear finished'**
  String get clearFinished;

  /// No description provided for @clearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get clearHistory;

  /// No description provided for @clearHistoryBody.
  ///
  /// In en, this message translates to:
  /// **'All entries will be removed. Your files are not deleted.'**
  String get clearHistoryBody;

  /// No description provided for @clearHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear history?'**
  String get clearHistoryTitle;

  /// No description provided for @clearSelectionBody.
  ///
  /// In en, this message translates to:
  /// **'This removes all files from the list. Your files are not deleted.'**
  String get clearSelectionBody;

  /// No description provided for @clearSelectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear selection?'**
  String get clearSelectionTitle;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @connectDevice.
  ///
  /// In en, this message translates to:
  /// **'Connect a device'**
  String get connectDevice;

  /// No description provided for @connection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get connection;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @continuedEarlier.
  ///
  /// In en, this message translates to:
  /// **'Continued an earlier attempt: {size} were already there.'**
  String continuedEarlier(String size);

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get copyLink;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteEntry.
  ///
  /// In en, this message translates to:
  /// **'Delete entry'**
  String get deleteEntry;

  /// No description provided for @deleteEntryBody.
  ///
  /// In en, this message translates to:
  /// **'Only the history entry is removed. Your files are not deleted.'**
  String get deleteEntryBody;

  /// No description provided for @deleteEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this entry?'**
  String get deleteEntryTitle;

  /// No description provided for @deleteOldNames.
  ///
  /// In en, this message translates to:
  /// **'Delete old names'**
  String get deleteOldNames;

  /// No description provided for @deviceKey.
  ///
  /// In en, this message translates to:
  /// **'Device key: {key}'**
  String deviceKey(String key);

  /// No description provided for @deviceKeySecure.
  ///
  /// In en, this message translates to:
  /// **'Device key: kept in secure storage'**
  String get deviceKeySecure;

  /// No description provided for @deviceName.
  ///
  /// In en, this message translates to:
  /// **'Device name'**
  String get deviceName;

  /// No description provided for @deviceNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name other devices will see'**
  String get deviceNameLabel;

  /// No description provided for @diagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get diagnostics;

  /// No description provided for @diagnosticsSub.
  ///
  /// In en, this message translates to:
  /// **'Connection, link speed, speed test, last error'**
  String get diagnosticsSub;

  /// No description provided for @didNotFinish.
  ///
  /// In en, this message translates to:
  /// **'{count} file(s), {size} - did not finish'**
  String didNotFinish(String count, String size);

  /// No description provided for @discoveryOn.
  ///
  /// In en, this message translates to:
  /// **'on'**
  String get discoveryOn;

  /// No description provided for @discoveryState.
  ///
  /// In en, this message translates to:
  /// **'Discovery: {state}'**
  String discoveryState(String state);

  /// No description provided for @dragFilesHere.
  ///
  /// In en, this message translates to:
  /// **'Drag files here, or'**
  String get dragFilesHere;

  /// No description provided for @encryptionNote.
  ///
  /// In en, this message translates to:
  /// **'Encryption: TLS 1.3 with both devices\' keys checked.'**
  String get encryptionNote;

  /// No description provided for @engineVersion.
  ///
  /// In en, this message translates to:
  /// **'Engine: {version}'**
  String engineVersion(String version);

  /// No description provided for @filesAndSize.
  ///
  /// In en, this message translates to:
  /// **'{count} file(s) · {size}'**
  String filesAndSize(String count, String size);

  /// No description provided for @folderNotOpened.
  ///
  /// In en, this message translates to:
  /// **'The folder could not be opened.'**
  String get folderNotOpened;

  /// No description provided for @folderPickFailed.
  ///
  /// In en, this message translates to:
  /// **'The folder could not be opened here. Try picking files instead.'**
  String get folderPickFailed;

  /// No description provided for @fromName.
  ///
  /// In en, this message translates to:
  /// **'From {name}'**
  String fromName(String name);

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get getStarted;

  /// No description provided for @helpGuides.
  ///
  /// In en, this message translates to:
  /// **'Help & guides'**
  String get helpGuides;

  /// No description provided for @helpGuidesSub.
  ///
  /// In en, this message translates to:
  /// **'Hotspot, permissions, troubleshooting'**
  String get helpGuidesSub;

  /// No description provided for @historyEntries.
  ///
  /// In en, this message translates to:
  /// **'History entries: {count}'**
  String historyEntries(String count);

  /// No description provided for @historyLine.
  ///
  /// In en, this message translates to:
  /// **'{outcome} - {count} file(s), {size}'**
  String historyLine(String outcome, String count, String size);

  /// No description provided for @historyNoteNames.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device only. File contents are never stored; file names are (turn off in Settings).'**
  String get historyNoteNames;

  /// No description provided for @historyNoteNoNames.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device only. File contents are never stored; file names are not saved.'**
  String get historyNoteNoNames;

  /// No description provided for @historyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'History is not available'**
  String get historyUnavailable;

  /// No description provided for @historyUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'This device could not open its history file.'**
  String get historyUnavailableBody;

  /// No description provided for @homeFooter.
  ///
  /// In en, this message translates to:
  /// **'Files go directly between your devices, encrypted. Nothing is uploaded.'**
  String get homeFooter;

  /// No description provided for @homeReadyHelp.
  ///
  /// In en, this message translates to:
  /// **'Keep Isekai Drop open to receive. You will always be asked first.'**
  String get homeReadyHelp;

  /// No description provided for @howToUpdate.
  ///
  /// In en, this message translates to:
  /// **'How to update'**
  String get howToUpdate;

  /// No description provided for @interruptedSends.
  ///
  /// In en, this message translates to:
  /// **'Interrupted sends'**
  String get interruptedSends;

  /// No description provided for @jobProgress.
  ///
  /// In en, this message translates to:
  /// **'{status} - {percent}% of {size}'**
  String jobProgress(String status, String percent, String size);

  /// No description provided for @keepOldNames.
  ///
  /// In en, this message translates to:
  /// **'Keep old names'**
  String get keepOldNames;

  /// No description provided for @keyHelp.
  ///
  /// In en, this message translates to:
  /// **'Your other devices know this device by this key. It changes only if the app is reinstalled or reset.'**
  String get keyHelp;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageNote.
  ///
  /// In en, this message translates to:
  /// **'Hindi and Kannada are machine/assistant translations and have not been checked by a native speaker yet.'**
  String get languageNote;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'Same as device'**
  String get languageSystem;

  /// No description provided for @latestTestBuild.
  ///
  /// In en, this message translates to:
  /// **'Latest test build'**
  String get latestTestBuild;

  /// No description provided for @licences.
  ///
  /// In en, this message translates to:
  /// **'Licences'**
  String get licences;

  /// No description provided for @licencesSub.
  ///
  /// In en, this message translates to:
  /// **'Full licence texts of included software'**
  String get licencesSub;

  /// No description provided for @licencesTitle.
  ///
  /// In en, this message translates to:
  /// **'Open-source licences'**
  String get licencesTitle;

  /// No description provided for @manage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get manage;

  /// No description provided for @modeFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get modeFiles;

  /// No description provided for @modeText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get modeText;

  /// No description provided for @moved.
  ///
  /// In en, this message translates to:
  /// **'Moved: {size}'**
  String moved(String size);

  /// No description provided for @nameNearby.
  ///
  /// In en, this message translates to:
  /// **'{name}  (nearby)'**
  String nameNearby(String name);

  /// No description provided for @nameNearbyAsk.
  ///
  /// In en, this message translates to:
  /// **'{name}  (nearby, asks once to accept)'**
  String nameNearbyAsk(String name);

  /// No description provided for @navConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get navConnect;

  /// No description provided for @navHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navHistory;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get navSend;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @nearbyDevices.
  ///
  /// In en, this message translates to:
  /// **'Nearby devices'**
  String get nearbyDevices;

  /// No description provided for @nearbySeen.
  ///
  /// In en, this message translates to:
  /// **'Nearby devices seen: {count}'**
  String nearbySeen(String count);

  /// No description provided for @needsPairingAgain.
  ///
  /// In en, this message translates to:
  /// **'Needs pairing again'**
  String get needsPairingAgain;

  /// No description provided for @newKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'This device has a new key'**
  String get newKeyTitle;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @noAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Isekai Drop itself has no analytics, no cloud, no crash reporting. On Android the QR scanner (Google ML Kit) sends Google its own usage metrics - see Privacy.'**
  String get noAnalytics;

  /// No description provided for @noTransfers.
  ///
  /// In en, this message translates to:
  /// **'No transfers yet'**
  String get noTransfers;

  /// No description provided for @noTransfersInfo.
  ///
  /// In en, this message translates to:
  /// **'Finished transfers will be listed here.'**
  String get noTransfersInfo;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @notReady.
  ///
  /// In en, this message translates to:
  /// **'Not ready'**
  String get notReady;

  /// No description provided for @notRunning.
  ///
  /// In en, this message translates to:
  /// **'not running'**
  String get notRunning;

  /// No description provided for @notifBody.
  ///
  /// In en, this message translates to:
  /// **'Isekai Drop shows how far a transfer is, and asks you about incoming files, in a notification. Then transfers keep going when you switch to another app. No file names or device names are shown.'**
  String get notifBody;

  /// No description provided for @notifTitle.
  ///
  /// In en, this message translates to:
  /// **'Show transfer notifications?'**
  String get notifTitle;

  /// No description provided for @openInBrowser.
  ///
  /// In en, this message translates to:
  /// **'Open in browser'**
  String get openInBrowser;

  /// No description provided for @openLink.
  ///
  /// In en, this message translates to:
  /// **'Open link'**
  String get openLink;

  /// No description provided for @openSource.
  ///
  /// In en, this message translates to:
  /// **'Open-source software'**
  String get openSource;

  /// No description provided for @opening.
  ///
  /// In en, this message translates to:
  /// **'Opening...'**
  String get opening;

  /// No description provided for @outcomeCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get outcomeCancelled;

  /// No description provided for @outcomeCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get outcomeCompleted;

  /// No description provided for @outcomeFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get outcomeFailed;

  /// No description provided for @pairAgain.
  ///
  /// In en, this message translates to:
  /// **'Pair again'**
  String get pairAgain;

  /// No description provided for @pickFiles.
  ///
  /// In en, this message translates to:
  /// **'Pick files'**
  String get pickFiles;

  /// No description provided for @pickFolder.
  ///
  /// In en, this message translates to:
  /// **'Pick a folder'**
  String get pickFolder;

  /// No description provided for @pickerFailed.
  ///
  /// In en, this message translates to:
  /// **'The file picker could not open. Please try again.'**
  String get pickerFailed;

  /// No description provided for @ready.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get ready;

  /// No description provided for @receiveTrusted.
  ///
  /// In en, this message translates to:
  /// **'Receive files from trusted devices'**
  String get receiveTrusted;

  /// No description provided for @receiveTrustedInfo.
  ///
  /// In en, this message translates to:
  /// **'When off, every offer is declined. Unknown devices can never send; they must pair first.'**
  String get receiveTrustedInfo;

  /// No description provided for @receiveTrustedOff.
  ///
  /// In en, this message translates to:
  /// **'Off: every offer is declined'**
  String get receiveTrustedOff;

  /// No description provided for @receivedFrom.
  ///
  /// In en, this message translates to:
  /// **'Received from {name}'**
  String receivedFrom(String name);

  /// No description provided for @receivedGoTo.
  ///
  /// In en, this message translates to:
  /// **'Received files go to: {place}'**
  String receivedGoTo(String place);

  /// No description provided for @receiving.
  ///
  /// In en, this message translates to:
  /// **'Receiving'**
  String get receiving;

  /// No description provided for @receivingPort.
  ///
  /// In en, this message translates to:
  /// **'Receiving on port: {port}'**
  String receivingPort(String port);

  /// No description provided for @rejectedPeerBody.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" tried to connect, but with a different key than \"{paired}\" had when you paired. Most likely Isekai Drop was reinstalled or reset on it. This device refused it. Pair again only if that is true.'**
  String rejectedPeerBody(String name, String paired);

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @removeFromList.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from list'**
  String removeFromList(String name);

  /// No description provided for @removeSendBody.
  ///
  /// In en, this message translates to:
  /// **'It will no longer be offered for retry. Your files are not deleted.'**
  String get removeSendBody;

  /// No description provided for @removeSendTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this send?'**
  String get removeSendTitle;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @requestExpired.
  ///
  /// In en, this message translates to:
  /// **'Request expired - nobody answered in time.'**
  String get requestExpired;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saveNames.
  ///
  /// In en, this message translates to:
  /// **'Save file names in History'**
  String get saveNames;

  /// No description provided for @saveNamesInfo.
  ///
  /// In en, this message translates to:
  /// **'Names are kept on this device only and never written to logs. File contents are never saved.'**
  String get saveNamesInfo;

  /// No description provided for @saveNamesSummary.
  ///
  /// In en, this message translates to:
  /// **'Kept on this device only'**
  String get saveNamesSummary;

  /// No description provided for @savedTo.
  ///
  /// In en, this message translates to:
  /// **'Saved to: {place}'**
  String savedTo(String place);

  /// No description provided for @savedTrusted.
  ///
  /// In en, this message translates to:
  /// **'Saved trusted devices'**
  String get savedTrusted;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @sendFilesTo.
  ///
  /// In en, this message translates to:
  /// **'Send {count} file(s) to {name}'**
  String sendFilesTo(String count, String name);

  /// No description provided for @sendText.
  ///
  /// In en, this message translates to:
  /// **'Send text'**
  String get sendText;

  /// No description provided for @sendTextTo.
  ///
  /// In en, this message translates to:
  /// **'Send text to {name}'**
  String sendTextTo(String name);

  /// No description provided for @sendToName.
  ///
  /// In en, this message translates to:
  /// **'Send to {name}'**
  String sendToName(String name);

  /// No description provided for @sentTo.
  ///
  /// In en, this message translates to:
  /// **'Sent to {name}'**
  String sentTo(String name);

  /// No description provided for @sharedFromApp.
  ///
  /// In en, this message translates to:
  /// **'Shared from another app'**
  String get sharedFromApp;

  /// No description provided for @shortKey.
  ///
  /// In en, this message translates to:
  /// **'Short: {key}'**
  String shortKey(String key);

  /// No description provided for @showFolder.
  ///
  /// In en, this message translates to:
  /// **'Show folder'**
  String get showFolder;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @slide1Text.
  ///
  /// In en, this message translates to:
  /// **'Phones and PCs. No account and no cloud.'**
  String get slide1Text;

  /// No description provided for @slide1Title.
  ///
  /// In en, this message translates to:
  /// **'Open Isekai Drop on both devices'**
  String get slide1Title;

  /// No description provided for @slide2Text.
  ///
  /// In en, this message translates to:
  /// **'Both devices on one network (or one shares a hotspot). The first time, connect them once with a QR code.'**
  String get slide2Text;

  /// No description provided for @slide2Title.
  ///
  /// In en, this message translates to:
  /// **'Use the same Wi-Fi'**
  String get slide2Title;

  /// No description provided for @slide3Text.
  ///
  /// In en, this message translates to:
  /// **'Files go straight between your devices, encrypted and checked.'**
  String get slide3Text;

  /// No description provided for @slide3Title.
  ///
  /// In en, this message translates to:
  /// **'Pick files and send'**
  String get slide3Title;

  /// No description provided for @starting.
  ///
  /// In en, this message translates to:
  /// **'Starting...'**
  String get starting;

  /// No description provided for @stepFilesCount.
  ///
  /// In en, this message translates to:
  /// **'1. Files: {count}, {size}'**
  String stepFilesCount(String count, String size);

  /// No description provided for @stepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String stepOf(String step, String total);

  /// No description provided for @stepPickDevice.
  ///
  /// In en, this message translates to:
  /// **'2. Pick a device'**
  String get stepPickDevice;

  /// No description provided for @stepPickFiles.
  ///
  /// In en, this message translates to:
  /// **'1. Pick files'**
  String get stepPickFiles;

  /// No description provided for @stepTextOrLink.
  ///
  /// In en, this message translates to:
  /// **'1. Text or link'**
  String get stepTextOrLink;

  /// No description provided for @stopNamesBody.
  ///
  /// In en, this message translates to:
  /// **'New history entries will not contain file names. Do you also want to delete the names already saved?'**
  String get stopNamesBody;

  /// No description provided for @stopNamesTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop saving file names?'**
  String get stopNamesTitle;

  /// No description provided for @testBuildNote.
  ///
  /// In en, this message translates to:
  /// **'A test build, not a public release.'**
  String get testBuildNote;

  /// No description provided for @textAskNote.
  ///
  /// In en, this message translates to:
  /// **'The other device asks before showing it. Links are never opened by themselves.'**
  String get textAskNote;

  /// No description provided for @textErrDeclined.
  ///
  /// In en, this message translates to:
  /// **'The other device declined the text.'**
  String get textErrDeclined;

  /// No description provided for @textErrEmpty.
  ///
  /// In en, this message translates to:
  /// **'Type a text first.'**
  String get textErrEmpty;

  /// No description provided for @textErrExpired.
  ///
  /// In en, this message translates to:
  /// **'Nobody answered on the other device.'**
  String get textErrExpired;

  /// No description provided for @textErrFailed.
  ///
  /// In en, this message translates to:
  /// **'The text could not be sent. Please try again.'**
  String get textErrFailed;

  /// No description provided for @textErrNoAddress.
  ///
  /// In en, this message translates to:
  /// **'The other device was not found. Make sure it is on the same network with Isekai Drop open.'**
  String get textErrNoAddress;

  /// No description provided for @textErrNotTrusted.
  ///
  /// In en, this message translates to:
  /// **'The other device does not trust this device any more. Pair again.'**
  String get textErrNotTrusted;

  /// No description provided for @textErrOldPeer.
  ///
  /// In en, this message translates to:
  /// **'The other device has an older Isekai Drop that cannot receive text. Update the other app.'**
  String get textErrOldPeer;

  /// No description provided for @textErrTooLong.
  ///
  /// In en, this message translates to:
  /// **'The text is too long. Up to 8 KB (about 8000 letters) can be sent.'**
  String get textErrTooLong;

  /// No description provided for @textFrom.
  ///
  /// In en, this message translates to:
  /// **'Text from {name}'**
  String textFrom(String name);

  /// No description provided for @textHint.
  ///
  /// In en, this message translates to:
  /// **'Type or paste a text or link'**
  String get textHint;

  /// No description provided for @textPairedOnly.
  ///
  /// In en, this message translates to:
  /// **'Text can be sent to paired devices only. Pair first (send a file, or use Connect).'**
  String get textPairedOnly;

  /// No description provided for @textSentTo.
  ///
  /// In en, this message translates to:
  /// **'Text sent to {name}.'**
  String textSentTo(String name);

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @thisDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get thisDevice;

  /// No description provided for @thisDeviceKey.
  ///
  /// In en, this message translates to:
  /// **'This device\'s key'**
  String get thisDeviceKey;

  /// No description provided for @toName.
  ///
  /// In en, this message translates to:
  /// **'To {name}'**
  String toName(String name);

  /// No description provided for @transfersThisSession.
  ///
  /// In en, this message translates to:
  /// **'Transfers this session'**
  String get transfersThisSession;

  /// No description provided for @trustedCount.
  ///
  /// In en, this message translates to:
  /// **'Trusted devices: {count}'**
  String trustedCount(String count);

  /// No description provided for @trustedDevices.
  ///
  /// In en, this message translates to:
  /// **'Trusted devices'**
  String get trustedDevices;

  /// No description provided for @trustedDevicesSub.
  ///
  /// In en, this message translates to:
  /// **'Check codes, rename, revoke or remove'**
  String get trustedDevicesSub;

  /// No description provided for @turnOn.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get turnOn;

  /// No description provided for @unavailable.
  ///
  /// In en, this message translates to:
  /// **'unavailable'**
  String get unavailable;

  /// No description provided for @updateAndroid.
  ///
  /// In en, this message translates to:
  /// **'Android: open the link above, download isekai-drop-android-arm64.apk (or -universal.apk) and install it over this app. Your paired devices and history stay.'**
  String get updateAndroid;

  /// No description provided for @updateBoth.
  ///
  /// In en, this message translates to:
  /// **'Update both devices: devices with very different versions may not understand each other.'**
  String get updateBoth;

  /// No description provided for @updateIos.
  ///
  /// In en, this message translates to:
  /// **'iPhone/iPad: sign the new .ipa again with your own Apple ID (NOT TESTED).'**
  String get updateIos;

  /// No description provided for @updateMac.
  ///
  /// In en, this message translates to:
  /// **'Mac: download isekai-drop-macos.dmg and drag the app to Applications (NOT TESTED on a Mac).'**
  String get updateMac;

  /// No description provided for @updateWindows.
  ///
  /// In en, this message translates to:
  /// **'Windows: download isekai-drop-windows-setup.exe and run it.'**
  String get updateWindows;

  /// No description provided for @versionTitle.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get versionTitle;

  /// No description provided for @visible.
  ///
  /// In en, this message translates to:
  /// **'Visible to nearby devices'**
  String get visible;

  /// No description provided for @visibleInfo.
  ///
  /// In en, this message translates to:
  /// **'Off: this device stops announcing itself (and stops Bonjour). Paired devices and QR/typed-address connections still work.'**
  String get visibleInfo;

  /// No description provided for @visibleSummary.
  ///
  /// In en, this message translates to:
  /// **'Others on your Wi-Fi can find this device'**
  String get visibleSummary;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi', 'kn'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'kn':
      return AppLocalizationsKn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
