import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plaqa/features/profile/presentation/widgets/profile_vehicle_statistics_card.dart';

void main() {
  testWidgets('statistics start at zero and update from live streams', (
    tester,
  ) async {
    final profileViews = StreamController<int>();
    final totalLikes = StreamController<int>();
    addTearDown(profileViews.close);
    addTearDown(totalLikes.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileVehicleStatisticsCard(
            profileViews: profileViews.stream,
            totalLikes: totalLikes.stream,
          ),
        ),
      ),
    );

    expect(find.text('0'), findsNWidgets(2));
    profileViews.add(17);
    totalLikes.add(42);
    await tester.pump();

    expect(find.text('17'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('Profilaufrufe'), findsOneWidget);
    expect(find.text('Gefällt mir'), findsOneWidget);
  });

  testWidgets('statistics use zero instead of a placeholder on stream errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileVehicleStatisticsCard(
            profileViews: Stream<int>.error(StateError('nicht verfügbar')),
            totalLikes: Stream<int>.value(0),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('0'), findsNWidgets(2));
  });
}
