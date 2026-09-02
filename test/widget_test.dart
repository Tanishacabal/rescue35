import 'package:flutter_test/flutter_test.dart';

import 'package:rescue35/main.dart';

void main() {
  testWidgets('app renders the Rescue 35 splash screen', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('RESCUE 35'), findsOneWidget);
    expect(find.text('MDRRMO Lal-lo, Cagayan'), findsOneWidget);
  });
}
