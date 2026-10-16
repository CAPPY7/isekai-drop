import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var bonjour: IsekaiBonjour?
  private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "IsekaiNative") else { return }
    let channel = FlutterMethodChannel(name: "isekai_drop/apple", binaryMessenger: registrar.messenger())
    let bj = IsekaiBonjour(channel: channel)
    bonjour = bj
    channel.setMethodCallHandler { [weak self] call, result in
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "bonjourStart":
        bj.start(
          name: args["name"] as? String ?? "iPhone",
          port: args["port"] as? Int ?? 0,
          txt: args["txt"] as? [String: String] ?? [:],
          advertise: args["advertise"] as? Bool ?? true)
        result(nil)
      case "bonjourStop":
        bj.stop()
        result(nil)
      case "keepAwake":
        self?.keepAwake(args["on"] as? Bool ?? false)
        result(nil)
      case "share":
        self?.share(paths: args["paths"] as? [String] ?? [])
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// While a transfer runs: stop auto-lock, and ask iOS for a short grace
  /// period if the user leaves the app (iOS decides how long; not guaranteed).
  private func keepAwake(_ on: Bool) {
    UIApplication.shared.isIdleTimerDisabled = on
    if on, backgroundTask == .invalid {
      backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "IsekaiDropTransfer") { [weak self] in
        self?.endBackground()
      }
    } else if !on {
      endBackground()
    }
  }

  private func endBackground() {
    if backgroundTask != .invalid {
      UIApplication.shared.endBackgroundTask(backgroundTask)
      backgroundTask = .invalid
    }
  }

  /// System share sheet for received files ("Save to Files", AirDrop, ...).
  private func share(paths: [String]) {
    let urls = paths.map { URL(fileURLWithPath: $0) }
    guard !urls.isEmpty else { return }
    let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    guard let root = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
      ?? scene?.windows.first?.rootViewController else { return }
    var top = root
    while let p = top.presentedViewController { top = p }
    let vc = UIActivityViewController(activityItems: urls, applicationActivities: nil)
    if let pop = vc.popoverPresentationController {
      pop.sourceView = top.view
      pop.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 1, height: 1)
      pop.permittedArrowDirections = []
    }
    top.present(vc, animated: true)
  }
}

/// Bonjour advertise + browse for Isekai Drop (service type _isekaidrop._tcp).
/// Uses NetService, which works on iPhone/iPad WITHOUT Apple's multicast
/// entitlement when the type is listed in NSBonjourServices.
/// Results are only hints; identity is checked inside TLS by the app.
final class IsekaiBonjour: NSObject, NetServiceDelegate, NetServiceBrowserDelegate {
  private let channel: FlutterMethodChannel
  private var published: NetService?
  private var browser: NetServiceBrowser?
  private var resolving: [NetService] = []

  init(channel: FlutterMethodChannel) {
    self.channel = channel
  }

  func start(name: String, port: Int, txt: [String: String], advertise: Bool = true) {
    stop()
    let s = NetService(domain: "local.", type: "_isekaidrop._tcp.", name: String(name.prefix(60)), port: Int32(port))
    var data: [String: Data] = [:]
    for (k, v) in txt { data[k] = v.data(using: .utf8) }
    s.setTXTRecord(NetService.data(fromTXTRecord: data))
    // Audit #8: "Visible" off stops only advertising; browsing continues.
    if advertise {
      s.publish()
      published = s
    }
    let b = NetServiceBrowser()
    b.delegate = self
    b.searchForServices(ofType: "_isekaidrop._tcp.", inDomain: "local.")
    browser = b
  }

  func stop() {
    published?.stop()
    published = nil
    browser?.stop()
    browser = nil
    resolving.removeAll()
  }

  func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
    if service.name == published?.name { return }
    service.delegate = self
    resolving.append(service)
    service.resolve(withTimeout: 5)
  }

  func netServiceDidResolveAddress(_ sender: NetService) {
    var txt: [String: String] = [:]
    if let d = sender.txtRecordData() {
      for (k, v) in NetService.dictionary(fromTXTRecord: d) {
        txt[k] = String(data: v, encoding: .utf8) ?? ""
      }
    }
    for addr in sender.addresses ?? [] {
      if let ip = IsekaiBonjour.ipv4(addr) {
        channel.invokeMethod("bonjourFound", arguments: [
          "name": sender.name, "host": ip, "port": sender.port, "txt": txt,
        ])
        break
      }
    }
    resolving.removeAll { $0 === sender }
  }

  func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
    resolving.removeAll { $0 === sender }
  }

  static func ipv4(_ data: Data) -> String? {
    return data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> String? in
      guard let base = raw.baseAddress, raw.count >= MemoryLayout<sockaddr_in>.size else { return nil }
      let sa = base.assumingMemoryBound(to: sockaddr.self)
      guard sa.pointee.sa_family == sa_family_t(AF_INET) else { return nil }
      var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
      let r = getnameinfo(sa, socklen_t(raw.count), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
      return r == 0 ? String(cString: host) : nil
    }
  }
}
