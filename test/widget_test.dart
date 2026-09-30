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
    await tester.pumpWidget(ArdentBiApp());
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
    await tester.pumpWidget(ArdentBiApp());
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

  testWidgets('Fullscreen button opens full screen view and exits cleanly', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: const Scaffold(
        body: SingleChildScrollView(
          child: BiChartCard(
            title: 'Net sales and gross profit by month',
            categories: ['Jan', 'Feb', 'Mar'],
            series: [
              SeriesSpec('Net sales', [100, 200, 300]),
              SeriesSpec('Gross profit', [20, 40, 60]),
            ],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.fullscreen), findsOneWidget);
    await tester.tap(find.byIcon(Icons.fullscreen));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);
    await tester.tap(find.byIcon(Icons.fullscreen_exit));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.fullscreen), findsOneWidget);
  });

  testWidgets('Table mode renders cleanly in card and fullscreen', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: const Scaffold(
        body: SingleChildScrollView(
          child: BiChartCard(
            title: 'Growth against the prior month',
            categories: ['Jan', 'Feb', 'Mar'],
            series: [
              SeriesSpec('Net sales', [10, 20, 30]),
              SeriesSpec('Gross profit', [5, 10, 15]),
            ],
            defaultTable: true,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('CATEGORY'), findsOneWidget);
    expect(find.text('NET SALES'), findsOneWidget);
    expect(find.text('GROSS PROFIT'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.fullscreen));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('CATEGORY'), findsWidgets);

    await tester.tap(find.byIcon(Icons.fullscreen_exit));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.fullscreen), findsOneWidget);
  });
}
