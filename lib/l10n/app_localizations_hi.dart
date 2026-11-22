// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get aboutApp => 'Isekai Drop के बारे में';

  @override
  String aboutSubtitle(String version) {
    return 'Isekai Drop $version - बिल्ड, कुंजी, अपडेट, लाइसेंस';
  }

  @override
  String get aboutThisDevice => 'इस डिवाइस के बारे में';

  @override
  String get aboutTitle => 'जानकारी';

  @override
  String get accept => 'स्वीकार करें';

  @override
  String get addedToQueue =>
      'कतार में जोड़ा गया। अभी का भेजना पूरा होने पर शुरू होगा।';

  @override
  String get advanced => 'उन्नत';

  @override
  String andMore(String count) {
    return '...और $count';
  }

  @override
  String get anyFilesIos =>
      'किसी भी तरह की फ़ाइलें। iPhone/iPad पर अभी फ़ोल्डर नहीं चुन सकते - अंदर की फ़ाइलें चुनें।';

  @override
  String get anyFilesOrFolder =>
      'किसी भी तरह की फ़ाइलें, या पूरा फ़ोल्डर (अंदर के फ़ोल्डर भी रहते हैं)।';

  @override
  String get appTitle => 'Isekai Drop';

  @override
  String appVersion(String version) {
    return 'Isekai Drop $version';
  }

  @override
  String get appearance => 'दिखावट';

  @override
  String get askAlwaysAllow => 'इस डिवाइस को हमेशा अनुमति दें';

  @override
  String get askAlwaysAllowHelp =>
      'इससे फ़ाइलें बिना यह सवाल पूछे आएँगी। सेटिंग्स > भरोसेमंद डिवाइस में बंद करें।';

  @override
  String get askCodeCheck => 'वैकल्पिक जाँच: दूसरी स्क्रीन पर यही कोड दिखता है';

  @override
  String askFilesTitle(String name) {
    return '$name आपको फ़ाइलें भेजना चाहता है';
  }

  @override
  String askFromTrusted(String platform, String name) {
    return 'भरोसेमंद $platform डिवाइस \"$name\" से।';
  }

  @override
  String get askKeyWarning =>
      'चेतावनी: इस आईडी वाला डिवाइस पहले किसी अलग कुंजी के साथ जोड़ा गया था। तभी स्वीकार करें जब आपने उस पर Isekai Drop दोबारा इंस्टॉल या रीसेट किया हो। स्वीकार करने से पुरानी कुंजी बदल जाएगी।';

  @override
  String askPairConnect(String platform, String name) {
    return '$platform डिवाइस \"$name\" जुड़ना चाहता है।';
  }

  @override
  String get askPairHelp =>
      'जोड़ने के लिए स्वीकार करें: दोनों डिवाइस एक-दूसरे को याद रखेंगे, अगली बार सीधे सामान्य सवाल आएगा। अगर आपने यह शुरू नहीं किया, तो मना करें दबाएँ।';

  @override
  String askPairTitle(String name) {
    return '$name को स्वीकार करें?';
  }

  @override
  String askPairWithFiles(
    String platform,
    String name,
    String count,
    String size,
  ) {
    return '$platform डिवाइस \"$name\" आपको $count फ़ाइल(ें), $size भेजना चाहता है।';
  }

  @override
  String askReplaces(String name) {
    return 'आपने पहले \"$name\" नाम का डिवाइस किसी दूसरी कुंजी के साथ जोड़ा था। शायद उस पर Isekai Drop दोबारा इंस्टॉल या रीसेट हुआ है। तभी स्वीकार करें जब यह सच हो; स्वीकार करने से पुराना जोड़ बदल जाएगा।';
  }

  @override
  String askResume(String size) {
    return 'रुका हुआ ट्रांसफ़र जारी है: $size पहले से यहाँ है।';
  }

  @override
  String askTextBody(String count, String platform, String name) {
    return '$platform डिवाइस \"$name\" से एक छोटा टेक्स्ट ($count अक्षर)। स्वीकार करने के बाद दिखेगा।';
  }

  @override
  String askTextTitle(String name) {
    return '$name आपको एक टेक्स्ट भेजना चाहता है';
  }

  @override
  String get autoReceive => 'सत्यापित डिवाइस से अपने-आप पाएँ';

  @override
  String get autoReceiveBody =>
      '\"सत्यापित\" डिवाइस आपसे पूछे बिना इस डिवाइस पर फ़ाइलें भेज सकेंगे। फ़ाइलें फिर भी सामान्य फ़ोल्डर में ही जाएँगी और ख़राबी के लिए जाँची जाएँगी। आप इसे कभी भी बंद कर सकते हैं।';

  @override
  String get autoReceiveInfo =>
      'बंद: हर बार आपसे पूछा जाएगा (सुझाया गया)। चालू: सिर्फ़ \"सत्यापित\" डिवाइस बिना पूछे भेज सकते हैं। \"भरोसेमंद\" के लिए हमेशा पूछा जाता है और ब्लॉक किए गए डिवाइस हमेशा मना होते हैं।';

  @override
  String get autoReceiveOff => 'बंद: हर बार आपसे पूछा जाएगा (सुझाया गया)';

  @override
  String get autoReceiveTitle => 'अपने-आप पाना चालू करें?';

  @override
  String get benchmarkLog => 'बेंचमार्क लॉग';

  @override
  String get benchmarkSub => 'मापे गए रन, मीडियन/न्यूनतम/अधिकतम, CSV एक्सपोर्ट';

  @override
  String get blockDevice => 'इस डिवाइस को ब्लॉक करें';

  @override
  String get blockedNote =>
      'ब्लॉक किया गया। सेटिंग्स > भरोसेमंद डिवाइस में अनब्लॉक करें।';

  @override
  String get buildLoading => 'बिल्ड: ...';

  @override
  String get buildLocal => 'बिल्ड: लोकल बिल्ड (GitHub से नहीं)';

  @override
  String buildNumber(String number) {
    return 'बिल्ड $number';
  }

  @override
  String get cancel => 'रद्द करें';

  @override
  String get cannotRetry =>
      'दोबारा नहीं हो सकता: डिवाइस या कोई फ़ाइल अब उपलब्ध नहीं है।';

  @override
  String get chooseFiles => 'भेजने के लिए फ़ाइलें चुनें';

  @override
  String get clear => 'हटाएँ';

  @override
  String get clearFinished => 'पूरे हुए हटाएँ';

  @override
  String get clearHistory => 'इतिहास साफ़ करें';

  @override
  String get clearHistoryBody =>
      'सभी एंट्री हट जाएँगी। आपकी फ़ाइलें नहीं मिटेंगी।';

  @override
  String get clearHistoryTitle => 'इतिहास साफ़ करें?';

  @override
  String get clearSelectionBody =>
      'इससे सूची से सभी फ़ाइलें हट जाएँगी। आपकी फ़ाइलें नहीं मिटेंगी।';

  @override
  String get clearSelectionTitle => 'चुनी हुई फ़ाइलें हटाएँ?';

  @override
  String get close => 'बंद करें';

  @override
  String get connectDevice => 'डिवाइस जोड़ें';

  @override
  String get connection => 'कनेक्शन';

  @override
  String get continueLabel => 'जारी रखें';

  @override
  String continuedEarlier(String size) {
    return 'पिछली कोशिश से जारी: $size पहले से था।';
  }

  @override
  String get copied => 'कॉपी हो गया';

  @override
  String get copy => 'कॉपी करें';

  @override
  String get copyLink => 'लिंक कॉपी करें';

  @override
  String get decline => 'मना करें';

  @override
  String get delete => 'मिटाएँ';

  @override
  String get deleteEntry => 'एंट्री मिटाएँ';

  @override
  String get deleteEntryBody =>
      'सिर्फ़ इतिहास की एंट्री हटेगी। आपकी फ़ाइलें नहीं मिटेंगी।';

  @override
  String get deleteEntryTitle => 'यह एंट्री मिटाएँ?';

  @override
  String get deleteOldNames => 'पुराने नाम मिटाएँ';

  @override
  String deviceKey(String key) {
    return 'डिवाइस कुंजी: $key';
  }

  @override
  String get deviceKeySecure => 'डिवाइस कुंजी: सुरक्षित स्टोरेज में रखी है';

  @override
  String get deviceName => 'डिवाइस का नाम';

  @override
  String get deviceNameLabel => 'दूसरे डिवाइस को दिखने वाला नाम';

  @override
  String get diagnostics => 'जाँच जानकारी';

  @override
  String get diagnosticsSub =>
      'कनेक्शन, लिंक स्पीड, स्पीड टेस्ट, आख़िरी गड़बड़ी';

  @override
  String didNotFinish(String count, String size) {
    return '$count फ़ाइल(ें), $size - पूरा नहीं हुआ';
  }

  @override
  String get discoveryOn => 'चालू';

  @override
  String discoveryState(String state) {
    return 'खोज: $state';
  }

  @override
  String get dragFilesHere => 'फ़ाइलें यहाँ खींचें, या';

  @override
  String get encryptionNote =>
      'एन्क्रिप्शन: TLS 1.3, दोनों डिवाइस की कुंजियाँ जाँची जाती हैं।';

  @override
  String engineVersion(String version) {
    return 'इंजन: $version';
  }

  @override
  String filesAndSize(String count, String size) {
    return '$count फ़ाइल(ें) · $size';
  }

  @override
  String get folderNotOpened => 'फ़ोल्डर नहीं खुल सका।';

  @override
  String get folderPickFailed =>
      'फ़ोल्डर यहाँ नहीं खुल सका। इसके बजाय फ़ाइलें चुनकर देखें।';

  @override
  String fromName(String name) {
    return '$name से';
  }

  @override
  String get getStarted => 'शुरू करें';

  @override
  String get helpGuides => 'मदद और गाइड';

  @override
  String get helpGuidesSub => 'हॉटस्पॉट, अनुमतियाँ, समस्या हल करना';

  @override
  String historyEntries(String count) {
    return 'इतिहास एंट्री: $count';
  }

  @override
  String historyLine(String outcome, String count, String size) {
    return '$outcome - $count फ़ाइल(ें), $size';
  }

  @override
  String get historyNoteNames =>
      'सिर्फ़ इसी डिवाइस पर सहेजा गया। फ़ाइलों की सामग्री कभी नहीं रखी जाती; फ़ाइलों के नाम रखे जाते हैं (सेटिंग्स में बंद करें)।';

  @override
  String get historyNoteNoNames =>
      'सिर्फ़ इसी डिवाइस पर सहेजा गया। फ़ाइलों की सामग्री कभी नहीं रखी जाती; फ़ाइलों के नाम नहीं रखे जाते।';

  @override
  String get historyUnavailable => 'इतिहास उपलब्ध नहीं है';

  @override
  String get historyUnavailableBody =>
      'यह डिवाइस अपनी इतिहास फ़ाइल नहीं खोल सका।';

  @override
  String get homeFooter =>
      'फ़ाइलें सीधे आपके डिवाइसों के बीच एन्क्रिप्टेड जाती हैं। कुछ भी अपलोड नहीं होता।';

  @override
  String get homeReadyHelp =>
      'पाने के लिए Isekai Drop खुला रखें। आपसे हमेशा पहले पूछा जाएगा।';

  @override
  String get howToUpdate => 'अपडेट कैसे करें';

  @override
  String get interruptedSends => 'रुके हुए भेजे गए';

  @override
  String jobProgress(String status, String percent, String size) {
    return '$status - $size का $percent%';
  }

  @override
  String get keepOldNames => 'पुराने नाम रखें';

  @override
  String get keyHelp =>
      'आपके दूसरे डिवाइस इस डिवाइस को इसी कुंजी से पहचानते हैं। यह तभी बदलती है जब ऐप दोबारा इंस्टॉल या रीसेट हो।';

  @override
  String get language => 'भाषा';

  @override
  String get languageNote =>
      'हिन्दी और कन्नड़ मशीन/सहायक अनुवाद हैं; अभी किसी मूल भाषी ने इन्हें नहीं जाँचा है।';

  @override
  String get languageSystem => 'डिवाइस जैसी';

  @override
  String get latestTestBuild => 'नया टेस्ट बिल्ड';

  @override
  String get licences => 'लाइसेंस';

  @override
  String get licencesSub => 'शामिल सॉफ़्टवेयर के पूरे लाइसेंस';

  @override
  String get licencesTitle => 'ओपन-सोर्स लाइसेंस';

  @override
  String get manage => 'प्रबंधित करें';

  @override
  String get modeFiles => 'फ़ाइलें';

  @override
  String get modeText => 'टेक्स्ट';

  @override
  String moved(String size) {
    return 'भेजा गया: $size';
  }

  @override
  String nameNearby(String name) {
    return '$name  (पास में)';
  }

  @override
  String nameNearbyAsk(String name) {
    return '$name  (पास में, एक बार स्वीकार करने को पूछेगा)';
  }

  @override
  String get navConnect => 'जोड़ें';

  @override
  String get navHistory => 'इतिहास';

  @override
  String get navHome => 'होम';

  @override
  String get navSend => 'भेजें';

  @override
  String get navSettings => 'सेटिंग्स';

  @override
  String get nearbyDevices => 'पास के डिवाइस';

  @override
  String nearbySeen(String count) {
    return 'दिखे पास के डिवाइस: $count';
  }

  @override
  String get needsPairingAgain => 'फिर से जोड़ना होगा';

  @override
  String get newKeyTitle => 'इस डिवाइस की नई कुंजी है';

  @override
  String get next => 'आगे';

  @override
  String get noAnalytics =>
      'Isekai Drop में खुद कोई एनालिटिक्स, क्लाउड या क्रैश रिपोर्टिंग नहीं है। Android पर QR स्कैनर (Google ML Kit) Google को अपने इस्तेमाल के आँकड़े भेजता है - Privacy देखें।';

  @override
  String get noTransfers => 'अभी तक कोई ट्रांसफ़र नहीं';

  @override
  String get noTransfersInfo => 'पूरे हुए ट्रांसफ़र यहाँ दिखेंगे।';

  @override
  String get notNow => 'अभी नहीं';

  @override
  String get notReady => 'तैयार नहीं';

  @override
  String get notRunning => 'नहीं चल रहा';

  @override
  String get notifBody =>
      'Isekai Drop सूचना में दिखाता है कि ट्रांसफ़र कितना हुआ, और आने वाली फ़ाइलों के बारे में पूछता है। फिर दूसरा ऐप खोलने पर भी ट्रांसफ़र चलता रहता है। फ़ाइल या डिवाइस के नाम नहीं दिखाए जाते।';

  @override
  String get notifTitle => 'ट्रांसफ़र की सूचनाएँ दिखाएँ?';

  @override
  String get openInBrowser => 'ब्राउज़र में खोलें';

  @override
  String get openLink => 'लिंक खोलें';

  @override
  String get openSource => 'ओपन-सोर्स सॉफ़्टवेयर';

  @override
  String get opening => 'खुल रहा है...';

  @override
  String get outcomeCancelled => 'रद्द हुआ';

  @override
  String get outcomeCompleted => 'पूरा हुआ';

  @override
  String get outcomeFailed => 'विफल';

  @override
  String get pairAgain => 'फिर से जोड़ें';

  @override
  String get pickFiles => 'फ़ाइलें चुनें';

  @override
  String get pickFolder => 'फ़ोल्डर चुनें';

  @override
  String get pickerFailed =>
      'फ़ाइल चुनने वाला नहीं खुल सका। फिर से कोशिश करें।';

  @override
  String get ready => 'तैयार';

  @override
  String get receiveTrusted => 'भरोसेमंद डिवाइस से फ़ाइलें पाएँ';

  @override
  String get receiveTrustedInfo =>
      'बंद होने पर हर फ़ाइल मना होगी। अनजान डिवाइस कभी नहीं भेज सकते; उन्हें पहले जुड़ना होगा।';

  @override
  String get receiveTrustedOff => 'बंद: हर फ़ाइल मना होगी';

  @override
  String receivedFrom(String name) {
    return '$name से मिला';
  }

  @override
  String receivedGoTo(String place) {
    return 'मिली फ़ाइलें यहाँ जाती हैं: $place';
  }

  @override
  String get receiving => 'पाना';

  @override
  String receivingPort(String port) {
    return 'इस पोर्ट पर पा रहा है: $port';
  }

  @override
  String rejectedPeerBody(String name, String paired) {
    return '\"$name\" ने जुड़ने की कोशिश की, पर जोड़ते समय \"$paired\" की जो कुंजी थी उससे अलग कुंजी के साथ। शायद उस पर Isekai Drop दोबारा इंस्टॉल या रीसेट हुआ। इस डिवाइस ने मना कर दिया। यह सच हो तभी फिर से जोड़ें।';
  }

  @override
  String get remove => 'हटाएँ';

  @override
  String removeFromList(String name) {
    return '$name को सूची से हटाएँ';
  }

  @override
  String get removeSendBody =>
      'यह अब दोबारा कोशिश के लिए नहीं दिखेगा। आपकी फ़ाइलें नहीं मिटेंगी।';

  @override
  String get removeSendTitle => 'यह भेजना हटाएँ?';

  @override
  String get rename => 'नाम बदलें';

  @override
  String get requestExpired =>
      'अनुरोध की समय-सीमा खत्म - समय पर किसी ने जवाब नहीं दिया।';

  @override
  String get retry => 'फिर से कोशिश करें';

  @override
  String get save => 'सहेजें';

  @override
  String get saveNames => 'इतिहास में फ़ाइलों के नाम सहेजें';

  @override
  String get saveNamesInfo =>
      'नाम सिर्फ़ इसी डिवाइस पर रखे जाते हैं और लॉग में कभी नहीं लिखे जाते। फ़ाइलों की सामग्री कभी नहीं सहेजी जाती।';

  @override
  String get saveNamesSummary => 'सिर्फ़ इसी डिवाइस पर रखा जाता है';

  @override
  String savedTo(String place) {
    return 'यहाँ सहेजा: $place';
  }

  @override
  String get savedTrusted => 'सहेजे गए भरोसेमंद डिवाइस';

  @override
  String get security => 'सुरक्षा';

  @override
  String sendFilesTo(String count, String name) {
    return '$name को $count फ़ाइल(ें) भेजें';
  }

  @override
  String get sendText => 'टेक्स्ट भेजें';

  @override
  String sendTextTo(String name) {
    return '$name को टेक्स्ट भेजें';
  }

  @override
  String sendToName(String name) {
    return '$name को भेजें';
  }

  @override
  String sentTo(String name) {
    return '$name को भेजा';
  }

  @override
  String get sharedFromApp => 'दूसरे ऐप से शेयर किया गया';

  @override
  String shortKey(String key) {
    return 'छोटा रूप: $key';
  }

  @override
  String get showFolder => 'फ़ोल्डर दिखाएँ';

  @override
  String get skip => 'छोड़ें';

  @override
  String get slide1Text => 'फ़ोन और पीसी। कोई खाता नहीं, कोई क्लाउड नहीं।';

  @override
  String get slide1Title => 'दोनों डिवाइस पर Isekai Drop खोलें';

  @override
  String get slide2Text =>
      'दोनों डिवाइस एक ही नेटवर्क पर हों (या एक हॉटस्पॉट चालू करे)। पहली बार QR कोड से एक बार जोड़ें।';

  @override
  String get slide2Title => 'एक ही वाई-फ़ाई इस्तेमाल करें';

  @override
  String get slide3Text =>
      'फ़ाइलें सीधे आपके डिवाइसों के बीच जाती हैं, एन्क्रिप्टेड और जाँची हुई।';

  @override
  String get slide3Title => 'फ़ाइलें चुनें और भेजें';

  @override
  String get starting => 'शुरू हो रहा है...';

  @override
  String stepFilesCount(String count, String size) {
    return '1. फ़ाइलें: $count, $size';
  }

  @override
  String stepOf(String step, String total) {
    return 'चरण $step / $total';
  }

  @override
  String get stepPickDevice => '2. डिवाइस चुनें';

  @override
  String get stepPickFiles => '1. फ़ाइलें चुनें';

  @override
  String get stepTextOrLink => '1. टेक्स्ट या लिंक';

  @override
  String get stopNamesBody =>
      'नई इतिहास एंट्री में फ़ाइलों के नाम नहीं होंगे। क्या पहले से सहेजे नाम भी मिटाने हैं?';

  @override
  String get stopNamesTitle => 'फ़ाइलों के नाम सहेजना बंद करें?';

  @override
  String get testBuildNote => 'यह टेस्ट बिल्ड है, सार्वजनिक रिलीज़ नहीं।';

  @override
  String get textAskNote =>
      'दूसरा डिवाइस दिखाने से पहले पूछता है। लिंक अपने-आप कभी नहीं खुलते।';

  @override
  String get textErrDeclined => 'दूसरे डिवाइस ने टेक्स्ट मना कर दिया।';

  @override
  String get textErrEmpty => 'पहले कुछ टेक्स्ट लिखें।';

  @override
  String get textErrExpired => 'दूसरे डिवाइस पर किसी ने जवाब नहीं दिया।';

  @override
  String get textErrFailed => 'टेक्स्ट नहीं भेजा जा सका। फिर से कोशिश करें।';

  @override
  String get textErrNoAddress =>
      'दूसरा डिवाइस नहीं मिला। देखें कि वह उसी नेटवर्क पर है और Isekai Drop खुला है।';

  @override
  String get textErrNotTrusted =>
      'दूसरा डिवाइस अब इस डिवाइस पर भरोसा नहीं करता। फिर से जोड़ें।';

  @override
  String get textErrOldPeer =>
      'दूसरे डिवाइस पर पुराना Isekai Drop है जो टेक्स्ट नहीं ले सकता। दूसरे ऐप को अपडेट करें।';

  @override
  String get textErrTooLong =>
      'टेक्स्ट बहुत लंबा है। 8 KB (लगभग 8000 अक्षर) तक भेज सकते हैं।';

  @override
  String textFrom(String name) {
    return '$name से टेक्स्ट';
  }

  @override
  String get textHint => 'टेक्स्ट या लिंक लिखें या पेस्ट करें';

  @override
  String get textPairedOnly =>
      'टेक्स्ट सिर्फ़ जुड़े हुए डिवाइस को भेजा जा सकता है। पहले जोड़ें (फ़ाइल भेजें, या जोड़ें टैब इस्तेमाल करें)।';

  @override
  String textSentTo(String name) {
    return '$name को टेक्स्ट भेजा गया।';
  }

  @override
  String get theme => 'थीम';

  @override
  String get themeDark => 'डार्क';

  @override
  String get themeLight => 'लाइट';

  @override
  String get themeSystem => 'सिस्टम';

  @override
  String get thisDevice => 'यह डिवाइस';

  @override
  String get thisDeviceKey => 'इस डिवाइस की कुंजी';

  @override
  String toName(String name) {
    return '$name को';
  }

  @override
  String get transfersThisSession => 'इस बार के ट्रांसफ़र';

  @override
  String trustedCount(String count) {
    return 'भरोसेमंद डिवाइस: $count';
  }

  @override
  String get trustedDevices => 'भरोसेमंद डिवाइस';

  @override
  String get trustedDevicesSub =>
      'कोड जाँचें, नाम बदलें, अनुमति वापस लें या हटाएँ';

  @override
  String get turnOn => 'चालू करें';

  @override
  String get unavailable => 'उपलब्ध नहीं';

  @override
  String get updateAndroid =>
      'Android: ऊपर का लिंक खोलें, isekai-drop-android-arm64.apk (या -universal.apk) डाउनलोड करें और इसी ऐप के ऊपर इंस्टॉल करें। आपके जुड़े डिवाइस और इतिहास बने रहेंगे।';

  @override
  String get updateBoth =>
      'दोनों डिवाइस अपडेट करें: बहुत अलग संस्करण वाले डिवाइस शायद एक-दूसरे को न समझें।';

  @override
  String get updateIos =>
      'iPhone/iPad: नई .ipa को अपनी Apple ID से फिर से साइन करें (NOT TESTED)।';

  @override
  String get updateMac =>
      'Mac: isekai-drop-macos.dmg डाउनलोड करें और ऐप को Applications में खींचें (Mac पर NOT TESTED)।';

  @override
  String get updateWindows =>
      'Windows: isekai-drop-windows-setup.exe डाउनलोड करके चलाएँ।';

  @override
  String get versionTitle => 'संस्करण';

  @override
  String get visible => 'पास के डिवाइस को दिखे';

  @override
  String get visibleInfo =>
      'बंद: यह डिवाइस अपनी घोषणा बंद कर देता है (और Bonjour भी)। जुड़े डिवाइस और QR/लिखे पते वाले कनेक्शन फिर भी चलते हैं।';

  @override
  String get visibleSummary =>
      'आपके वाई-फ़ाई पर दूसरे इस डिवाइस को ढूँढ सकते हैं';
}
