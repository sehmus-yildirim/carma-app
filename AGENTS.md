# Plaqa Engineering Rules

- Use Flutter `3.41.7`, Dart null safety, Java 17 and Node.js 22.
- Before committing, run formatting, `flutter analyze`, Flutter tests, Functions tests, Firebase Rules emulator tests and the Android release build relevant to the change.
- Keep Firebase writes server-authoritative for security-sensitive state. Clients must never set verification, moderation or billing status directly.
- Never commit secrets, production tokens, real identity documents, signatures or personal test data.
- Verification fixtures must be synthetic. Document photos stay on-device, are processed locally and are deleted from temporary storage immediately after OCR or cancellation.
- Do not log OCR text, identity fields, signatures or clear-text licence plates.
- Do not deploy Firebase or publish a store build without explicit user approval.
