# Verification V1 manual QA

## Test data safety

Use synthetic printed fixtures that contain no real identity, document number, address, portrait, VIN, or real plate. Do not capture or import another person's document. Before and after each run, verify that the in-app verification flow offers camera and explicit gallery selection, that gallery images can be aligned locally, and that the local temporary directory is empty after leaving the flow. The current profile matrix and external gates are maintained in `docs/verification/`.

## Real-device matrix

| Area | Redmi / Android | iPhone / iOS external gate |
| --- | --- | --- |
| Fresh install and camera prompt | Required | Required on macOS/Xcode |
| Deny, retry, and permanently deny | Required | Required |
| Front/back camera availability | Back camera only | Back camera only |
| Tap focus and exposure | Required | Required |
| Flash off/on | Required | Required |
| Portrait rotation handling | Required | Required |
| ID-card overlay | Required | Required |
| Passport data-page overlay | Required | Required |
| Residence-permit overlay | Required | Required |
| Registration overlay | Required | Required |
| Dark, glare, blur, and cropped photo | Required | Required |
| German/Turkish names | Synthetic fixture | Synthetic fixture |
| Large text and screen reader | Required | Required |
| Background/resume and process kill | Required | Required |
| Offline OCR then online retry | Required | Required |
| Logout during scan | Required | Required |
| App Check release token | Play Integrity metrics | App Attest metrics |

## Required flows

- Registered holder succeeds with matching synthetic identity and plate.
- Blur is rejected, retake succeeds.
- Identity expired yesterday is rejected; today and tomorrow are accepted.
- User below the configured Plaqa minimum age is rejected.
- Surname/first-name mismatch is rejected without automatic relation switching.
- Plate mismatch is rejected for every relation.
- Leasing, company car, authorized private vehicle, and other authorized use each require the exact declaration, checkbox, meaningful finger signature, and one private PDF.
- Company C.1.1 with empty C.1.2 reaches the declaration step.
- Camera denial presents retry/settings guidance without a stack trace.
- Network loss before submit keeps only in-memory extracted values and safely retries the same session.
- Rapid duplicate taps create one effective completion.
- An expired session restarts without reusing its nonce.
- Logout removes local temporary images.
- Plate change and vehicle removal clear the effective status.

## Visual and accessibility checks

- No `Rückseite`, arbitrary file upload, editable expiry, or combined leasing/company option exists. Camera and gallery selection are both available for the requested document page.
- Every camera, flash, capture, retake, and signature control has a spoken label and at least a 48 dp target.
- Focus order follows title, step, content, actions.
- Errors include text and icon, not color alone.
- At 200% text scale on the smallest supported screen there is no overflow or hidden action.
- Dark-theme contrast remains readable in direct sunlight and low brightness.
- OCR and resize show a progress state and do not freeze scrolling or navigation.

## Firebase and release checklist

- Run all repository tests and the full emulator Rules suite.
- Deploy only to a non-production project until legal and App Check gates pass.
- Confirm private V1 Firestore paths are denied to another account.
- Confirm a declaration PDF is owner-readable and cannot be overwritten by the client.
- Confirm no document object is created under `profile_documents` by V1.
- Confirm Function logs contain no name, birth date, expiry, clear plate, holder values, OCR text, or signature.
- Confirm expiry schedule and required composite index are active.
- Observe App Check metrics before enforcement; do not guess production readiness.
- Produce signed AAB and run the release APK/AAB on Redmi.
- Build, archive, and test iOS on macOS/Xcode; then test TestFlight.
- Obtain legal approval for declaration, privacy information, retention, and terms linkage.

## Release decision

The technical result may be called `release-ready after listed external gates` only after all automated gates, signed Android build, and Redmi smoke tests pass. It must remain `not release-ready` while a required technical test fails. It must never be called fully `release-ready` before iOS and legal review are complete for an iOS/public release.
