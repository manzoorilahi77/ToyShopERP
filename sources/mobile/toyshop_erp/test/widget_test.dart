// Smoke test: the app boots to the shared login screen ("Who's billing?").
import 'package:flutter_test/flutter_test.dart';

import 'package:toyshop_erp/app.dart';

void main() {
  testWidgets('App boots to the login picker', (WidgetTester tester) async {
    await tester.pumpWidget(const ToyShopApp());
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text("Who's billing?"), findsOneWidget);
  });
}
