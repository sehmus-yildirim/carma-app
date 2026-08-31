# Push-Abnahme auf echtem Android-Geraet

Datum: 31.08.2026

## Umfang

- Firebase-Projekt: `carma-a84e4`
- App: `de.plaqa.app`, Debug-Build `1.0.0+1`
- Geraet: Redmi `2201117TY`, Android 13
- Transport: echte Firebase-Cloud-Messaging-Nachrichten
- Zustaende: Vordergrund, Hintergrund und beendeter App-Prozess

Ein erzwungener Stopp wurde fuer den letzten Zustand bewusst nicht verwendet.
Android blockiert FCM nach einem vom Nutzer erzwungenen Stopp bis zum naechsten
manuellen Start. Stattdessen wurde der Prozess bei im Hintergrund liegender App
beendet und vor dem Versand ein leerer Prozessstatus sowie `stopped=false`
nachgewiesen.

## Technische Umsetzung

- Android 13+ fordert `POST_NOTIFICATIONS` explizit an.
- Der Kanal `plaqa_messages` wird beim App-Start mit hoher Wichtigkeit angelegt.
- FCM verwendet den Kanal auch fuer Hintergrund- und Kaltstartnachrichten.
- Vordergrundnachrichten werden ueber eine kleine native Android-Bruecke sichtbar
  dargestellt und fuehren ihre sicheren Navigationsdaten zurueck an Flutter.
- Android verwendet transparente, dichteoptimierte Kopien des originalen
  Plaqa-App-Icons. Der schwarze Hintergrund des Launcher-PNGs wurde nur in
  diesen Notification-Kopien transparent gesetzt; es existiert keine
  nachgezeichnete `q`-Variante und keine von Plaqa gesetzte blaue
  Notification-Hintergrundfarbe.
- iOS verwendet fuer Benachrichtigungen systembedingt automatisch den vorhandenen
  `AppIcon.appiconset`; Apple erlaubt kein separates Notification-Symbol.
- `tools/send_push_smoke_test.cjs` waehlt den neuesten privaten Android-Token,
  ohne ihn auszugeben, und sendet wiederholbare, eindeutig markierte Testdaten.

## Reale Ergebnisse

| Zustand | Nachweis | Ergebnis |
|---|---|---|
| Vordergrund | App war sichtbar; FCM nahm die Nachricht an; Android postete Titel und Text im Kanal `plaqa_messages` mit Wichtigkeit 4 | PASS |
| Hintergrund | Android-Einstellungen waren sichtbar; Plaqa lag pausiert im Hintergrund; FCM-Systembenachrichtigung, Kanal, Inhalt und `PendingIntent` waren vorhanden | PASS |
| App geschlossen | Plaqa-PID vor Versand leer, Paket `stopped=false`; FCM stellte die Nachricht zu und startete nur den Messaging-Prozess, nicht die App-Oberflaeche | PASS |
| Darstellung | Reale Redmi-Aufnahme kontrolliert; links erscheint das Plaqa-`q` ohne eingebettete quadratische Icon-Kachel | PASS |

Alle drei Nachrichten verwendeten hohe FCM-Prioritaet, den Kanal
`plaqa_messages`, einen eindeutigen Smoke-Test-Tag sowie sichere interne
Navigationsdaten vom Typ `chat`.

## Begleitpruefungen

- `flutter test test/push_notification_navigation_test.dart test/app_check_configuration_test.dart`
- `flutter analyze lib/shared/notifications/push_notification_service.dart lib/main.dart`
- `flutter build apk --debug`
- Android Notification Manager (`dumpsys notification --noredact`)
- Android Prozess- und Paketstatus vor und nach der Zustellung
- reale visuelle Kontrolle in der Redmi-Benachrichtigungsleiste

## Abgrenzung

Die reale Android-Zustellung ist damit abgeschlossen. Eine reale APNs-Zustellung
auf einem iPhone bleibt Bestandteil der separat ausgesetzten iOS-/Mac-Abnahme.
Der vorhandene iOS-App-Icon-Katalog wurde bereits statisch geprueft; seine reale
Darstellung kann erst auf einem iPhone abgenommen werden.
