# plaqa Auth-E-Mail-Vorlagen

Diese Werte werden in Firebase Authentication unter `Templates` verwendet.
Die öffentliche Domain darf erst aktiviert werden, nachdem `auth.plaqa.de` mit
Firebase Hosting verbunden und als autorisierte Auth-Domain eingetragen wurde.

## E-Mail-Adresse bestätigen

- Absendername: `plaqa`
- Antwortadresse: `support@plaqa.de`
- Betreff: `Bestätige deine E-Mail Adresse für plaqa`
- Action URL: `https://auth.plaqa.de/auth/action`

Hallo %DISPLAY_NAME%,

bestätige bitte deine E-Mail Adresse, damit dein plaqa Konto vollständig
geschützt ist.

%LINK%

Wenn du kein plaqa Konto erstellt hast, kannst du diese E-Mail ignorieren.

Viele Grüße
dein plaqa Team

## Passwort zurücksetzen

- Absendername: `plaqa`
- Antwortadresse: `support@plaqa.de`
- Betreff: `Dein plaqa Passwort zurücksetzen`
- Action URL: `https://auth.plaqa.de/auth/action`

Hallo %DISPLAY_NAME%,

über den folgenden Link kannst du ein neues Passwort für dein plaqa Konto
festlegen:

%LINK%

Wenn du das Zurücksetzen nicht angefordert hast, kannst du diese E-Mail
ignorieren.

Viele Grüße
dein plaqa Team

## E-Mail-Adresse ändern oder wiederherstellen

- Absendername: `plaqa`
- Antwortadresse: `support@plaqa.de`
- Action URL: `https://auth.plaqa.de/auth/action`

Die Texte benennen die alte und neue Adresse über die von Firebase
bereitgestellten Platzhalter und verweisen bei einer unbekannten Änderung auf
`support@plaqa.de`.

## Zuständigkeiten

- allgemeine Anfragen: `info@plaqa.de`
- automatische Konto-E-Mails: `no-reply@plaqa.de`
- Nutzerhilfe und Antwortadresse: `support@plaqa.de`
- Datenschutzanfragen: `privacy@plaqa.de`
- Kooperationen: `partners@plaqa.de`
