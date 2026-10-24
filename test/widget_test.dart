
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriapp/main.dart';

void main() {
  testWidgets('NutriTrack app starts', (WidgetTester tester) async {
    await tester.pumpWidget(const NutritrackRoot());
    await tester.pump();

    expect(find.byType(NutritrackRoot), findsOneWidget);
  });
}
