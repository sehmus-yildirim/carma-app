# Google Play Datensicherheit - Arbeitsblatt

Stand: 1. September 2026  
Status: Entwurf fuer die Play Console; vor Einreichung mit dem final signierten AAB und den tatsaechlichen Anbieter-Konfigurationen abgleichen.

## 1. Grundangaben

- Daten werden verschluesselt uebertragen: Ja, fuer App-/Backend-Kommunikation per TLS.
- Nutzer koennen Kontoloeschung anfordern: Ja, in der App sowie ueber `https://plaqa.de/konto-loeschen/`.
- Unabhaengige Sicherheitspruefung: Nur angeben, wenn eine gueltige externe Zertifizierung vorliegt. Derzeit nicht belegt.
- Zielgruppe: ab 16 Jahren; nicht als Kinder-App oder Families-App vermarkten.

## 2. Voraussichtlich anzugebende Datentypen

| Kategorie | Beispiele in Plaqa | Erhoben | Geteilt | Zweck |
|---|---|---:|---:|---|
| Personenbezogene Daten | Name, E-Mail, Anzeigename, Geburtsdatum soweit eingegeben | Ja | Dienstleister | Konto, App-Funktion, Sicherheit, Support |
| Nutzerkennungen | Firebase UID, Provider-ID | Ja | Dienstleister | Konto, Sicherheit |
| Standort | genauer/ungefaehrer Standort bei aktivierter Funktion | Ja | nicht als Verkauf; Dienstleisterverarbeitung | App-Funktion, Missbrauchsschutz |
| Fotos/Videos | Profil-, Fahrzeug-, Chat-, Story- und Meldebilder | Ja | nutzerbestimmt/Dienstleister | App-Funktion, Moderation |
| Audio | vom Nutzer gesendete Chat-Medien, falls Funktion aktiv | Ja | nutzerbestimmt/Dienstleister | App-Funktion |
| Nachrichten | Chat-, Kontakt-, Support- und Meldetexte | Ja | Empfaenger/Dienstleister | App-Funktion, Sicherheit, Support |
| App-Aktivitaet | Suchen, Kontakte, Feed-/Interaktionen, Blockierungen | Ja | Dienstleister | App-Funktion, Sicherheit |
| App-Information/Leistung | Push-Token, App-Version, technische Statusdaten | Ja | Dienstleister | Benachrichtigung, Sicherheit, Diagnose |
| Geraete- oder andere IDs | App-Check-/Integritaetssignale, Push-Token | Ja | Dienstleister | Betrugs-/Missbrauchsschutz |
| Dateien und Dokumente | Verifizierungsunterlagen, sofern der Flow spaeter freigeschaltet wird | Bedingt | Dienstleister | optionale Verifizierung |

`Geteilt` ist nach der jeweils aktuellen Google-Definition zu beantworten. Reine Auftragsverarbeitung kann in der Play-Console anders behandelt werden als eine Weitergabe an Dritte. Nicht pauschal `Nein` ankreuzen, ohne die aktuelle Formularhilfe zu pruefen.

## 3. Zwingende Release-Abgleiche

1. Finales AAB und `pubspec.lock` auf neue SDKs pruefen.
2. Firebase-/Google-Cloud-Datenstandorte, App Check, Push und KI-Konfiguration pruefen.
3. Verifizierungsfunktion nur deklarieren, wenn sie im Release sichtbar/nutzbar ist; technische Speicherung trotzdem in Datenschutz und Sicherheitspruefung dokumentieren.
4. Kontoloeschungs-URL oeffentlich, ohne Login erreichbar und aktuell halten.
5. Screenshots/Storetexte duerfen keine nicht vorhandene Verifizierung oder Sicherheitsgarantie versprechen.
6. Nach jeder Funktions-, SDK- oder Anbieteranderung Play-Datensicherheit erneut pruefen.

