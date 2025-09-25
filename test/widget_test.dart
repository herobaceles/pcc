import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pccmobile/main.dart';
import 'package:pccmobile/pages/splash_screen.dart';
import 'package:pccmobile/pages/onboarding_screen.dart';

void main() {
  testWidgets(
    'App shows SplashScreen when onboarding is complete',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp(onboardingComplete: true));
      await tester.pump(); // let the first frame build

      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
    },
  );

  testWidgets(
    'App shows OnboardingScreen when onboarding is NOT complete',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp(onboardingComplete: false));
      await tester.pump();

      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
    },
  );
}
