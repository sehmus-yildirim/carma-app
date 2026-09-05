# Profile provisioning compatibility fix - 2026-09-05

## Confirmed cause

The installed Android app showed "Konto wird vorbereitet" after signing in.
Device logs identified a denied write to the owner's public profile. This was
separate from the App Check debug credential issue repaired earlier.

The vehicle-management Function adds `isVerified` and `plateDisplayLabel` to the
public profile; verification V1 also writes `isVerified`. The public-profile
Rules field allowlist did not include either field. The client's login batch
merges ordinary profile metadata, retaining both server fields. Validation of
the entire resulting document then denied the batch even though those fields
were not changed by the client.

## Correction and tests

- Recognize both fields in the public-profile schema.
- Deny client initialization of either field, including false/null values.
- Deny additions, changes and deletions during updates using affectedKeys().
- Preserve ownership, identity-name locks, private verification matching and
  server-owned profile-view counters.

Added three regression tests to `profile_personal_data_rules.test.cjs`.
Before the fix, the login reproduction failed while the other 16 tests passed.
After the fix, all 44 tests across personal-data, vehicle and verification
Firestore/Storage suites passed. Verified and unverified profiles are covered,
as are forged flags, missing/null fields, field deletion and foreign writers.

One intermediate run omitted the Storage emulator and cancelled the dependent
verification tests. The final run included both emulators and had no failures,
cancellations or skipped tests. Emulator runtime: Node 22 and installed Java 21;
no Android build or Java build configuration was changed.

## Approved production activation

The user explicitly approved deploying only the affected profile rule.
Live Rules differed from the local repository in unrelated retention rules.
Therefore only the two tested public-profile blocks were transplanted onto the
current live source, after verifying both old blocks matched the test baseline.
All other live Rules were preserved, rather than publishing the entire local
file. Firebase compilation reported no errors. Existing non-error compiler
diagnostics were not remediated as part of this narrowly scoped fix.

- Previous Ruleset: `19bdba86-9895-4893-b72f-3cb2b596b35d`.
- Active Ruleset: `1f7528e5-7b4f-437f-995c-6f9689477f02`.
- Activated at `2026-09-05T00:14:45.336087Z` in `carma-a84e4`.

Firebase returned transient 503 responses during compilation/creation. Before
retrying activation, readback found the already-created candidate and verified
its exact content. That candidate was activated without duplicate creation.
Release readback confirmed the expected Ruleset. No accounts, vehicles, images,
Functions, Storage Rules or Hosting content were changed by this deployment.

## Actual device check

Tapped the visible "Erneut versuchen" button on Redmi `cf1d4c97` after the
deployment. The account-error and retry labels disappeared. The real app showed
the profile view and its Suchen, Profil, Chats, Melden and Einstellungen
navigation. No sign-out, data clearing or reinstall was needed for this repair.

AI image generation and final image quality are separate checks and were not
exercised by the account-recovery test.
