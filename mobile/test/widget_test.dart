import 'package:flutter_test/flutter_test.dart';

import 'package:rydlnk/main.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const RydlnkApp());
    expect(find.byType(RydlnkApp), findsOneWidget);
  });
}
