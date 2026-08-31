import '../domain/verification_models.dart';

class VerificationV1Strings {
  const VerificationV1Strings._();

  static const intro =
      'Wir gleichen die Angaben deines Identitätsnachweises und des Fahrzeugscheins mit dem ausgewählten Fahrzeug ab. Bist du nicht im Fahrzeugschein als Halter eingetragen, bestätigst du deine Nutzungsberechtigung mit einer Eigenerklärung.';

  static const privacyTitle = 'Datenschutz & Berechtigung';
  static const privacyVersion = VerificationV1Policy.privacyVersion;
  static const privacyItems = <String>[
    'Es wird nur die vom Dokumentprofil benötigte Seite mit der In-App-Kamera aufgenommen oder von dir aktiv aus der Galerie ausgewählt.',
    'Die Dokumentbilder werden lokal verarbeitet und weder hochgeladen noch dauerhaft gespeichert.',
    'Aus dem Identitätsnachweis werden nur Vorname, Nachname, Geburtsdatum und Ablaufdatum verwendet.',
    'Aus dem Fahrzeugdokument werden nur Kennzeichen und Haltername beziehungsweise Firma für den Abgleich verwendet.',
    'Die Halterdaten aus dem Fahrzeugdokument werden nach dem Abgleich nicht dauerhaft gespeichert.',
    'Bei Nicht-Haltern wird die unterschriebene Eigenerklärung als privates PDF gespeichert.',
    'Es findet keine Gesichtserkennung, kein Face Match und keine Liveness-Prüfung statt.',
    'Der Ablauf gleicht Dokumentdaten ab. Er ist keine amtliche Echtheitsprüfung.',
  ];

  static const declarationVersion = VerificationV1Policy.declarationVersion;
  static const declarationConfirmation =
      'Ich habe die Eigenerklärung vollständig gelesen und bestätige ihre Richtigkeit verbindlich.';

  static String declaration({
    required String fullName,
    required String plate,
    required String relation,
  }) =>
      '''Eigenerklärung zur Fahrzeugnutzungsberechtigung

Ich, $fullName, bestätige, dass ich berechtigt bin, das Fahrzeug mit dem amtlichen Kennzeichen $plate zu nutzen und diesem Plaqa-Konto zuzuordnen.

Die von mir ausgewählte Fahrzeugzuordnung lautet: $relation.

Ich bestätige, dass meine Angaben vollständig, aktuell und wahrheitsgemäß sind. Ich werde die Fahrzeugzuordnung entfernen oder Plaqa informieren, sobald meine Nutzungsberechtigung endet.

Mir ist bekannt, dass falsche Angaben zur Sperrung der Fahrzeugzuordnung oder meines Plaqa-Kontos führen können.''';
}
