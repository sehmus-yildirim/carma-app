# plaqa Google Play Store Listing (de-DE)

Stand: 2026-08-22

Dieses Dokument ist die lokale, deutsche Vorlage fuer den Haupt-Store-Eintrag. Es wurde noch nichts in die Play Console hochgeladen oder dort gespeichert. Vor einem spaeteren Upload muessen die unten genannten Release-Gates erneut geprueft werden.

## Produktdetails

- App-Name: `plaqa`
- Zeichenanzahl App-Name: 5 von maximal 30
- Standardsprache: Deutsch
- App-Typ: App
- Preismodell: Kostenlos
- Mindestalter: 16 Jahre

## Kurzbeschreibung

Zeichenanzahl: 67 von maximal 80

```text
Fahrzeugprofile, Beiträge und Kontaktanfragen rund ums Kennzeichen.
```

## Vollständige Beschreibung

Zeichenanzahl: 1.710 von maximal 4.000, inklusive Leerzeichen und Zeilenumbruechen im folgenden Textblock.

```text
plaqa bringt Menschen über ihre Fahrzeuge zusammen. Erstelle ein persönliches Fahrzeugprofil, teile Beiträge und Storys und entscheide selbst, welche Informationen andere sehen dürfen.

Dein Fahrzeugprofil

Präsentiere deine Fahrzeuge mit Fotos, technischen Daten, Ausstattung, Umbauten und einer Timeline. Lege ein Hauptfahrzeug für dein Profil fest und verwalte weitere Fahrzeuge getrennt.

Community und Beiträge

Entdecke neue Beiträge von Profilen, denen du folgst. Teile eigene Fotos oder Videos, hinterlasse Likes und Kommentare und antworte direkt auf Kommentare. Storys ermöglichen kurze Einblicke, die nur vorübergehend sichtbar sind.

Kontakt rund ums Kennzeichen

Wenn ein Fahrzeug über sein Kennzeichen auffindbar ist, kannst du mit einem nachvollziehbaren Grund eine Kontaktanfrage senden. Ein persönlicher Chat wird erst möglich, nachdem die Anfrage angenommen wurde. So bleibt die Kontaktaufnahme kontrolliert und zweckgebunden.

Privatsphäre nach deinen Regeln

Du entscheidest, wer dein Profil, deine Beiträge, Storys und freigegebenen Fahrzeugdaten sehen darf. Einstellungen für Kontaktanfragen, Chats und Kennzeichen lassen sich getrennt verwalten. E-Mail-Adresse, Telefonnummer, Geburtsdatum und Dokumente erscheinen nicht im öffentlichen Profil.

Sicherheit und respektvoller Austausch

Blockiere Nutzer, melde problematische Inhalte oder Konten und nutze die vorgesehenen Sicherheits- und Supportwege. Community-Richtlinien und Kinderschutzstandards geben klare Regeln für einen verantwortungsvollen Umgang vor.

plaqa ist für Personen ab 16 Jahren vorgesehen. Nutze Kennzeichen- und Kontaktfunktionen nur für legitime, nachvollziehbare Anliegen und respektiere die Privatsphäre anderer.
```

## Kategorieempfehlung

- Empfohlene Kategorie: `Social`
- Begruendung: Profile, Folgen, Feed, nutzergenerierte Beitraege und Storys, Kontaktanfragen, Kommentare sowie Chats bilden den Hauptzweck. Der Fahrzeugbezug ist das Thema der Community, nicht nur ein Fahrzeug-Nachschlagewerk.
- Alternative nur nach erneuter Produktpruefung: `Auto & Vehicles`. Diese Kategorie waere erst passender, wenn Social Feed und Nutzerkommunikation nicht mehr den Kern der App bilden.

## Kontakt und öffentliche Seiten

- Support-E-Mail: `support@plaqa.de`
- Website: `https://plaqa.de`
- Datenschutz: `https://plaqa.de/datenschutz/`
- Kontoloeschung: `https://plaqa.de/konto-loeschen/`
- Kinderschutz: `https://plaqa.de/kinderschutz/`

## Bewusst nicht beworbene Funktionen

Die folgenden Funktionen werden im Store-Text nicht als verfuegbar oder fertig dargestellt:

- KI-generierte Fahrzeugbilder, solange Kosten, Rate-Limits und der komplette Liveablauf nicht freigegeben sind.
- Dokumenten- und Identitaetsverifizierung, solange Functions, Cleanup und echte Pruefprozesse nicht live abgenommen sind.
- Zwei-Faktor-Authentifizierung als Store-Vorteil, solange alle Enrollment-, Login-, Recovery- und Entfernen-Ablaufe nicht abschliessend live geprueft sind.
- Live-Profilstatistiken, solange `recordProfileView` nicht veroeffentlicht und mit mehreren Konten getestet wurde.
- Ablauf-Erinnerungen fuer Dokumente, solange Scheduler, Benachrichtigung und Datenbereinigung nicht live nachgewiesen sind.
- Push-Benachrichtigungen, solange Berechtigungen, Zustellung und Stummmodus-Verhalten nicht releasefertig geprueft sind.
- Unbegrenzte Kennzeichenanfragen, absolute Sicherheit, vollstaendige Anonymitaet oder andere unbelegbare Garantien.

## Release-Gates vor dem Upload

- Blaze-abhaengige Kern-Functions fuer Fahrzeugverwaltung und geplante Releasefunktionen gezielt deployen.
- Store-Text gegen den tatsaechlich hochzuladenden AAB-Stand pruefen.
- Social Feed, Storys, Kontaktanfragen, Chats, Melden und Blockieren mit mehreren Konten live testen.
- Rechtstexte und ladungsfaehige Anschrift nach dem geplanten Umzug extern pruefen.
- Keine Store-Angabe veroeffentlichen, wenn eine im Text genannte Kernfunktion im Release-Build nicht nutzbar ist.

