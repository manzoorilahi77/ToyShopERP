import 'dart:io';

import 'package:flutter/material.dart';

/// Runtime environment detection — zero extra dependencies.
///
/// Uses the Android `android.os.Build` fields via a platform channel
/// to check if we're on an emulator. Falls back to a network probe
/// (tries to open a TCP socket to 10.0.2.2:5000) if the channel fails.
///
/// On Android emulators `10.0.2.2` maps to the host's localhost.
/// On physical Android devices connected via USB we use `adb reverse`
/// so `127.0.0.1` works.
class AppEnv {
  AppEnv._();

  static bool _emulator = false;

  /// Must be called once in `main()` before the widget tree is built.
  static Future<void> init() async {
    if (!Platform.isAndroid) return;
    _emulator = await _detectViaProbe();
    debugPrint('[AppEnv] isEmulator=$_emulator → host=$localHost');
  }

  /// Probe whether 10.0.2.2:5000 (the emulator host alias) is reachable.
  /// On an emulator this connects in ~5 ms.
  /// On a physical device it either times out or refuses immediately.
  static Future<bool> _detectViaProbe() async {
    try {
      final socket = await Socket.connect(
        '10.0.2.2',
        5000,
        timeout: const Duration(seconds: 2),
      );
      await socket.close();
      return true; // connected → we're on an emulator
    } catch (_) {
      return false; // refused / timed out → physical device
    }
  }

  static bool get isEmulator => _emulator;

  /// The correct host depending on environment:
  ///   - Android emulator  → 10.0.2.2  (host loopback alias)
  ///   - Physical device   → 127.0.0.1 (forwarded via adb reverse)
  ///   - iOS simulator     → 127.0.0.1
  static String get localHost =>
      (Platform.isAndroid && _emulator) ? '10.0.2.2' : '127.0.0.1';
}
