import 'package:bawarii_reference_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App boots and HomeScreen renders without overflow at 360×640',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const BawariiReferenceApp());
    await tester.pump();

    // Wordmark present.
    expect(find.text('BAWARII'), findsOneWidget);

    // TEST ENVIRONMENT badge
    expect(find.text('TEST ENVIRONMENT'), findsOneWidget);

    // Both workflow cards present
    expect(find.text('Document Only'), findsOneWidget);
    expect(find.text('Document + Liveness'), findsOneWidget);

    // "How this works" link
    expect(find.text('How this works'), findsOneWidget);
  });
}
