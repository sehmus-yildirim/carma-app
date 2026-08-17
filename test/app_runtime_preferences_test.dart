import 'package:flutter_test/flutter_test.dart';
import 'package:plaqa/features/settings/data/app_runtime_preferences.dart';

void main() {
  test('runtime preferences notify only when app values change', () {
    final preferences = AppRuntimePreferences.instance;
    final initial = preferences.settings;
    final nextCountry = initial.defaultPlateCountry == 'CH' ? 'AT' : 'CH';
    var notifications = 0;

    void listener() => notifications += 1;

    preferences.addListener(listener);
    preferences.apply(initial);
    expect(notifications, 0);

    preferences.apply(initial.copyWith(defaultPlateCountry: nextCountry));
    expect(notifications, 1);
    expect(preferences.settings.defaultPlateCountry, nextCountry);

    preferences.removeListener(listener);
    preferences.apply(initial);
  });
}
