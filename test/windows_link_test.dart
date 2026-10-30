// 0.11.0: parsers for the read-only Windows link report.
import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/windows_link.dart';

const _netsh = '''

There is 1 interface on the system:

    Name                   : Wi-Fi
    Description            : Intel(R) Wi-Fi 6 AX201 160MHz
    GUID                   : 1234abcd-0000-0000-0000-000000000000
    Physical address       : aa:bb:cc:dd:ee:ff
    Interface type         : Primary
    State                  : connected
    SSID                   : MyHomeNetwork
    AP BSSID               : 11:22:33:44:55:66
    Band                   : 5 GHz
    Channel                : 36
    Network type           : Infrastructure
    Radio type             : 802.11ax
    Authentication         : WPA2-Personal
    Cipher                 : CCMP
    Connection mode        : Auto Connect
    Receive rate (Mbps)    : 1201
    Transmit rate (Mbps)   : 960
    Signal                 : 88%
    Profile                : MyHomeNetwork
    QoS MSCS Configured         : 0

    Hosted network status  : Not available
''';

void main() {
  test('netsh: connected Wi-Fi, no network names kept', () {
    final l = parseNetshInterfaces(_netsh);
    expect(l.connected, isTrue);
    expect(l.radioType, '802.11ax');
    expect(l.band, '5 GHz');
    expect(l.channel, 36);
    expect(l.frequencyMhz, 5180);
    expect(l.receiveMbps, 1201);
    expect(l.transmitMbps, 960);
    expect(l.signalPercent, 88);
    expect(
      l.summary,
      '802.11ax, 5 GHz, channel 36, receive 1201 / send 960 Mbps, signal 88%',
    );
    expect(l.summary.contains('MyHomeNetwork'), isFalse);
  });

  test('netsh: Windows 10 has no Band line -> from the channel', () {
    final l = parseNetshInterfaces(
      _netsh
          .replaceAll('    Band                   : 5 GHz\n', '')
          .replaceAll(': 36', ': 6'),
    );
    expect(l.band, isNull);
    expect(l.frequencyMhz, 2437);
    expect(l.summary, contains('2.4 GHz'));
  });

  test('netsh: disconnected / empty / other language', () {
    expect(
      parseNetshInterfaces(
        _netsh.replaceAll(
          'State                  : connected',
          'State                  : disconnected',
        ),
      ).connected,
      isFalse,
    );
    expect(parseNetshInterfaces('').connected, isFalse);
    expect(
      parseNetshInterfaces(
        'The Wireless AutoConfig Service (wlansvc) is not running.',
      ).summary,
      'Wi-Fi not connected',
    );
  });

  test('channel to MHz', () {
    expect(channelToMhz(1), 2412);
    expect(channelToMhz(14), 2484);
    expect(channelToMhz(149), 5745);
    expect(channelToMhz(5, band: '6 GHz'), 5975);
    expect(channelToMhz(0), isNull);
  });

  test('powercfg Wi-Fi power saving', () {
    const out = '''
    Power Setting GUID: 12bbebe6-58d6-4636-95bb-3217ef867c1a  (Power Saving Mode)
      Possible Setting Index: 000
      Possible Setting Friendly Name: Maximum Performance
    Current AC Power Setting Index: 0x00000000
    Current DC Power Setting Index: 0x00000002
''';
    expect(
      parsePowercfgWifi(out),
      'plugged in: Maximum Performance, battery: Medium Power Saving',
    );
    expect(parsePowercfgWifi('nothing'), isNull);
  });

  test('adapter properties: only speed-related ones', () {
    const out =
        'Wi-Fi|Roaming Aggressiveness|3. Medium\r\n'
        'Wi-Fi|MIMO Power Save Mode|Auto SMPS\r\n'
        'Wi-Fi|Wake on Magic Packet|Enabled\r\n'
        'Ethernet|Speed & Duplex|Auto Negotiation\r\n'
        'broken line\r\n';
    expect(parseAdapterProps(out), [
      'Wi-Fi: Roaming Aggressiveness = 3. Medium',
      'Wi-Fi: MIMO Power Save Mode = Auto SMPS',
    ]);
  });

  test('report label: band, Ethernet or nothing', () {
    expect(
      WindowsLinkReport(wlan: parseNetshInterfaces(_netsh)).linkLabel,
      '5 GHz',
    );
    expect(
      const WindowsLinkReport(wlan: WlanLink(), ethernet: true).linkLabel,
      'Ethernet',
    );
    expect(const WindowsLinkReport(wlan: WlanLink()).linkLabel, isNull);
  });
}
