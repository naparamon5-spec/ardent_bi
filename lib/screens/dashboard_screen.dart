import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../format.dart';
import '../state/auth_state.dart';
import '../state/filter_state.dart';
import '../theme.dart';
import '../widgets/bi_chart.dart';
import '../widgets/insights_sheet.dart';
import '../widgets/kpi_tile.dart';
import '../widgets/filter_sheet.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late FilterState _filters;
  Timer? _debounce;

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _kpis;
  List<dynamic> _trend = [];
  Map<String, dynamic>? _brand;
  Map<String, dynamic>? _salesman;
  List<dynamic> _movers = [];
  Map<String, dynamic>? _inv;
  List<dynamic> _insights = [];
  Map<String, dynamic>? _pivot;

  @override
  void initState() {
    super.initState();
    _filters = context.read<FilterState>();
    _filters.addListener(_onFilters);
    _load();
  }

  @override
  void dispose() {
    _filters.removeListener(_onFilters);
    _debounce?.cancel();
    super.dispose();
  }

  void _onFilters() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = context.read<AuthState>().client;
    final body = {'filters': _filters.salesPayload};
    try {
      final results = await Future.wait([
        api.post('/api/sales/kpis', body),
        api.post('/api/sales/timeseries', {...body, 'grain': 'month'}),
        api.post('/api/sales/breakdown', {...body, 'dimension': 'brand', 'limit': 8}),
        api.post('/api/sales/breakdown', {...body, 'dimension': 'salesman', 'limit': 10}),
        api.post('/api/sales/movers', {...body, 'dimension': 'brand'}),
        api.post('/api/inventory/kpis', {'filters': {}}),
        api.post('/api/sales/insights', {...body, 'dimension': 'brand', 'grain': 'month', 'mode': 'yoy'}),
        api.post('/api/sales/pivot', {...body, 'rows': 'brand', 'cols': 'quarter', 'measure': 'sales'}),
      ]);
      if (!mounted) return;
      setState(() {
        _kpis = results[0] as Map<String, dynamic>;
        _trend = (results[1] as Map)['points'] as List? ?? [];
        _brand = results[2] as Map<String, dynamic>;
        _salesman = results[3] as Map<String, dynamic>;
        _movers = (results[4] as Map)['rows'] as List? ?? [];
        _inv = results[5] as Map<String, dynamic>;
        _insights = (results[6] as Map)['insights'] as List? ?? [];
        _pivot = results[7] as Map<String, dynamic>;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  List<BarDatum> _breakdownBars(Map<String, dynamic>? bd, String dim) {
    final rows = (bd?['rows'] as List?) ?? const [];
    final selected = _filters.sales(dim);
    return rows
        .map((r) => BarDatum(
              (r['name'] ?? '—').toString(),
              (r['sales'] as num?)?.toDouble() ?? 0,
              selected: selected.contains((r['name'] ?? '').toString()),
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    final filters = context.watch<FilterState>();
    final auth = context.watch<AuthState>();
    final k = (_kpis?['current'] as Map?) ?? const {};
    final d = (_kpis?['delta'] as Map?) ?? const {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Overview'),
        actions: [
          _InsightsButton(count: _insights.length, onTap: () => _showInsights(context)),
          _FilterButton(count: filters.activeSalesCount, onTap: () => showSalesFilterSheet(context)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            if (auth.scopeNote != null) _scopeBanner(t, auth.scopeNote!),
            if (_error != null) _errorBanner(t, _error!),
            // KPI grid
            KpiGrid(tiles: [
              KpiTile(label: 'Net sales', value: k['sales'], format: 'currency', delta: d['sales'], loading: _loading),
              KpiTile(label: 'Gross profit', value: k['grossProfit'], format: 'currency', delta: d['grossProfit'], loading: _loading),
              KpiTile(label: 'Gross margin', value: k['gmPercent'], format: 'percent', delta: d['gmPercent'], deltaIsPoints: true, loading: _loading),
              KpiTile(label: 'Invoices', value: k['invoices'], format: 'number', delta: d['invoices'], loading: _loading, sub: '${Fmt.number(k['lines'] ?? 0)} lines'),
              KpiTile(label: 'Active customers', value: k['customers'], format: 'number', delta: d['customers'], loading: _loading, sub: '${Fmt.number(k['skus'] ?? 0)} items sold'),
            ]),
            const SizedBox(height: 24),
            _section(t, 'Trend'),
            BiChartCard(
              title: 'Net sales and gross profit by month',
              subtitle: 'Both measures are currency, so they share one axis',
              categories: _trend.map((p) => (p['label'] ?? '').toString()).toList(),
              series: [
                SeriesSpec('Net sales', _trend.map((p) => (p['sales'] as num?)?.toDouble() ?? 0).toList()),
                SeriesSpec('Gross profit', _trend.map((p) => (p['grossProfit'] as num?)?.toDouble() ?? 0).toList()),
              ],
            ),
            const SizedBox(height: 24),
            _section(t, 'Breakdown'),
            BiChartCard(
              title: 'Net sales by brand',
              subtitle: 'Tap a bar to filter the whole page',
              bars: _breakdownBars(_brand, 'brand'),
              types: const [BiChartType.bar, BiChartType.column, BiChartType.donut, BiChartType.treemap],
              onBarTap: (c) => filters.toggleSales('brand', c),
            ),
            const SizedBox(height: 16),
            BiChartCard(
              title: 'Net sales by salesman',
              subtitle: 'Top 10 by value',
              bars: _breakdownBars(_salesman, 'salesman'),
              types: const [BiChartType.bar, BiChartType.column, BiChartType.treemap],
              onBarTap: (c) => filters.toggleSales('salesman', c),
            ),
            const SizedBox(height: 16),
            _pivotCard(t),
            const SizedBox(height: 24),
            _section(t, 'Movers'),
            BiChartCard(
              title: 'Biggest movers by brand',
              subtitle: 'Change against the equally long window before',
              bars: _movers
                  .take(8)
                  .map((r) => BarDatum((r['name'] ?? '—').toString(), (r['delta'] as num?)?.toDouble() ?? 0))
                  .toList(),
              signColors: true,
              types: const [BiChartType.bar, BiChartType.column, BiChartType.waterfall],
              onBarTap: (c) => filters.toggleSales('brand', c),
            ),
            const SizedBox(height: 24),
            _section(t, 'Inventory'),
            _inventoryGlance(t),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Uppercase eyebrow with a hairline rule, used to group the lower page
  /// sections (Movers, Inventory) the way the web splits its overview.
  Widget _section(BiTokens t, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Text(label.toUpperCase(),
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                  color: t.textMuted)),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: t.gridline, height: 1)),
        ]),
      );

  /// Brand × quarter pivot — the same grid the web shows under the charts,
  /// with em-dashes for empty cells and a bold TOTAL column.
  Widget _pivotCard(BiTokens t) {
    final cols = ((_pivot?['columns'] as List?) ?? const []).map((c) => c.toString()).toList();
    final rows = (_pivot?['rows'] as List?) ?? const [];
    final colTotals = ((_pivot?['columnTotals'] as List?) ?? const []);
    final grand = (_pivot?['grandTotal'] as num?)?.toDouble() ?? 0;

    return BiCard(
      title: 'Brand by quarter',
      subtitle: 'Grand total ${Fmt.compact(grand)}',
      child: rows.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                  child: Text('No data for this selection',
                      style: TextStyle(color: t.textMuted, fontSize: 12))),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                columnWidths: {
                  0: const FixedColumnWidth(150),
                  for (var c = 1; c <= cols.length + 1; c++) c: const FixedColumnWidth(96),
                },
                children: [
                  TableRow(children: [
                    _pivotCell(t, 'BRAND', header: true),
                    for (final c in cols) _pivotCell(t, c.toUpperCase(), header: true, right: true),
                    _pivotCell(t, 'TOTAL', header: true, right: true),
                  ]),
                  for (final r in rows)
                    TableRow(children: [
                      _pivotCell(t, (r['name'] ?? '—').toString()),
                      for (final v in (r['values'] as List? ?? const []))
                        _pivotCell(t, _pivotText(v), right: true),
                      _pivotCell(t, Fmt.compact((r['total'] as num?)?.toDouble() ?? 0),
                          right: true, bold: true),
                    ]),
                  TableRow(children: [
                    _pivotCell(t, 'TOTAL', bold: true),
                    for (final v in colTotals) _pivotCell(t, _pivotText(v), right: true, bold: true),
                    _pivotCell(t, Fmt.compact(grand), right: true, bold: true),
                  ]),
                ],
              ),
            ),
    );
  }

  String _pivotText(dynamic v) {
    final n = (v as num?)?.toDouble() ?? 0;
    return n == 0 ? '—' : Fmt.compact(n);
  }

  Widget _pivotCell(BiTokens t, String text,
      {bool header = false, bool right = false, bool bold = false}) {
    return Container(
      padding: EdgeInsets.fromLTRB(right ? 8 : 0, 9, right ? 0 : 8, 9),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.gridline))),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: right ? TextAlign.right : TextAlign.left,
        style: TextStyle(
          fontSize: header ? 10.5 : 12.5,
          letterSpacing: header ? 0.5 : 0,
          fontWeight: header || bold ? FontWeight.w700 : FontWeight.w500,
          color: header ? t.textMuted : (bold ? t.textPrimary : t.textSecondary),
        ),
      ),
    );
  }

  void _showInsights(BuildContext context) => showInsightsSheet(context, _insights);

  Widget _inventoryGlance(BiTokens t) {
    final over90 = (_inv?['over90Share'] as num?)?.toDouble() ?? 0;
    final critical = over90 > 30;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Inventory at a glance', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.textPrimary)),
          Text('Latest snapshot, unfiltered', style: TextStyle(fontSize: 11.5, color: t.textMuted)),
          const SizedBox(height: 14),
          _glanceRow(t, 'Stock value', Fmt.moneyShort(_inv?['value'] ?? 0)),
          const SizedBox(height: 10),
          _glanceRow(t, 'SKUs on hand', Fmt.number(_inv?['skus'] ?? 0)),
          const SizedBox(height: 10),
          _glanceRow(t, 'Aged over 90 days', Fmt.percent(over90),
              valueColor: critical ? AppColors.critical : null),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(children: [
              Container(height: 8, color: t.gridline),
              FractionallySizedBox(
                widthFactor: (over90 / 100).clamp(0.0, 1.0),
                child: Container(height: 8, color: critical ? AppColors.critical : t.series[0]),
              ),
            ]),
          ),
          const SizedBox(height: 6),
          Text('${Fmt.moneyShort(_inv?['over90Value'] ?? 0)} sitting beyond a quarter',
              style: TextStyle(fontSize: 11, color: t.textMuted)),
        ]),
      ),
    );
  }

  Widget _glanceRow(BiTokens t, String label, String value, {Color? valueColor}) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: t.textSecondary)),
          Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: valueColor ?? t.textPrimary)),
        ],
      );

  Widget _scopeBanner(BiTokens t, String note) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: t.series[0].withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(Icons.info_outline, size: 18, color: t.series[0]),
          const SizedBox(width: 8),
          Expanded(child: Text(note, style: TextStyle(fontSize: 12.5, color: t.textSecondary))),
        ]),
      );

  Widget _errorBanner(BiTokens t, String msg) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.critical.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.critical.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.critical),
          const SizedBox(width: 8),
          Expanded(child: Text(msg, style: const TextStyle(fontSize: 12.5, color: AppColors.critical))),
        ]),
      );
}

class _InsightsButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _InsightsButton({required this.count, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    return Stack(clipBehavior: Clip.none, children: [
      IconButton(onPressed: onTap, icon: const Icon(Icons.auto_awesome_outlined)),
      if (count > 0)
        Positioned(
          right: 4,
          top: 4,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: t.brandSoft, shape: BoxShape.circle),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            child: Text('$count',
                textAlign: TextAlign.center,
                style: TextStyle(color: t.brand, fontSize: 9, fontWeight: FontWeight.w700)),
          ),
        ),
    ]);
  }
}

class _FilterButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _FilterButton({required this.count, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(clipBehavior: Clip.none, children: [
        IconButton(onPressed: onTap, icon: const Icon(Icons.tune)),
        if (count > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: t.brandSoft, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text('$count',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: t.brand, fontSize: 9, fontWeight: FontWeight.w700)),
            ),
          ),
      ]),
    );
  }
}
