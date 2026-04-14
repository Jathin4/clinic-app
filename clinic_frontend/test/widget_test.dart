import 'package:clinic_frontend/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_frontend/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ClinicApp());
    expect(find.byType(ClinicApp), findsOneWidget);
  });
}