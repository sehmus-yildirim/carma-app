# CaRisma MFA Recovery Admin

Dieses Werkzeug ist von der normalen CaRisma-App getrennt und wird nicht über
deren Navigation ausgeliefert. Es vergibt keine Adminrechte. Jede Abfrage und
jede Aktion läuft über Callable Functions, die ein serverseitiges `admin`
Custom Claim verlangen.

## Lokaler Start

1. `config.example.js` als lokal ignorierte `config.js` anlegen und die
   öffentliche Firebase-Web-Konfiguration eintragen.
2. Einen statischen lokalen Webserver in diesem Ordner starten.
3. Mit einem eigens vorgesehenen Admin-Konto anmelden.
4. Nach jeder Änderung des Custom Claims vollständig ab- und neu anmelden.

Das Werkzeug niemals gemeinsam mit der öffentlichen Nutzer-App hosten. Vor
einem internen Hosting müssen Zugriffsbeschränkung, App Check und die erlaubte
Domain in Firebase Authentication fertig konfiguriert sein.

## Ablauf

1. Fall anhand der internen UID öffnen oder eine Nutzeranfrage auswählen.
2. Externe Identitätsprüfung durchführen und ausdrücklich bestätigen.
3. Admin A erteilt die erste Freigabe.
4. Ein anderer Admin B erteilt die zweite Freigabe.
5. Erst danach widerruft der Server Refresh-Tokens und entfernt MFA-Faktoren.

Passwörter, SMS-Codes, vollständige Telefonnummern und Tokens dürfen niemals
in dieses Werkzeug eingegeben werden.
