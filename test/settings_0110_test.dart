// 0.11.0: real default device name, route mode (Auto default + migration),
// System theme default.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/settings/device_name.dart';
import 'package:isekaidrop/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('device name', () {
    test('friendlyModelName', () {
      expect(friendlyModelName('samsung', 'SM-G991B'), 'Samsung SM-G991B');
      expect(friendlyModelName('Google', 'Pixel 7'), 'Google Pixel 7');
      expect(friendlyModelName('OnePlus', 'OnePlus 9'), 'OnePlus 9');
      expect(friendlyModelName('', 'X1'), 'X1');
      expect(friendlyModelName('Nokia', ''), 'Nokia');
    });

    test('cleanDeviceName', () {
      expect(cleanDeviceName('  OnePlus 9 '), 'OnePlus 9');
      expect(cleanDeviceName('kazuto-pc.local', hostname: true), 'kazuto-pc');
      expect(cleanDeviceName('localhost', hostname: true), isNull);
      expect(cleanDeviceName(''), isNull);
      expect(cleanDeviceName(null), isNull);
      expect(cleanDeviceName('a\u0007b'), 'ab');
      expect(cleanDeviceName('x' * 60)!.length, 40);
    });

    test('generic stored name is replaced by the system name', () async {
      SharedPreferences.setMockInitialValues({'device_name': 'Android phone'});
      final p = await SharedPreferences.getInstance();
      expect(
        SettingsController(p, systemName: 'OnePlus 9').deviceName,
        'OnePlus 9',
      );
    });

    test('no stored name: system name, else generic', () async {
      SharedPreferences.setMockInitialValues({});
      final p = await SharedPreferences.getInstance();
      expect(
        SettingsController(p, systemName: 'KAZUTO-PC').deviceName,
        'KAZUTO-PC',
      );
      expect(SettingsController(p).deviceName, genericDeviceName());
    });

    test('a name the user typed is never overwritten', () async {
      SharedPreferences.setMockInitialValues({'device_name': 'Kazuto phone'});
      final p = await SharedPreferences.getInstance();
      expect(
        SettingsController(p, systemName: 'OnePlus 9').deviceName,
        'Kazuto phone',
      );
      // Even a generic-looking name is kept once the user saved it.
      final c = SettingsController(p, systemName: 'OnePlus 9');
      await c.setDeviceName('Android phone');
      expect(
        SettingsController(p, systemName: 'OnePlus 9').deviceName,
        'Android phone',
      );
    });
  });

  group('route mode', () {
    test('fresh install: Auto', () async {
      SharedPreferences.setMockInitialValues({});
      final p = await SharedPreferences.getInstance();
      await SettingsController.migrate(p);
      final c = SettingsController(p);
      expect(c.routeMode, SettingsController.routeAuto);
      expect(c.fastDirect, isTrue);
    });

    test(
      '0.10 users (Fast direct was on by default) migrate to Auto',
      () async {
        SharedPreferences.setMockInitialValues({
          'settings_schema_version': 2,
          'fast_direct': true,
        });
        final p = await SharedPreferences.getInstance();
        await SettingsController.migrate(p);
        expect(p.getInt('settings_schema_version'), 3);
        expect(SettingsController(p).routeMode, SettingsController.routeAuto);
      },
    );

    test('0.10 users who turned Fast direct off get Router only', () async {
      SharedPreferences.setMockInitialValues({
        'settings_schema_version': 2,
        'fast_direct': false,
      });
      final p = await SharedPreferences.getInstance();
      await SettingsController.migrate(p);
      expect(SettingsController(p).routeMode, SettingsController.routeRouter);
    });

    test('set and read back', () async {
      SharedPreferences.setMockInitialValues({});
      final p = await SharedPreferences.getInstance();
      final c = SettingsController(p);
      await c.setRouteMode(SettingsController.routeRouter);
      expect(SettingsController(p).routeMode, SettingsController.routeRouter);
      expect(SettingsController(p).fastDirect, isFalse);
      await c.setRouteMode(SettingsController.routeDirect);
      expect(SettingsController(p).routeMode, SettingsController.routeDirect);
      await c.setFastDirect(false);
      expect(SettingsController(p).routeMode, SettingsController.routeRouter);
    });
  });

  test('theme defaults to System', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    expect(SettingsController(p).themeMode, ThemeMode.system);
  });
}
