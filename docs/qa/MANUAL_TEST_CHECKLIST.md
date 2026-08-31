# plaqa Manuelle Release-Testliste

Stand: 2026-08-29
Status: vor öffentlichem Release vollständig mit Datum, Gerät, Tester und
Nachweis auszufüllen

## Android und iOS

- [ ] saubere Neuinstallation, Updateinstallation und erster Start
- [ ] Onboarding einmalig vollständig; nach Neustart kein erneutes Onboarding
- [ ] Registrierung, E-Mail-Verifizierung, Login, Logout, Re-Authentifizierung
- [ ] Google- und Apple-Anmeldung einschließlich Abbruch- und Fehlerfällen
- [ ] Konto A/B: Fahrzeug, Suche, Anfrage, Annahme, Chat und Blockierung
- [ ] Medien: Bild, Video, Audio und Dokument mit erlaubten und abgelehnten
  Berechtigungen
- [ ] Kamera, Mikrofon, Standort, Fotos und Benachrichtigungen nach späterer
  Freigabe in Systemeinstellungen
- [x] Android-Push im Vordergrund, Hintergrund und bei beendetem App-Prozess
  real auf dem Redmi geprueft; iPhone/APNs bleibt im ausgesetzten iOS-Block
- [ ] Offline/Online, App-Wechsel, Prozessende, Neustart und Tokenwechsel
- [ ] Kontolöschung einschließlich Fremdpfaden, Begegnungen und Auth-Widerruf
- [ ] Datenexport mit Identitätsprüfung, Zustellung und Frist

## Geräte und Darstellung

- [ ] aktuelles kleines und großes Android-Gerät
- [ ] unterstützte ältere Android-Version und Redmi/MIUI
- [ ] aktuelles iPhone sowie älteste unterstützte iOS-Version
- [ ] Smartphone hoch/quer, Tablet und große Schrift
- [ ] Light/Dark Mode, Displayzoom und hoher Kontrast
- [ ] Tastaturnavigation, TalkBack und VoiceOver-Grundreise
- [ ] Fokusreihenfolge, Beschriftungen, Fehlermeldungen und Touchziele
- [ ] keine abgeschnittenen Texte, Layoutsprünge oder verdeckten Dialoge

## Stabilität und Leistung

- [ ] drei Kaltstarts je Plattform dokumentieren
- [ ] Kernreisen unter langsamem Netz und Paketverlust
- [ ] mindestens 30 Minuten aktive Nutzung ohne Crash/ANR
- [ ] Speicher nach Start, Mediennutzung und längerer Session vergleichen
- [ ] Scrollen und Animationen mit Profiler kontrollieren
- [ ] Crashlytics-, Functions-, Auth-, Rules- und Kostenalarme während interner
  Testspur beobachten

## Store und Betrieb

- [ ] Storetexte, Screenshots, App-Icon und Vorschaugrafik entsprechen dem Build
- [ ] Datenschutz/Data Safety/App Privacy stimmen mit tatsächlichen Datenflüssen
  überein
- [ ] Zielgruppe, Altersfreigabe, UGC-, Melde-, Blockier- und Kinderschutzangaben
  freigegeben
- [ ] Support-, Datenschutz- und Kontolösch-URLs öffentlich erreichbar
- [ ] interne Testspur/TestFlight abgeschlossen; Rückmeldungen triagiert
- [ ] Monitoring-Dashboard, Alarmempfänger und Rollback-Verantwortlicher benannt
- [ ] Rollbackübung und Incident-Kontaktkette protokolliert

## Abschlussprotokoll

| Feld | Wert |
|---|---|
| Release-Version/Build | |
| Git-Commit | |
| Android-AAB-Hash | |
| iOS-Archiv/IPA-Hash | |
| Testzeitraum | |
| verantwortliche Tester | |
| offene Abweichungen | |
| Freigabe Produkt | |
| Freigabe Technik | |
| Freigabe Datenschutz/Recht | |
