# plaqa E-Mail-Vorlagen

Die Vorlagen bilden ein gemeinsames, dunkles plaqa-Maildesign mit blauem
Hauptakzent und orangefarbenem Sicherheitshinweis. Sie verwenden tabellenbasiertes
HTML und Inline-CSS, damit sie auch in konservativen Mailclients stabil bleiben.
Es werden keine Skripte, Formulare, Webfonts oder Tracking-Pixel eingebunden.

## Automatische Konto-E-Mails

Firebase stellt weiterhin die sicheren, einmalig verwendbaren Aktionscodes
bereit. Für die drei regulären Kontoflüsse erzeugen Cloud Functions daraus den
Aktionslink und versenden die vollständig gestaltete HTML-Mail über den
IONOS-SMTP-Server von `no-reply@plaqa.de`. Die öffentliche Aktionsseite bleibt
`https://auth.plaqa.de/auth/action`.

| Kontofluss | Datei | Callable Function | Betreff |
| --- | --- | --- | --- |
| E-Mail-Adresse bestätigen | `auth/verify-email.html` | `sendBrandedEmailVerification` | `Bestätige deine E-Mail-Adresse für plaqa` |
| Passwort zurücksetzen | `auth/reset-password.html` | `sendBrandedPasswordResetEmail` | `Setze dein plaqa Passwort zurück` |
| E-Mail-Adresse ändern | `auth/change-email.html` | `sendBrandedEmailChangeVerification` | `Bestätige deine neue E-Mail-Adresse für plaqa` |

Die produktive Rendering- und Versandlogik liegt in
`functions/branded_email.js`. Die HTML-Dateien in diesem Ordner sind die
visuell prüfbaren Referenzen desselben Designs.

Gemeinsame Firebase-Werte:

- Absendername: `plaqa`
- Absender: `no-reply@plaqa.de`
- Antwortadresse: `support@plaqa.de`
- Format: `HTML` mit Textfallback
- sichtbare Aktion: Button statt ausgeschriebener Aktions-URL
- Logo: `https://plaqa.de/assets/plaqa_logo_transparent.png`
- SMTP-Secret: `PLAQA_NOREPLY_SMTP_PASSWORD`
- App Check: Monitoring, keine Erzwingung
- Missbrauchsschutz: serverseitige, gehashte Versandlimits ohne Klartextadresse

SMTP-Passwort, Firebase-Aktionscodes und vollständige Aktionslinks dürfen weder
im Repository noch in Logs oder Screenshots gespeichert werden.

### Multi-Faktor-Sicherheit

Der von Firebase erzeugte Widerrufslink nach dem Hinzufügen eines zweiten
Faktors bleibt vorerst beim sicherheitskritischen Firebase-Fallback. Die Datei
`auth/mfa-added.html` ist eine geprüfte Designvorlage, wird aber nicht als live
markiert, solange der Widerrufsfluss nicht mit gleicher Sicherheitswirkung
serverseitig ersetzt werden kann. Es wird bewusst keine zweite Mail verschickt,
die den Firebase-Widerruf nur optisch nachahmt.

## Postfach-Eingangsbestätigungen

Für die echten IONOS-Postfächer sind jeweils HTML- und Textfassungen vorhanden:

| Postfach | HTML | Text-Fallback |
| --- | --- | --- |
| `support@plaqa.de` | `mailboxes/support-auto-reply.html` | `mailboxes/support-auto-reply.txt` |
| `privacy@plaqa.de` | `mailboxes/privacy-auto-reply.html` | `mailboxes/privacy-auto-reply.txt` |
| `partners@plaqa.de` | `mailboxes/partners-auto-reply.html` | `mailboxes/partners-auto-reply.txt` |

Die frueheren IONOS-Textantworten sind deaktiviert. Drei live bereitgestellte
Cloud Functions lesen die Postfaecher kontrolliert aus und versenden die gestalteten
HTML-Eingangsbestaetigungen mit Textfallback. Die Functions laufen alle fuenf
Minuten und verwenden jeweils ein eigenes Secret fuer das Postfachpasswort:

| Postfach | Function | Secret |
| --- | --- | --- |
| `support@plaqa.de` | `processSupportMailboxAutoReplies` | `PLAQA_SUPPORT_MAILBOX_PASSWORD` |
| `privacy@plaqa.de` | `processPrivacyMailboxAutoReplies` | `PLAQA_PRIVACY_MAILBOX_PASSWORD` |
| `partners@plaqa.de` | `processPartnersMailboxAutoReplies` | `PLAQA_PARTNERS_MAILBOX_PASSWORD` |

Die Auto-Antworten bestaetigen nur den Eingang. Sie versprechen weder eine
Bearbeitungszeit noch ein Ergebnis. Schutz vor Schleifen und doppelten
Antworten wird serverseitig umgesetzt.

`info@plaqa.de` bleibt bewusst ohne automatische Vorlage.

## Live-Stand und offene Prüfung

1. `PLAQA_NOREPLY_SMTP_PASSWORD` ist als Firebase Functions Secret angelegt.
2. Nur die drei oben genannten Callable Functions wurden am 2026-08-25
   deployt; sie sind aktiv, v2, Node.js 22 und laufen in `europe-west3`.
3. Verifizierung, Passwort-Reset und E-Mail-Wechsel mit einem freigegebenen
   Testkonto prüfen.
4. Die drei IONOS-Textantworten sind deaktiviert. Die drei HTML-Postfach-
   Functions sind deployt und aktiv.
5. Die Designs wurden mit Testnachrichten visuell in Outlook geprueft.

## Ziele nach dem Klick

- Kontoaktionen: `https://auth.plaqa.de/auth/action`
- Support: `https://plaqa.de/support/`
- Datenschutz: `https://plaqa.de/datenschutz/`
- Partnerschaften: `https://plaqa.de/partner/`

Die Kontoaktionsseite bietet ausschliesslich fuer die Designpruefung sichere
Vorschauzustaende ueber den Parameter `preview`. Diese Zustaende fuehren keine
Kontoaktion aus. Produktive Links enthalten weiterhin einen einmalig
verwendbaren Firebase-Aktionscode.

Vor einer neuen App-Freigabe müssen die drei Kontoflüsse mit einem freigegebenen
Testkonto geprüft werden. Ein nur lokal vorhandenes Template gilt nie als live.

## Inhaltliche Regeln

- Support bestätigt nur den Eingang und verspricht keine feste Bearbeitungszeit.
- Datenschutz bestätigt nur den Eingang, fordert keine Ausweisdokumente per
  E-Mail an und behauptet keine abgeschlossene Identitätsprüfung oder Löschung.
- Partnerschaften bestätigt nur den Eingang und ist keine Zusage oder
  vertragliche Vereinbarung.
- Sicherheitslinks werden ausschließlich zur Laufzeit aus Firebase-Aktionscodes
  erzeugt und niemals in Logs, Screenshots oder Dokumentation gespeichert.
- Passwort, Bestätigungscode, SMTP-Zugangsdaten und andere Geheimnisse werden
  niemals per E-Mail angefordert.

## Zuständigkeiten

- allgemeine Anfragen: `info@plaqa.de`
- automatische Konto-E-Mails: `no-reply@plaqa.de`
- Nutzerhilfe: `support@plaqa.de`
- Datenschutzanfragen: `privacy@plaqa.de`
- Kooperationen: `partners@plaqa.de`
