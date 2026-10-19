# Data and privacy

What Mindy stores, where it goes, and the database decision with its evidence.

## What is stored

### Per play session

session id · pseudonymous child id · activity · level · difficulty label ·
pace · study condition · full decision trace · start time · emotion before ·
emotion after · emotion source · check-in duration · completed flag ·
completion percent · successes · mistakes · interactions · pause count ·
duration · mean response time · response-time variability · replay answer ·
perceived difficulty · load time · sync status.

### Per child

A pseudonymous participant code, a nickname the caregiver typed, birth **year**
only, consent state, and the child's saved characters (a handful of integers
plus a name they chose).

### Caregiver-entered

Observations the caregiver chooses to record, worry-scale entries, Calm Corner
visits, support-plan decisions ("I'll try this" / "Not now"), and usability
questionnaire answers.

### Never stored

Full date of birth. Real name (the nickname is caregiver-chosen and free-text,
so the consent form must tell caregivers not to enter a full legal name).
Location. Contacts. Advertising identifiers. Any photograph, except the
caregiver's own optional report image on the "ask about a report" screen, which
stays on the device and is not transmitted.

## Where it goes

```
   Device (source of truth)                Optional backend
   ─────────────────────────               ────────────────────
   SharedPreferences                       SQLite, localhost
     mindy_sessions_v7         ──sync──►   sessions table
     mindy_observations_v7                 (research copies)
     mindy_avatars_v1_<child>  ✗ never synced
     settings, accounts, consent ✗ never synced
```

The app is fully functional with no backend. Sync is opt-in and points at an
address the caregiver or researcher sets.

### The AI wording layer

If, and only if, the caregiver turns on "Smarter wording for the support plan"
in Settings, the app sends **aggregated numbers already computed on the device**
(a band label, counts over 14 days, a confidence string, signal titles) to a
third-party LLM provider, and shows the paragraph that comes back. It never
sends a name, a raw session, a child id, or anything identifying.

Every returned paragraph is checked against a banned-term list on both the
server and the client, and is discarded if it contains diagnostic or clinical
vocabulary. Any failure at any step falls back silently to the existing
rule-based text.

**This is off by default and is not mentioned in the current consent screen.
That wording must be added before any real family uses it.**

## Database decision

**Recommendation: keep the existing storage (Option A). Do not add a database.**

### Evidence

| Question | Answer, from the code |
| --- | --- |
| How much data per child? | A few hundred session objects at most. A session serialises to roughly 1 KB, so a heavy user is well under 1 MB |
| What queries are actually run? | Exactly two shapes: "all sessions for the active child" and "all sessions on this device" (researcher export). Both are a single list read, then filtered in Dart |
| Any joins, aggregates or indexes needed? | None. Every statistic is computed in Dart over the in-memory list |
| Any concurrent writers? | No. One app, one user, writes serialised through one repository |
| Is a migration path needed? | The storage key is already versioned (`_v7`), and loading is wrapped in try/catch that falls back to empty rather than crashing |

### Why not SQLite (Option B)

It would add a plugin dependency with platform channels, a schema, a migration
path, and a new class of failure (a corrupt or locked database file) — in
exchange for query capability that nothing in the codebase uses. For a dataset
that fits comfortably in memory, that is cost without benefit. It would also
add a second place where child data lives, which is a privacy cost, not a
neutral one.

### Why not a cloud database (Option C)

It would move children's emotional data off the device and into a hosted
service, creating a transfer that the ethics application would have to justify,
a processor agreement, a jurisdiction question, and a breach surface. The
research question does not require it. The optional local backend already
covers the only real need, which is getting data off one device for analysis.

### The genuine deficiency, which a database would not fix

**The local store is not encrypted at rest.** Sessions sit in SharedPreferences
as plain JSON. On a shared or lost device, a caregiver's own child's emotional
history is readable. This is an ethics blocker, not a nice-to-have, and it is
independent of which datastore is used.

Options, in increasing order of effort:

1. Encrypt the JSON payload before writing it, with a key held in the platform
   keystore. Smallest change, keeps the current datastore.
2. Move to an encrypted store (for example an encrypted SQLite build). Larger
   change, and only worth it if a database is wanted for other reasons.
3. Store nothing locally and require the backend. Rejected: it breaks offline
   use, which is the point of the design.

Option 1 is recommended. It is **not implemented**.

## Deletion

- Per child, from Settings: sessions, journey, rewards, companion look and
  saved characters are removed.
- The backend has its own delete path for a withdrawn participant.
- Deletion is immediate and local; there is no soft-delete or retention window
  implemented, so a retention schedule still has to be written for the ethics
  application.

## Still required before any real participant

- [ ] Institutional ethics approval
- [ ] Caregiver consent and separate child assent, revisited not once-only
- [ ] Data protection impact assessment
- [ ] Encryption at rest (above)
- [ ] Consent wording for the AI layer
- [ ] Native-speaker review of the Sinhala and Tamil text
- [ ] A written retention and destruction schedule
- [ ] A distress protocol for sessions with a researcher present
