import 'package:flutter_test/flutter_test.dart';

import 'package:rar_example/main.dart';

void main() {
  testWidgets('RAR Browser shows empty state', (WidgetTester tester) async {
    await tester.pumpWidget(const RarBrowserApp());

    // Verify the app title is shown
    expect(find.text('RAR Browser'), findsOneWidget);

    // Verify the empty state message is shown
    expect(find.text('RAR Archive Browser'), findsOneWidget);
    expect(find.text('Open a RAR file to browse its contents'), findsOneWidget);

    // Verify the Open RAR button exists
    expect(find.text('Open RAR'), findsOneWidget);
    expect(find.text('Open RAR File'), findsOneWidget);
  });
}
