import 'package:flutter_test/flutter_test.dart';
import 'package:wise_pmc_app/main.dart';

void main() {
  testWidgets('app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(initialLoggedIn: false));
    expect(find.text('Login'), findsOneWidget);
  });
}