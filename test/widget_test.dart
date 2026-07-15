import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:auscult_pen/main.dart';

void main() {
  testWidgets('App loads and shows home screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: AuscultPenApp(),
      ),
    );

    expect(find.text('首页'), findsOneWidget);
    expect(find.text('患者库'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });
}
