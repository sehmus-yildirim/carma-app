# Offener Fehler: Kontaktanfrage annehmen scheitert

Datum: 2026-06-14

Status: Zurueckgestellt. Nicht weiter bearbeiten, bis wir diesen Punkt bewusst wieder aufnehmen.

## Beobachtung

Beim Annehmen einer eingehenden Kontaktanfrage erscheint weiterhin ein Firestore-Permission-Fehler.

Aktuelle App-Meldung aus dem Test:

```text
Annehmen fehlgeschlagen [accept].
user=Svuu2w...J7y1 receiver=Svuu2w...J7y1 sender=5BGq4H...TLq2 request=5BGq4H...4700 error=[cloud_firestore/permission-denied] The caller does not have permission to execute the specified operation.
```

Screenshot-Kontext:

```text
C:\Users\Admin\AppData\Local\Packages\5319275A.WhatsAppDesktop_cv1g1gvanyjgm\LocalState\sessions\D45BED26AD6492D315742149E31E6D3870BD6FB5\transfers\2026-24\WhatsApp Image 2026-06-14 at 18.26.14.jpeg
```

## Was zuletzt versucht wurde

- Firestore/Storage Rules wurden lokal kompiliert und live deployed.
- Accept-Ablauf wurde erweitert, damit bei Permission-Problemen ein Recovery-Pfad versucht wird.
- `flutter analyze` war sauber.
- `flutter test` war sauber.

## Wichtiger Hinweis fuer spaeter

Die sichtbare Fehlermeldung zeigt weiter `[accept]` statt einer neuen Stage wie `[accept-request-first]` oder `[create-chat-after-accept]`. Beim Wiederaufnehmen zuerst pruefen:

- Laeuft auf dem Geraet wirklich der neueste App-Code?
- Wird `_acceptRequestErrorMessage` aus `chat_shell.dart` noch von einem alten Hot-Restart-Zustand angezeigt?
- Welche konkrete Firestore-Operation scheitert live: `contact_requests/{id}.update`, `chats/{id}.set` oder ein danach folgender Read/Update?
- Firestore-Dokument der betroffenen Anfrage pruefen: `status`, `senderUserId`, `receiverUserId`, `chatId`, Dokument-ID.

## Naechster sinnvoller Debug-Schritt

Wenn wir diesen Fehler wieder aufnehmen, nicht weiter an UI arbeiten. Erst gezielt:

1. Live-Dokument der betroffenen Anfrage in Firestore anschauen.
2. App neu installieren oder Full Restart sicherstellen.
3. Temporär Stage-Logging fuer jede Accept-Operation setzen.
4. Danach Rules oder Repository nur fuer die exakt scheiternde Operation korrigieren.
