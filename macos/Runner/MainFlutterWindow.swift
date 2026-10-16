import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var bonjour: IsekaiBonjour?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(
      name: "isekai_drop/apple",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    let bj = IsekaiBonjour(channel: channel)
    bonjour = bj
    channel.setMethodCallHandler { call, result in
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "bonjourStart":
        bj.start(
          name: args["name"] as? String ?? "Mac",
          port: args["port"] as? Int ?? 0,
          txt: args["txt"] as? [String: String] ?? [:],
          advertise: args["advertise"] as? Bool ?? true)
        result(nil)
      case "bonjourStop":
        bj.stop()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
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
