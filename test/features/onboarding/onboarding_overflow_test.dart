import 'package:awaken/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards J-06: the marketing carousel previously had no scroll fallback
/// and used a fixed `SizedBox(width: 290)` for its title/body — at large
/// system text scale on a small device this overflowed (`RenderFlex`)
/// instead of scrolling or reflowing narrower.
void main() {
  Widget wrap({required double width, required double height, required double textScale}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, height),
          textScaler: TextScaler.linear(textScale),
        ),
        child: OnboardingPage(onFinished: () {}),
      ),
    );
  }

  testWidgets(
    'marketing carousel does not overflow at 2x text scale on a small screen',
    (tester) async {
      await tester.pumpWidget(
        wrap(width: 320, height: 568, textScale: 2.0),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('marketing carousel swipes to the next card', (tester) async {
    await tester.pumpWidget(wrap(width: 400, height: 800, textScale: 1.0));
    await tester.pumpAndSettle();

    expect(find.text('Every run claims ground.'), findsNothing);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Every run claims ground.'), findsOneWidget);
  });
}
