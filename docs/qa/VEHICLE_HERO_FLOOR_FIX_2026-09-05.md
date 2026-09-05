# Vehicle hero floor cleanup - 2026-09-05

## Scope and cause

Only `functions/vehicle_hero_image.js` and its regression tests changed.
The image model, generation prompt, left-facing orientation, output dimensions,
Flutter rendering and stored vehicle images were not changed.

The previous floor cleanup only ran for a dark bottom band (average luminance
below 75). White/grey ground could therefore survive after the backdrop had
already become transparent. Ground touching the tires could also enclose key
colour underneath the chassis. Soft ground edges mixed with the chroma colour
could fail the old RGB-distance check and remain as a visible oval rim.

## Correction

- Remove broad, shallow, connected light-neutral ground near the silhouette's
  bottom before normalizing size and position.
- Do not erase light components extending upward into the vehicle. This is a
  conservative colour/geometry heuristic, not semantic vehicle segmentation.
- After ground removal, flood-fill newly reachable backdrop pockets before
  suppressing chroma spill. Previously transparent pixels allow this traversal.
- Recognize neutral/chroma mixtures at soft ground edges, retaining the existing
  colour-dominance requirements.

## Verification

Final local result: all 183 Functions tests passed, including all 15 vehicle-image
tests. JavaScript syntax checking and `git diff --check` also passed. No Flutter
code, Rules or Android build inputs changed; no new APK was built for this patch.

The first five new fixtures failed against the original implementation while
its six existing image tests passed. The additional tests cover white, grey,
partially transparent and soft oval floors composited beneath the actual BMW
reference asset, on transparency and green/magenta backdrops. They compare the
whole processed silhouette with the same input without ground, including scale
and position, allowing less than 0.3% extra or missing alpha-weighted foreground.
Separate white/silver body, low sill and tire fixtures check against erasure of
light vehicle parts. These are constructed regression fixtures, not a new live
AI generation or a copy of the user's currently faulty image.

Reproduce from the repository root:

```powershell
node --test --test-concurrency=1 functions/*.test.js
```

Optional local visual evidence (not needed in CI):

```powershell
$env:VEHICLE_HERO_QA_DIR = Join-Path $env:TEMP 'plaqa-hero-floor-qa'
node --test --test-name-pattern='floor touching' functions/vehicle_hero_image.test.js
```

The optional PNG previews are composited on dark blue to make residual ground
visible; the production output remains transparent. The white-floor and soft
oval/chroma before/after previews were visually inspected.

## Production activation

After explicit approval, deployed only `requestVehicleHeroImage` to
`carma-a84e4` in `europe-west3` using Node 22. The Firebase deployment completed
successfully; the new revision is `requestvehicleheroimage-00017-xug`.

The service still had 100% of traffic pinned to revision `00014-gap` from a
previous rollback. First attached a temporary zero-traffic tag to the new
revision, checked its OPTIONS preflight (HTTP 204), and verified both Ready and
Active were true. Then moved 100% of traffic to `00017-xug` and removed the
temporary tag. Readback confirmed the new revision receives all traffic and
the service is Ready. The preflight is a reachability check, not an image test.

## Redmi App Check repair

The user's new image request was rejected with Auth VALID and App Check INVALID.
The installed Redmi app is a debug build. Its on-device App Check debug secret
failed the Firebase exchange with HTTP 403 / App attestation failed. The client
misleadingly presented this as a request to sign in again.

Registered only that existing private debug credential for the Android app,
labelled `Redmi cf1d4c97 Debug 2026-09-05`. The subsequent limited-use exchange
succeeded and returned an App Check JWT with a 300-second TTL. Credentials were
not printed or saved in the repository. App Check enforcement, production
providers, user authorization and generation limits were not disabled.

Restarted only Plaqa on the device without clearing data or signing out. No
Flutter source change or APK installation was needed for this registration.
Readback of the app's own cache then showed a fresh App Check JWT issued at
`2026-09-04T23:55:43Z`, valid until `2026-09-05T00:55:43Z`, for the expected
Plaqa Android app. Only issue/expiry times and the matching-app boolean were
reported, not the token. No new callable request had arrived at the log check.

## Remaining live check

No paid image generation or regeneration of existing vehicles was performed by
the agent. The user was asked to try generation for the newly added vehicle.
Successful generation and its appearance in the profile header and vehicle card
still require confirmation. Do not mass-regenerate existing example vehicles.

No universal guarantee for arbitrary generated ground is implied by the local
fixtures. Ground that cannot be separated conservatively from light bodywork
still requires a real-image check.
