# MFA Recovery: Release-Checkliste

## Admin-Custom-Claim

Adminrechte werden ausschließlich mit Application Default Credentials in
einer vertrauenswürdigen Verwaltungsumgebung geändert. Niemals einen
Service-Account-Schlüssel in das Repository legen.

```powershell
$env:PLAQA_ADMIN_OPERATOR_UID='UID_DER_HANDELNDEN_PERSON'
node tools/set_admin_claim.js status ZIEL_UID
node tools/set_admin_claim.js grant ZIEL_UID "ADMINRECHT VERGEBEN"
node tools/set_admin_claim.js revoke ZIEL_UID "ADMINRECHT ENTFERNEN"
```

Nach `grant` oder `revoke` muss sich das Zielkonto vollständig ab- und neu
anmelden. Erst das neue ID-Token enthält den aktualisierten Claim.

## App Check

App Check ist aktuell absichtlich **nicht erzwungen**. Das Paket ist im
Flutter-Client initialisiert: Android Release verwendet Play Integrity,
Apple Release App Attest mit DeviceCheck-Fallback und Debug-Builds den
Debug-Provider. Vor einer Erzwingung sind diese Schritte notwendig:

1. Android- und iOS-App in Firebase App Check registriert bestätigen.
2. Play Integrity, App Attest und die korrekten Signierzuordnungen in Firebase
   kontrollieren.
3. Debug-Token ausschließlich in der Firebase Console registrieren, niemals
   im Repository speichern.
4. Debug und signierten Release-Build gegen alle Recovery-Callables testen.
5. In der App-Check-Metrik kontrollieren, dass gültige Requests ankommen.
6. Erst danach bei allen MFA-Recovery-Callables `enforceAppCheck: true`
   setzen. Für administrative Mutationen zusätzlich
   `consumeAppCheckToken: true` aktivieren und Retry-Verhalten testen.

App Check ersetzt weder Firebase Authentication noch das `admin` Custom
Claim oder die Vier-Augen-Freigabe.

## Sitzungswiderruf

Nach der zweiten Freigabe widerruft der Server Refresh-Tokens und speichert
`tokensValidAfterTime`, bevor MFA entfernt wird. Bereits ausgegebene ID-Tokens
können außerhalb der zusätzlich geschützten Recovery-Endpunkte bis zu ihrem
Ablauf weiter funktionieren. Der Live-Test muss deshalb prüfen:

1. Alte Admin-Sitzung wird von Recovery-Callables abgewiesen.
2. Altes Nutzer-Refresh-Token kann kein neues ID-Token beziehen.
3. Frische Anmeldung ist erforderlich.
4. MFA muss danach neu eingerichtet werden.

Der Test darf nur mit einem ausdrücklich freigegebenen Testkonto erfolgen.

## Interne Admin-Oberfläche

`tools/mfa_recovery_admin` ist nicht Teil der Nutzer-App und wird nicht durch
die öffentliche Navigation erreicht. Vor internem Hosting müssen Domain-
Zugriffsschutz, App Check und ein eigener Admin-Anmeldeprozess geprüft sein.
