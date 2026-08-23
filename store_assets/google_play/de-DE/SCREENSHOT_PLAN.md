# plaqa Google Play Screenshot-Konzept (de-DE)

Stand: 2026-08-22

Ziel sind acht echte Smartphone-Aufnahmen im Hochformat. Dieses Dokument beschreibt nur die spaetere Aufnahme; es wurden keine Screenshots kuenstlich nachgebaut oder in die Play Console hochgeladen.

## Technische Vorgaben

- Endformat je Screenshot: 1080 x 1920 Pixel, Seitenverhaeltnis 9:16.
- Dateiformat: 24-Bit-PNG oder JPEG ohne Transparenz.
- Nur die echte Release-App und reale UI-Zustaende aufnehmen.
- Fuer alle Aufnahmen dasselbe isolierte Demo-Konto und denselben konsistenten Demo-Datensatz verwenden.
- Statusleiste bereinigen: keine Benachrichtigungen, kein Netzbetreiber, keine persoenlichen Uhrzeit- oder Geraetehinweise.
- Keine Debug-Badges, `BEISPIEL`-Markierungen, roten Fehlerbanner oder Ladezustaende.
- Keine echten Namen, E-Mail-Adressen, Telefonnummern, Kennzeichen, Standorte, Dokumente oder Chat-Inhalte.
- Keine fremden Fahrzeugmarken, Markenlogos, geschuetzten Bilder oder echten Kennzeichen zeigen.
- Zusaetzliche Ueberschriften sind optional. Die ersten drei Bilder sollen vor allem die echte App-Oberflaeche zeigen.
- Jeder Alt-Text bleibt unter 140 Zeichen.

## Einheitlicher Demo-Datensatz

- Fiktiver Anzeigename ohne Bezug zu einer realen Person.
- Neutrales Profilbild oder freigegebene, synthetische Darstellung.
- Generisches Fahrzeug ohne sichtbares Herstellerlogo.
- Kennzeichen in Such- und Profilansichten unkenntlich oder als klarer, isolierter Testdatensatz dargestellt.
- Beitraege, Kommentare und Chats enthalten kurze, sachliche Inhalte ohne reale Personen- oder Ortsdaten.
- Mindestens zwei weitere isolierte Demo-Konten fuer Feed, Folgen, Likes, Kommentare, Kontaktanfragen und Chats.

## 1. Startseite mit Storys und Beitragsfeed

- App-Seite: Navigation `Profil`, danach Haus-Symbol.
- Kernfunktion: Story-Leiste und aktueller Feed von gefolgten Profilen.
- Optionale Ueberschrift: `Deine Fahrzeug-Community auf einen Blick`
- Demo-Zustand: Drei neutrale Story-Profilbilder; ein vollstaendiger Beitrag mit generischem Fahrzeug, Like-, Kommentar- und Teilen-Aktionen.
- Ausblenden: Debug-Kennzeichnungen, echte Profilbilder, reale Orte und echte Kennzeichen.
- Alt-Text: `plaqa Startseite mit Storys und einem Fahrzeugbeitrag aus dem persönlichen Feed.`
- Livetest vor Aufnahme: Ja, Feed-Sortierung, Sichtbarkeit und Story-Status mit mindestens zwei Konten.

## 2. Kennzeichensuche und Kontaktaufnahme

- App-Seite: Navigation `Suchen`, ausgefuelltes Suchformular vor dem Absenden oder ein datenschutzsicheres Suchergebnis.
- Kernfunktion: Land, Kennzeichen und begruendete Kontaktanfrage.
- Optionale Ueberschrift: `Kontakt mit einem nachvollziehbaren Anlass`
- Demo-Zustand: Isoliertes Testkennzeichen; neutraler Kontaktgrund; keine private Halterinformation.
- Ausblenden: Reale Kennzeichen, genauer Standort, Suchkontingente und technische Projektbezeichnungen.
- Alt-Text: `Kennzeichensuche in plaqa mit Länderauswahl und kontrollierter Kontaktanfrage.`
- Livetest vor Aufnahme: Ja, Suche, Auffindbarkeit, Kontaktgrund und Berechtigungsregeln mit zwei Testkonten.

## 3. Persönliches Profil und Hauptfahrzeug

- App-Seite: Navigation `Profil`, Profil-Symbol, Register `Beiträge`.
- Kernfunktion: Profilkopf mit Anzeigename, Region, Hauptfahrzeug, Kennzeichenanzeige und Beitragsuebersicht.
- Optionale Ueberschrift: `Dein Profil. Dein Fahrzeug.`
- Demo-Zustand: Fiktiver Nutzer, generisches Hauptfahrzeug, mehrere neutrale Beitraege.
- Ausblenden: Echte Initialen, reale Region, reale Follower-Daten und echte Kennzeichen.
- Alt-Text: `Persönliches plaqa Profil mit Hauptfahrzeug, Profilinformationen und Beitragsübersicht.`
- Livetest vor Aufnahme: Ja, Profilbild-, Anzeigenamen-, Hauptfahrzeug- und Zaehler-Synchronisierung.

## 4. Fahrzeugprofil mit Galerie und Fahrzeugdaten

- App-Seite: Navigation `Profil`, Profil-Symbol, Register `Fahrzeug`.
- Kernfunktion: Fahrzeugkarte, vier Informationen, Galerie-Kategorien und Fahrzeugdaten.
- Optionale Ueberschrift: `Dein Fahrzeug im Detail`
- Demo-Zustand: Generisches Fahrzeug; neutrale Galerieinhalte; plausible, nicht identifizierende technische Daten.
- Ausblenden: Herstellerlogo, VIN, HSN/TSN, reale Laufleistung und echte Zulassungsdaten.
- Alt-Text: `Fahrzeugprofil in plaqa mit Galerie, technischen Angaben und übersichtlicher Fahrzeugkarte.`
- Livetest vor Aufnahme: Ja, Speichern, erneutes Laden und Trennung mehrerer Fahrzeuge nach Function-Deploy.

## 5. Beiträge, Likes und Kommentare

- App-Seite: Geoeffneter eigener Beitrag im Profil.
- Kernfunktion: Medienbeitrag, Like-Aktion, Kommentare und sichtbare Antworten.
- Optionale Ueberschrift: `Teile, was dich bewegt`
- Demo-Zustand: Ein freigegebenes generisches Fahrzeugfoto; sachliche Beispielkommentare aus isolierten Demo-Konten.
- Ausblenden: Testzaehler, Platzhalterprofile, echte Nutzernamen, reale Orte und fremde Marken.
- Alt-Text: `Geöffneter Fahrzeugbeitrag mit Likes, Kommentaren und eingerückten Antworten.`
- Livetest vor Aufnahme: Ja, Live-Zaehler, Profilbilder, Anzeigenamen, Antworten und Loeschrechte.

## 6. Chats und Kontaktanfragen

- App-Seite: Navigation `Chats`, angenommene Kontaktanfrage und geoeffnete Unterhaltung.
- Kernfunktion: Erst anfragen, dann chatten; Text- und Medienaktionen sichtbar, aber ohne reale Inhalte.
- Optionale Ueberschrift: `Erst anfragen, dann chatten`
- Demo-Zustand: Zwei isolierte Demo-Konten mit angenommener Anfrage und kurzer sachlicher Unterhaltung.
- Ausblenden: Telefonnummern, E-Mail-Adressen, reale Nachrichten, Standorte, Dateien und Sprachnachrichteninhalte.
- Alt-Text: `plaqa Chat nach angenommener Kontaktanfrage mit klarer und privater Unterhaltung.`
- Livetest vor Aufnahme: Ja, Anfrage, Annahme, Nachrichtenzustellung, Lesestatus, Blockieren und Abmelden.

## 7. Melden, Blockieren und Community-Sicherheit

- App-Seite: Navigation `Melden` oder Meldeaktion an einem neutralen Demo-Beitrag.
- Kernfunktion: Strukturierter Meldeweg, Blockierung und Hinweis auf Community-Sicherheit.
- Optionale Ueberschrift: `Melden und blockieren, wenn es nötig ist`
- Demo-Zustand: Neutrale Kategorie ohne bedenklichen Bildinhalt; Formular noch nicht mit echten Daten abgesendet.
- Ausblenden: Reale Vorfaelle, Dokumentbilder, personenbezogene Beweise und interne Prueferinformationen.
- Alt-Text: `Strukturierter Meldeweg in plaqa mit Kategorien für Sicherheit und Community-Schutz.`
- Livetest vor Aufnahme: Ja, Rules, Support-Zuordnung, Blockierungswirkung und Berechtigungen.

## 8. Privatsphäre, Kontoschutz und Einstellungen

- App-Seite: Navigation `Einstellungen`, Bereich `Privatsphäre` oder `Konto & Sicherheit`.
- Kernfunktion: Sichtbarkeit, Kontaktanfragen, Chat-Privatsphaere, Story-Einstellungen und Kontoschutz.
- Optionale Ueberschrift: `Du entscheidest, was sichtbar ist`
- Demo-Zustand: Konsistente, gespeicherte Schalterzustaende ohne eingeblendete private Kontodaten.
- Ausblenden: E-Mail-Adresse, Telefonnummer, MFA-Faktor, Sitzungsdaten und interne Systemnamen.
- Alt-Text: `Privatsphäre-Einstellungen in plaqa für Sichtbarkeit, Kontaktanfragen, Chats und Storys.`
- Livetest vor Aufnahme: Ja, Speichern, erneutes Laden und direkte Wirkung der Sichtbarkeitseinstellungen.

## Empfohlene Reihenfolge im Store

1. Startseite und Feed
2. Kennzeichensuche
3. Persoenliches Profil
4. Fahrzeugprofil
5. Beitraege und Kommentare
6. Chats und Kontaktanfragen
7. Sicherheit und Melden
8. Privatsphaere und Einstellungen

## Noch nicht aufnehmen

- Dokumentenverifizierung und Verifizierungsbadges vor den ausstehenden Deploys und Livetests.
- KI-Fahrzeugbildgenerierung vor Kosten-, Rate-Limit- und Ausgabepruefung.
- MFA-, Recovery- und Sitzungsverwaltung vor dem vollstaendigen Sicherheits-Livetest.
- Profilstatistiken vor dem Deploy und Livetest von `recordProfileView`.
- Push- oder Ablaufbenachrichtigungen vor einer nachgewiesenen Zustellung im Release-Build.

