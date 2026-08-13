import 'package:flutter/services.dart';

class PlateSpeechResult {
  const PlateSpeechResult({
    required this.transcript,
    required this.alternatives,
  });

  final String transcript;
  final List<String> alternatives;
}

class PlateSpeechBridge {
  static const MethodChannel _channel = MethodChannel('plaqa/chat_tools');

  Future<PlateSpeechResult?> recognizePlateSpeech() async {
    final result = await _channel.invokeMapMethod<String, Object?>(
      'recognizePlateSpeech',
    );

    if (result == null) {
      return null;
    }

    final transcript = result['transcript']?.toString().trim() ?? '';
    final rawAlternatives = result['alternatives'];
    final alternatives = rawAlternatives is List
        ? rawAlternatives
              .map((value) => value.toString().trim())
              .where((value) => value.isNotEmpty)
              .toList(growable: false)
        : const <String>[];

    if (transcript.isEmpty && alternatives.isEmpty) {
      return null;
    }

    return PlateSpeechResult(
      transcript: transcript,
      alternatives: alternatives,
    );
  }
}
