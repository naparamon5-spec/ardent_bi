// Smoke test: the app boots to the login screen when no session is stored.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ardent_bi/main.dart';
import 'package:ardent_bi/theme.dart';
import 'package:ardent_bi/widgets/bi_chart.dart';

void main() {
  testWidgets('App boots to the sign-in screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ArdentBiApp());
    await tester.pumpAndSettle();

    expect(find.text('Ardent BI'), findsWidgets);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('Ranked card can switch to donut, treemap and waterfall', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Scaffold(
        body: SingleChildScrollView(
          child: BiChartCard(
            title: 'Net sales by brand',
            bars: const [
              BarDatum('Fortinet', 1200000),
              BarDatum('Cisco', 900000),
              BarDatum('Juniper', -300000),
            ],
            types: const [
              BiChartType.bar,
              BiChartType.column,
              BiChartType.donut,
              BiChartType.treemap,
              BiChartType.waterfall,
            ],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    Future<void> pick(String label) async {
      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    await pick('Donut');
    expect(tester.takeException(), isNull);
    expect(find.text('Total'), findsOneWidget);

    await pick('Treemap');
    expect(tester.takeException(), isNull);
    expect(find.byType(CustomPaint), findsWidgets);

    await pick('Waterfall');
    expect(tester.takeException(), isNull);
    expect(find.text('Net'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.table_view_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Fortinet'), findsWidgets);
  });

  testWidgets('Overview shows insights and the brand by quarter pivot in demo mode', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ArdentBiApp());
    await tester.pumpAndSettle();

    final demo = find.text('Preview the UI (demo data)');
    await tester.ensureVisible(demo);
    await tester.pumpAndSettle();
    await tester.tap(demo);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.auto_awesome_outlined), findsOneWidget);

    final pivot = find.text('Brand by quarter');
    await tester.dragUntilVisible(pivot, find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(pivot, findsOneWidget);
    expect(find.text('TOTAL'), findsWidgets);

    await tester.tap(find.byIcon(Icons.auto_awesome_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Net sales up 12.4% on the prior period'), findsOneWidget);
  });
}
