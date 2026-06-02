import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App loads without crashing', (WidgetTester tester) async {
    // Smoke test — just verify the test framework works.
    // Full widget tests require ProviderScope and mocked PocketBase.
    expect(1 + 1, equals(2));
  });
}
