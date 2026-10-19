# Account and privacy design (v12)
* Local accounts on the device (caregiver, researcher). Passwords: PBKDF2-HMAC-SHA256, random per-account salt, 10,000 iterations (**below current OWASP guidance; raise before real use**). No plaintext, no default PIN.
* Researcher role requires a study code compiled in with `--dart-define=MINDY_STUDY_CODE=...`; without it nobody can be a researcher.
* Child profiles hold a pseudonymous `P-XXXXXX` ID; exports use per-session pseudonymous IDs, no names.
* Consent (caregiver) + assent (child) with a version string; play is blocked until recorded. **Consent wording is a placeholder, not ethics-approved.**
* Deletion: deleting a child removes their sessions and journeys.
* Limits: data in SharedPreferences is **not encrypted**; no password reset; no server, so no cross-device sync; a rooted device can read data. Not suitable for real child data until encrypted storage and ethics approval exist.
