 import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescue35/services/app_language.dart';
import 'package:rescue35/widgets/localized_text.dart' as localized;

void main() {
  testWidgets('localized text follows Tagalog and English app locales', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('tl'),
        supportedLocales: [Locale('en'), Locale('tl')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(body: localized.Text('Home')),
      ),
    );

    expect(find.text('Tahanan'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        supportedLocales: [Locale('en'), Locale('tl')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(body: localized.Text('Home')),
      ),
    );

    expect(find.text('Home'), findsOneWidget);
  });

  test('English app text is restored when a source phrase is Tagalog', () {
    expect(
      translateText(
        'Kulang ang profile mo. Pakikumpleto muna ito sa Profile settings.',
      ),
      'Your profile is incomplete. Please complete it in Profile settings first.',
    );
  });
}
