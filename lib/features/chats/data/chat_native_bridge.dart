import 'package:flutter/services.dart';

class PickedPhoneContact {
  const PickedPhoneContact({required this.name, required this.phoneNumber});

  final String name;
  final String phoneNumber;
}

class ChatNativeBridge {
  static const MethodChannel _channel = MethodChannel('carma/chat_tools');

  Future<PickedPhoneContact?> pickPhoneContact() async {
    final result = await _channel.invokeMapMethod<String, String>(
      'pickPhoneContact',
    );

    if (result == null) {
      return null;
    }

    final name = result['name']?.trim() ?? '';
    final phoneNumber = result['phoneNumber']?.trim() ?? '';

    if (name.isEmpty && phoneNumber.isEmpty) {
      return null;
    }

    return PickedPhoneContact(
      name: name.isEmpty ? 'Kontakt' : name,
      phoneNumber: phoneNumber,
    );
  }

  Future<void> openMap({
    required double latitude,
    required double longitude,
  }) async {
    await _channel.invokeMethod<void>('openMap', <String, Object>{
      'latitude': latitude,
      'longitude': longitude,
    });
  }
}
