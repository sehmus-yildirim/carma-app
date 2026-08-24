# Apple Private Email Relay

Stand: 24. August 2026

## Zweck

Apple-Nutzer koennen bei Sign in with Apple ihre echte E-Mail-Adresse verbergen.
Apple stellt dann eine Adresse unter `privaterelay.appleid.com` bereit. Damit
Firebase-Konto- und Sicherheitsmails diese Nutzer erreichen, muss die echte
ausgehende E-Mail-Quelle im Apple Developer Portal registriert und authentifiziert
sein.

## Gepruefter Firebase-Stand

- Firebase-Projekt: `carma-a84e4`
- iOS-Bundle-ID: `de.plaqa.app`
- autorisierte benutzerdefinierte Domain: `auth.plaqa.de`
- technische Firebase-Callback-URL:
  `https://carma-a84e4.firebaseapp.com/__/auth/handler`
- Sprache der Firebase-E-Mail-Vorlagen: Deutsch
- benutzerdefinierter SMTP-Server: aktiviert
- SMTP-Transport: IONOS, Port 587 mit STARTTLS

`auth.plaqa.de` ist die Domain der Aktionslinks. Sie versendet selbst keine
E-Mails und ist deshalb keine Apple-E-Mail-Quelle. Die Domain ist in Firebase als
benutzerdefinierte autorisierte Domain eingetragen und zeigt per CNAME auf das
Firebase Hosting des Projekts.

## Tatsaechlicher Absender

Eine am 20. August 2026 ueber Firebase Authentication erzeugte
Passwort-zuruecksetzen-Mail wurde anhand der empfangenen Original-Header geprueft.

- From: `no-reply@plaqa.de`
- Return-Path / Envelope Sender: `no-reply@plaqa.de`
- DKIM-Domain: `plaqa.de`
- DKIM-Selector: `s1-ionos`
- Aktionslink-Domain: `auth.plaqa.de`
- Transportverschluesselung beim Empfang: TLS

Die Firebase-Vorlagenansicht zeigt in ihrer Standardvorschau weiterhin
`noreply@carma-a84e4.firebaseapp.com`. Der tatsaechliche neuere Versand nach der
SMTP-Einrichtung erfolgt jedoch nachweislich ueber `no-reply@plaqa.de`. Aeltere
Mails vor der SMTP-Umstellung wurden noch ueber die Firebase-Standardadresse
versendet.

## Authentifizierung der Domain

Die oeffentlichen DNS-Eintraege und die empfangenen Mail-Header wurden geprueft.

| Pruefung | Ergebnis |
| --- | --- |
| SPF | PASS; `plaqa.de` autorisiert IONOS ueber `_spf-eu.ionos.com` |
| DKIM | PASS; Signaturdomain `plaqa.de` |
| DMARC | PASS; vorhandene Richtlinie derzeit `p=none` |
| Return-Path-Abgleich | PASS; `no-reply@plaqa.de` |
| From-/DKIM-Abgleich | PASS; jeweils `plaqa.de` |

Die vorhandenen IONOS-MX-, SPF-, DKIM- und DMARC-Eintraege wurden nicht
veraendert.

## Bei Apple zu registrierende Quelle

Als engste und aktuell belegte Quelle ist zu registrieren:

`no-reply@plaqa.de`

Nicht als Quelle registrieren:

- `auth.plaqa.de`, solange diese Domain keine E-Mail versendet
- `noreply@carma-a84e4.firebaseapp.com`, solange der produktive Versand nicht
  wieder auf den Firebase-Standarddienst zurueckgestellt wird
- Support- oder Datenschutzadressen, solange sie keine automatischen Nachrichten
  an Apple-Relay-Adressen senden

Die Registrierung erfolgt im Apple Developer Portal unter Certificates,
Identifiers & Profiles, Services, Sign in with Apple for Email Communication.
Die Apple-Developer-Mitgliedschaft ist aktiv. `no-reply@plaqa.de` wurde als
Quelle registriert; die vorhandenen IONOS-Mail-DNS-Eintraege wurden dabei nicht
veraendert.

## Firebase-Vorlagen

Statisch geprueft wurden:

- Bestaetigung der E-Mail-Adresse
- Passwortzuruecksetzung
- Aenderung der E-Mail-Adresse und Wiederherstellung der alten Adresse
- Benachrichtigung ueber Multi-Faktor-Anmeldung

Die Vorlagen sind auf Deutsch eingestellt und verwenden `auth.plaqa.de` fuer
Aktionslinks. Die Firebase-Konsole weist derzeit keinen eigenen sichtbaren
Absendernamen aus. Vor dem spaeteren Produktionsstart sollte kontrolliert werden,
ob der Anzeigename in allen Mailprogrammen als `plaqa` erscheint.

Eine Passwortzuruecksetzung ist fuer ein reines Apple-Konto ohne verknuepften
E-Mail-/Passwort-Anbieter nicht anwendbar. Sie darf nur mit einem Konto getestet
werden, das diesen Anbieter tatsaechlich verwendet.

## Spaetere Relay-Testmatrix

Der echte Test wird erst mit einem freigegebenen Apple-Testkonto und nach
Registrierung der E-Mail-Quelle ausgefuehrt.

1. Mit Apple anmelden und E-Mail-Adresse verbergen.
2. Kontrollieren, dass Firebase eine Adresse unter
   `privaterelay.appleid.com` speichert.
3. Eine fuer den Kontotyp anwendbare Firebase-Mail ausloesen.
4. Zustellung im echten Apple-Postfach kontrollieren.
5. From, Return-Path, SPF, DKIM und DMARC erneut pruefen.
6. Kontrollieren, dass der Aktionslink `auth.plaqa.de` verwendet.
7. Sicherstellen, dass Apple keine Bounce-Meldung erzeugt.
8. E-Mail-Aenderungs-, Wiederherstellungs- und MFA-Mails getrennt pruefen,
   sofern der Testkontostand diese Vorgaenge zulaesst.

Es wurde keine Relay-Testmail versendet, kein Produktionskonto veraendert und
keine Kontoloeschung ausgefuehrt.

## Offene Schritte

- sichtbaren Firebase-Absendernamen in mehreren Mailprogrammen kontrollieren
- echten Relay-Test mit einer Apple-Adresse unter `privaterelay.appleid.com`
  auf einem Apple-Geraet durchfuehren
- Apple-Login, Verknuepfung, Reauthentifizierung und Widerruf live pruefen
- Zustellung und Bounce-Verhalten fuer alle anwendbaren Sicherheitsmails testen
