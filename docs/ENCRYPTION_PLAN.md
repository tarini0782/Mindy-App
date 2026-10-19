# Encryption at rest: plan (NOT built in v25)

Status: **not implemented.** Proposal NFR "zero anonymized patient telemetry stored unencrypted" is therefore NOT met on the device.
What does protect data today: salted PBKDF2 password hashes, pseudonymous child codes, HTTPS-only upload, demo data never uploaded.

## Why it was left out
Writing my own cipher is unsafe, and the proper route adds native plugins that I could not build or test here
(flutter_secure_storage needs platform setup; on Windows desktop it needs the ATL build component). Adding it blind could
stop the app from building on the panel laptop.

## Proper design (do after the panel, on the real target platform)
1. Add `flutter_secure_storage` (key in Android Keystore / iOS Keychain) and an AES-GCM package such as `cryptography` or `encrypt`.
2. One wrapper `SecureJsonStore.read(key)` / `write(key, json)`: random 256-bit key created once and kept in secure storage; random 96-bit nonce per write;
   store `nonce + ciphertext + tag` base64 in shared_preferences.
3. Migration: if a value is plain JSON, read it, then re-write encrypted. If decryption fails, show a clear message, never crash.
4. Move SessionRepository, JourneyController, CalmService, FeedLogService, UsabilityService, WorryService and AccountService (child list) onto the wrapper.
5. Tests: round-trip, tamper detection, migration, wrong key.
6. Until done, say plainly: "local data is not yet encrypted at rest".
