import 'package:flutter_test/flutter_test.dart';
import 'package:mixhouse/main.dart';

void main() {
  testWidgets('Mixhouse starts with a loading state', (tester) async {
    await tester.pumpWidget(const MixhouseApp());
    expect(find.byType(Splash), findsOneWidget);
  });
}
