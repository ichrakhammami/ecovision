import 'package:ecovision/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Le tableau de bord affiche le solde et ouvre le scanner', (
    tester,
  ) async {
    int? destination;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Dashboard(
            name: 'Amine',
            points: 250,
            onNavigate: (index) => destination = index,
          ),
        ),
      ),
    );
    expect(find.text('Bonjour, Amine'), findsOneWidget);
    expect(find.text('250'), findsOneWidget);
    await tester.tap(find.text('Scanner un déchet'));
    expect(destination, 1);
  });
}
