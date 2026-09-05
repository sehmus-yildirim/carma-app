# Verification OCR repair - 2026-09-05

## Scope and safety

Repair the existing verification flow, retaining camera and gallery. No second
verification flow, remote document processing, real document fixtures, client
verification writes, or Store publication. Existing account and vehicle data
must survive the device update.

## Reproduced defects and changes

- New text-level regressions reproduced six failures before correction: inline
  registration field A, spaced field codes, borrowing a following field's value,
  accepting a date label as a missing forename, borrowing distant unrelated
  text, and rejecting Germany's ICAO issuing code `D<<`.
- Field lookup now validates the expected value type, excludes known labels,
  bounds its search and stops at the next field. Ambiguous results stay rejected.
- German residence cards can use a clearly separated combined name field or
  the TD1 machine-readable back. All-capitals combined names on one line are
  not split by guessing. The country selection denotes the issuing country,
  not nationality. The established four-field submission contract is unchanged.
- Camera preview preserves its actual aspect ratio in portrait and landscape;
  focus coordinates refer to the displayed image. The completed-photo preview
  no longer draws a misleading second document frame over a different crop.
- Gallery starts with the whole selected image visible, allows zooming out,
  and prepares a higher-resolution crop. Camera/gallery choices remain.
- Luminance-edge heuristics report framing hints rather than preventing OCR:
  document text, portraits and tightly cropped originals do not prove that an
  outer document edge is missing. Resolution, blur and exposure checks remain.
  Missing or conflicting required data still prevents successful parsing.
- Native OCR can retry bounded rotations and a grayscale/contrast variant when
  recognition is incomplete. Conflicting readings are not discarded in a retry.
  Temporary variants are deleted in finally blocks and are never uploaded.
- MRZ parsing preserves spatial line order and Germany's `D<<` issuing code.
  Native OCR omitted repeated terminal fillers even in a fixed-width fixture.
  Only unused terminal positions may be padded. Name rows must visibly end in
  a double filler; date fields and their check digits must already be present
  and valid. This is four-field extraction, not a complete MRZ/authenticity audit.
- Camera/gallery private source copies are removed after processing or cancel.
  Android image-picker uses private `cache`, while Dart uses `code_cache`; both
  are covered. Public gallery originals outside these caches are preserved.
- The German registration guide uses the unfolded 210:106 paper aspect ratio.

## Final local evidence

- Initial new regression suite: 1 pass, 6 failures on the old parser.
- Corrected focused parser suite, including eAT and truncated MRZ cases: 11/11.
- Recovery suite: 9/9, including bounded retries, conflicting fields, fatal
  quality failures and cleanup after native exceptions.
- Full final Flutter suite: 332 passed, 1 native-Android-only test skipped on
  Windows; elapsed 4m19s. Includes the 240 deterministic parser-matrix cases.
- Final `flutter analyze`: no issues, 71.5s.
- Format check: 241 files checked, no changes. `git diff --check` passed.
- Updated Android CI Bash wrapper: `bash -n` passed. It now runs the native OCR
  suite as well as the existing flow suite. Hosted CI is a separate check after
  push; local results do not certify the hosted emulator.
- Functions: 183/183 passed under Node 22.
- Firestore and Storage local emulators: 117/117 passed, no cancellations.
- Final real Redmi native ML Kit run: 7/7 synthetic cases passed: identity
  rotation 0/90/180/270, German registration, residence front and passport MRZ.
  This is one native test containing seven cases, not seven real documents.
  The first proportional-font passport fixture failed; a fixed-width fixture
  then reproduced the terminal-filler issue described above. Both the fixture
  and parser were corrected before the passing rerun.
- Non-personal receipt read before replacing the test APK:
  `startedAt=2026-09-05T01:14:02.773425Z`, `status=passed`,
  `fixtures=synthetic-test-not-valid`, with all seven case identifiers.
- Normal `lib/main.dart` debug APK rebuilt after the final cache cleanup edits
  and installed successfully with `adb install -r -t` on `cf1d4c97`.
  Native seven-case OCR evidence predates those final cache/UI-only edits;
  the full final Dart suite and analyzer include them.
- Normal app start succeeded with the signed-in account and all five navigation
  items. Opened Settings > Profile & Verification > Documents > Photograph
  front: both Camera and Gallery were visible. Closed the chooser without
  selecting/submitting a personal document or changing any verification state.

## Android artifacts

- Debug APK: `build/app/outputs/flutter-apk/app-debug.apk`, 253865885 bytes,
  SHA-256 `93378A248C6921BAF3ADBE191ED0ED5DE1D2F27CA4B70F15490CF95E59367F04`.
- Signed release AAB: `build/app/outputs/bundle/release/app-release.aab`,
  88236689 bytes, built in 364s with the existing signing configuration,
  SHA-256 `5E1ABCBC8AC7425555FF68CCD84F85879301A8C15EB245F63116EE175CA56695`.
- Google bundletool 1.18.3 `validate` passed with exit 0.
- JDK jarsigner reported "JAR verified", exit 0, with warnings: self-signed
  certificate/untrusted PKIX chain, absent timestamp, unsigned POSIX metadata,
  and differing JarFile/JarInputStream treatment because of manifest ordering.
  The warnings are recorded, not represented as a warning-free signature audit.
- The release AAB was not uploaded to Play. The installed app is a debug build,
  preserving the user's existing signing/data setup. No new release-device
  smoke or real-document acceptance is claimed by this artifact build.

The native test uses generated images prominently marked TEST / SAMPLE /
NOT VALID. Its receipt contains only timestamps, test case identifiers and
pass/fail state. There are no real identity photos, OCR text or signatures in
this change. Device test APKs were installed with `adb install -r -t`, not by
uninstalling the user's app. The normal application has been restored.

## Deployment boundary

These verification corrections execute on-device. They do not require Firebase
Functions, Rules, indexes, Hosting or an App Check enforcement change. The
earlier targeted profile Rules and image-Function deployments are documented
separately. Do not publish the entire local Rules file merely to deliver Flutter
changes: unrelated live retention Rules differ from this checkout.

## Gates still requiring real evidence

Real camera/gallery captures for each released document generation remain a
mandatory acceptance step. No country/profile is marked productionValidated by
synthetic tests. No universal recognition guarantee or document-authenticity /
identity-proofing guarantee is claimed. Existing document_data_match assurance
and its lack of cryptographic binding of on-device OCR remain unchanged.
The current patch received manual security-sensitive diff review, not a new
formal Codex Security scan. Historical scan results must not be applied to it.

For the user: test the German ID front, residence card front (or code-line back),
passport data page, and registration side containing A/C.1.1/C.1.2. Check the
four recognized identity fields and the registration fields before submitting.
Use original images inside the app, not repository attachments. Also exercise
retake, gallery rotation/zoom, cancellation and returning from the background.
The user's requested shutdown is conditional on completing the task. Without
real-document acceptance, do not mark this area complete or automatically shut
down the laptop as though the real-world recognition gate had passed.

## Primary references

- ML Kit image and text-line guidance:
  https://developers.google.com/ml-kit/vision/text-recognition/v2/android
- BAMF eAT front/back field layout:
  https://www.bamf.de/SharedDocs/Anlagen/DE/MigrationAufenthalt/ElektronischerAufenthalt/broschuere-eat-a4.pdf
- PRADO German ID:
  https://www.consilium.europa.eu/prado/en/DEU-BO-02004/index.html
- PRADO German registration:
  https://www.consilium.europa.eu/prado/en/DEU-GO-01001/index.html
