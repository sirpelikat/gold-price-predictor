import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/main.dart';

void main() {
  testWidgets('App loads smoke test and renders tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const GoldApp());

    // Verify app title and tabs render
    expect(find.text('Gold AI Predictor'), findsOneWidget);
    expect(find.text('Forecast'), findsOneWidget);
    expect(find.text('Accuracy'), findsOneWidget);
    expect(find.text('Logs'), findsOneWidget);
  });
}
