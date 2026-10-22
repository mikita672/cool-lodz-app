import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';

/// «Przeczytaj na głos»: the phone's Polish voice (`cool_lodz/tts`).
class TextToSpeech {
  TextToSpeech([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel('cool_lodz/tts');

  final MethodChannel _channel;

  Future<void> _call(String method, [Object? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // Off Android (tests, desktop): silent.
    } on PlatformException catch (e) {
      debugPrint('tts.$method: $e');
    }
  }

  Future<void> speak(String text) => _call('speak', text);
  Future<void> stop() => _call('stop');
}

final textToSpeechProvider = Provider<TextToSpeech>((ref) => TextToSpeech());

/// Reads [text] aloud; a second tap stops.
class ReadAloudButton extends ConsumerStatefulWidget {
  const ReadAloudButton({super.key, required this.text});

  /// Built when tapped, so it reads what is on screen then.
  final String Function() text;

  @override
  ConsumerState<ReadAloudButton> createState() => _ReadAloudButtonState();
}

class _ReadAloudButtonState extends ConsumerState<ReadAloudButton> {
  bool _speaking = false;
  late final TextToSpeech _tts = ref.read(textToSpeechProvider);

  @override
  void dispose() {
    if (_speaking) _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OutlinedButton.icon(
      key: const Key('read-aloud'),
      onPressed: () {
        setState(() => _speaking = !_speaking);
        if (_speaking) {
          _tts.speak(widget.text());
        } else {
          _tts.stop();
        }
      },
      icon: Icon(
        _speaking ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
      ),
      label: Text(_speaking ? l10n.ttsStop : l10n.ttsRead),
    );
  }
}
