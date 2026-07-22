enum PlateContactReason {
  vehicleQuestion,
  compliment,
  meetAndDrive,
  getToKnow;

  String get key => switch (this) {
    PlateContactReason.vehicleQuestion => 'vehicle_question',
    PlateContactReason.compliment => 'compliment',
    PlateContactReason.meetAndDrive => 'meet_and_drive',
    PlateContactReason.getToKnow => 'get_to_know',
  };

  String get title => switch (this) {
    PlateContactReason.vehicleQuestion => 'Frage zum Fahrzeug',
    PlateContactReason.compliment => 'Kompliment zum Fahrzeug',
    PlateContactReason.meetAndDrive => 'Treffen & Ausfahrt',
    PlateContactReason.getToKnow => 'Kennenlernen',
  };

  String get description => switch (this) {
    PlateContactReason.vehicleQuestion =>
      'Für Modell, Ausstattung, Modifikation oder allgemeine Fragen.',
    PlateContactReason.compliment => 'Kompliment für das Fahrzeug geben.',
    PlateContactReason.meetAndDrive =>
      'Für Fahrzeugtreffen, gemeinsame Ausfahrten oder Community-Events.',
    PlateContactReason.getToKnow => 'Für einen persönlichen Kontakt.',
  };

  String messageFor({required String vehicleName}) {
    final vehicle = vehicleName.trim().isEmpty
        ? 'Fahrzeug'
        : vehicleName.trim();

    return switch (this) {
      PlateContactReason.vehicleQuestion =>
        'Hallo, ich habe eine Frage zu deinem $vehicle und würde mich gerne kurz mit dir darüber austauschen.',
      PlateContactReason.compliment =>
        'Hallo, dein $vehicle ist mir positiv aufgefallen. Wirklich ein sehr schönes Auto.',
      PlateContactReason.meetAndDrive =>
        'Hallo, ich wollte fragen, ob du Interesse an einem Fahrzeugtreffen oder einer gemeinsamen Ausfahrt hast.',
      PlateContactReason.getToKnow =>
        'Hallo, du bist mir mit deinem $vehicle aufgefallen und ich würde dich gerne kennenlernen.',
    };
  }
}
