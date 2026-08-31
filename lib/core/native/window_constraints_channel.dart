import 'dart:io';

import 'package:flutter/services.dart';

/// Lets the app lower/restore the native window's minimum trackable size
/// at runtime — used so collapsing the Home screen's folder side panel
/// (which needs much less width) also relaxes how narrow the window is
/// allowed to go, instead of it being stuck at the widest screen's floor.
/// See windows/runner/flutter_window.cpp and win32_window.cpp for the
/// native side of this channel.
class WindowConstraintsChannel {
  static const MethodChannel _channel = MethodChannel('studypdf/window');

  /// Default floor, matching win32_window.h's compiled-in default —
  /// restored whenever nothing narrower is currently needed.
  static const double defaultMinWidth = 760;
  static const double defaultMinHeight = 560;

  /// Narrower floor used while the Home screen's folder panel is
  /// collapsed. Only width is reduced; height stays at the default.
  static const double collapsedFolderPanelMinWidth = 600;

  static Future<void> setMinSize(double width, double height) async {
    if (!Platform.isWindows) {
      return;
    }
    try {
      await _channel.invokeMethod('setMinSize', {
        'width': width,
        'height': height,
      });
    } on PlatformException {
      // Non-fatal: worst case the window just keeps its previous floor.
    } on MissingPluginException {
      // Expected in tests / non-Windows dev runs where the native side
      // isn't wired up.
    }
  }
}
