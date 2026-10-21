import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shares [text] with the Android share sheet (WhatsApp, SMS, e-mail…).
/// Returns false when it could only copy it to the clipboard instead.
typedef ShareText = Future<bool> Function(String text, {String? title});

const _channel = MethodChannel('cool_lodz/share');

Future<bool> _shareText(String text, {String? title}) async {
  try {
    await _channel.invokeMethod<void>('text', {'text': text, 'title': title});
    return true;
  } on MissingPluginException {
    // Off Android (tests, desktop): the clipboard.
  } on PlatformException catch (e) {
    debugPrint('share: $e');
  }
  await Clipboard.setData(ClipboardData(text: text));
  return false;
}

final shareTextProvider = Provider<ShareText>((ref) => _shareText);
