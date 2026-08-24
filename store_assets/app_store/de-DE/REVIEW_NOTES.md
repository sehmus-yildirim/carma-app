# plaqa App Review Notes (de-DE)

Stand: 2026-08-25

## App-Zweck

plaqa ist eine soziale Fahrzeug-Community ab 16 Jahren. Nutzer verwalten
Fahrzeugprofile, teilen Beitraege und Storys, folgen Profilen und koennen nach
einer angenommenen fahrzeugbezogenen Kontaktanfrage chatten.

## Zugang fuer App Review

- Das vorbereitete Review-Testkonto ist ausschliesslich im geschuetzten
  App-Review-Informationsfeld von App Store Connect hinterlegt.
- Zugangsdaten duerfen nicht in diesem Repository gespeichert werden.
- Falls E-Mail-Bestaetigung oder MFA fuer das Testkonto erforderlich ist, muss
  der konkrete Review-Ablauf vor Einreichung erneut kontrolliert werden.

## Wichtige Navigationswege

- Kennzeichensuche: `Suchen`
- Feed und Profil: `Profil`, danach Haus- beziehungsweise Profil-Symbol
- Kontaktanfragen und Chats: `Chats`
- Fahrzeughinweis: `Melden`
- Datenschutz und Kontoloeschung: `Einstellungen`

## Moderation und Sicherheit

- Profile, Inhalte und Kommentare koennen gemeldet werden.
- Nutzer koennen blockiert werden.
- Oeffentlicher Kinderschutzstandard:
  `https://plaqa.de/kinderschutz/`
- Meldestelle: `https://plaqa.de/meldestelle/`

## Apple-Anmeldung

Der Dart-Flow fuer „Mit Apple fortfahren“, Kontoverknuepfung, erneute
Authentifizierung und Token-Widerruf bei Kontoloeschung ist vorbereitet.
Apple-Capability, Firebase-Provider, benutzerdefinierter SMTP-Absender und
Private Email Relay sind konfiguriert. Vor Einreichung bleibt der echte iPhone-
Test einschliesslich Relay-Zustellung und Widerruf erforderlich.

## Verifizierung und Dokumente

Die freiwillige Dokumentenverifizierung ist nicht fuer die Basisnutzung der
Community erforderlich. Vor einer Review-Einreichung muessen Upload,
Pruefstatus, Zugriffsschutz und automatisches Cleanup live geprueft sein. Wenn
dieser Ablauf im eingereichten Build nicht freigegeben ist, darf er dem Review
nicht als nutzbare Kernfunktion beschrieben werden.

## Bekannte Release-Gates

- Signing, Provisioning, Background Modes und Push-Zustellung auf Mac/iPhone
- App Attest/DeviceCheck und App Check weiterhin nur Monitoring
- Universal Links sind fuer Version 1 deaktiviert; eine spaetere Einfuehrung
  benoetigt AASA-Datei, Routing, Capability, Provisioning und Geraetetest
- iOS-Build, Signierung, TestFlight und echter iPhone-Test
- externe rechtliche Endpruefung und neue Anschrift vor Release
- finaler Abgleich der Store-Angaben und der unveroeffentlichten Privacy Labels
  gegen den eingereichten Build

Es wurde noch nichts in App Store Connect eingereicht oder veroeffentlicht.
