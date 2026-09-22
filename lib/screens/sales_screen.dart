import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../api.dart';
import '../format.dart';
import '../state/auth_state.dart';
import '../state/filter_state.dart';
import '../theme.dart';
import '../widgets/bi_chart.dart';
import '../widgets/common.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/insights_sheet.dart';
import '../widgets/kpi_tile.dart';
import '../widgets/pivot_card.dart';

/// Sales — the mobile counterpart of `web/app/pages/sales.vue`: one filter bar
/// (break down by / measure / time grain), the six KPI tiles, then trend,
/// breakdown, quarterly mix, month-on-month, Pareto/ABC and the transaction
/// detail, in the web's order.
class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});
  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  late FilterState _filters;
  Timer? _debounce;

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _dimOptions = _fallbackDims.map((e) => Map<String, dynamic>.from(e)).toList();
  List<Map<String, dynamic>> _measureOptions = _fallbackMeasures.map((e) => Map<String, dynamic>.from(e)).toList();

  Map<String, dynamic>? _kpis;
  List<dynamic> _trend = [];
  Map<String, dynamic>? _breakdown;
  Map<String, dynamic>? _mix;
  Map<String, dynamic>? _pareto;
  List<dynamic> _insights = [];
  Map<String, dynamic>? _mom;

  bool _detailLoading = true;
  List<dynamic> _detail = [];
  int _detailTotal = 0;

  String _dimension = 'brand';
  String _measure = 'sales';
  String _grain = 'month';
  String _paretoDim = 'customer';
  int _page = 1;
  String _sortBy = 'date';
  String _sortDir = 'desc';

  static const _fallbackDims = [
    {'key': 'brand', 'label': 'Brand'},
    {'key': 'salesman', 'label': 'Salesman'},
    {'key': 'customer', 'label': 'Customer'},
    {'key': 'productManager', 'label': 'Product Manager'},
    {'key': 'productGroup', 'label': 'Product Group'},
  ];
  static const _fallbackMeasures = [
    {'key': 'sales', 'label': 'Net Sales', 'format': 'currency'},
    {'key': 'cost', 'label': 'Cost', 'format': 'currency'},
    {'key': 'grossProfit', 'label': 'Gross Profit', 'format': 'currency'},
    {'key': 'qty', 'label': 'Quantity', 'format': 'number'},
  ];
  static const _grains = ['day', 'month', 'quarter', 'year'];
  static const _pageSize = 25;

  @override
  void initState() {
    super.initState();
    _filters = context.read<FilterState>();
    _filters.addListener(_onFilters);
    _loadMeta();
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
    _debounce = Timer(const Duration(milliseconds: 350), () {
      setState(() => _page = 1);
      _load();
    });
  }

  String get _dimLabel => _labelFor(_dimOptions, _dimension);
  String get _paretoLabel => _labelFor(_dimOptions, _paretoDim);
  Map<String, dynamic> get _measureMeta =>
      _measureOptions.firstWhere((m) => m['key'] == _measure, orElse: () => _fallbackMeasures[0]);
  String get _measureLabel => (_measureMeta['label'] ?? 'Value').toString();
  bool get _measureIsCurrency => (_measureMeta['format'] ?? 'number') == 'currency';

  static String _labelFor(List<Map<String, dynamic>> opts, String key) =>
      (opts.firstWhere((d) => d['key'] == key, orElse: () => {'label': key})['label'] ?? key).toString();

  Map<String, dynamic> get _body => {'filters': _filters.salesPayload};

  /// Month-on-month drops the date window but keeps every other filter, exactly
  /// like the web — a year-to-date range would starve the comparison of basis.
  Map<String, dynamic> get _momBody {
    final f = Map<String, dynamic>.from(_filters.salesPayload)
      ..remove('dateFrom')
      ..remove('dateTo');
    return {'filters': f, 'mode': 'mom'};
  }

  Future<void> _loadMeta() async {
    try {
      final api = context.read<AuthState>().client;
      final res = await api.get('/api/sales/meta') as Map;
      if (!mounted) return;
      setState(() {
        _dimOptions = ((res['dimensions'] as List?) ?? const []).cast<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        _measureOptions = ((res['measures'] as List?) ?? const []).cast<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        if (_dimOptions.isEmpty) _dimOptions = _fallbackDims.map((e) => Map<String, dynamic>.from(e)).toList();
        if (_measureOptions.isEmpty) _measureOptions = _fallbackMeasures.map((e) => Map<String, dynamic>.from(e)).toList();
      });
    } catch (_) {
      // Meta is a nicety; the fallbacks keep the page usable offline.
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = context.read<AuthState>().client;
    _loadDetail();
    try {
      final results = await Future.wait([
        api.post('/api/sales/kpis', _body),
        api.post('/api/sales/timeseries', {..._body, 'grain': _grain, 'measure': _measure}),
        api.post('/api/sales/breakdown', {..._body, 'dimension': _dimension, 'measure': _measure, 'limit': 12}),
        api.post('/api/sales/pivot', {..._body, 'rows': _dimension, 'cols': 'quarter', 'measure': _measure}),
        api.post('/api/sales/pareto', {..._body, 'dimension': _paretoDim, 'measure': _measure}),
        api.post('/api/sales/insights', {..._body, 'dimension': _dimension, 'grain': _grain}),
        api.post('/api/sales/comparison', _momBody),
      ]);
      if (!mounted) return;
      setState(() {
        _kpis = results[0] as Map<String, dynamic>;
        _trend = (results[1] as Map)['points'] as List? ?? [];
        _breakdown = results[2] as Map<String, dynamic>;
        _mix = results[3] as Map<String, dynamic>;
        _pareto = results[4] as Map<String, dynamic>;
        _insights = (results[5] as Map)['insights'] as List? ?? [];
        _mom = results[6] as Map<String, dynamic>;
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

  Future<void> _loadDetail() async {
    if (!mounted) return;
    setState(() => _detailLoading = true);
    final api = context.read<AuthState>().client;
    try {
      final res = await api.post('/api/sales/detail', {
        ..._body,
        'page': _page,
        'pageSize': _pageSize,
        'sortBy': _sortBy,
        'sortDir': _sortDir,
      }) as Map;
      if (!mounted) return;
      setState(() {
        _detail = res['rows'] as List? ?? [];
        _detailTotal = (res['total'] as num?)?.toInt() ?? 0;
        _detailLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _detailLoading = false;
        _error ??= e.message;
      });
    }
  }

  /// The insights a given chart explains itself with — mirrors the web's
  /// per-visual `.filter((i) => [...ids].includes(i.id))`.
  List<Map<String, dynamic>> _insightsFor(List<String> ids) => _insights
      .whereType<Map>()
      .where((i) => ids.contains((i['id'] ?? '').toString()))
      .map((i) => Map<String, dynamic>.from(i))
      .toList();

  void _sortDetail(String key) {
    setState(() {
      if (_sortBy == key) {
        _sortDir = _sortDir == 'asc' ? 'desc' : 'asc';
      } else {
        _sortBy = key;
        _sortDir = 'desc';
      }
      _page = 1;
    });
    _loadDetail();
  }

  Future<void> _exportCsv() async {
    final api = context.read<AuthState>().client;
    try {
      final csv = await api.postText('/api/sales/export', {'filters': _filters.salesPayload, 'limit': 20000});
      final stamp = DateTime.now().toIso8601String().substring(0, 10);
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(utf8.encode(csv), mimeType: 'text/csv', name: 'ardent-sales-$stamp.csv')],
        subject: 'Sales detail',
      ));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    final filters = context.watch<FilterState>();
    final k = (_kpis?['current'] as Map?) ?? const {};
    final d = (_kpis?['delta'] as Map?) ?? const {};

    return Scaffold(
      appBar: AppBar(title: const Text('Sales')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            if (_error != null) ErrorBanner(_error!),
            _filterBar(t, filters),
            const SizedBox(height: 12),
            KpiGrid(tiles: [
              KpiTile(label: 'Net sales', value: k['sales'], format: 'currency', delta: d['sales'], loading: _loading),
              KpiTile(label: 'Cost', value: k['cost'], format: 'currency', loading: _loading),
              KpiTile(label: 'Gross profit', value: k['grossProfit'], format: 'currency', delta: d['grossProfit'], loading: _loading),
              KpiTile(label: 'Gross margin', value: k['gmPercent'], format: 'percent', delta: d['gmPercent'], deltaIsPoints: true, loading: _loading),
              KpiTile(label: 'Quantity', value: k['qty'], format: 'number', delta: d['qty'], loading: _loading),
              KpiTile(label: 'Avg invoice', value: k['avgInvoice'], format: 'currency', loading: _loading,
                  sub: '${Fmt.number(k['invoices'] ?? 0)} invoices'),
            ]),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: _barButton(t,
                  icon: Icons.lightbulb_outline,
                  label: 'Insights',
                  badge: _insights.length,
                  onTap: () => showInsightsSheet(context, _insights)),
            ),
            const SizedBox(height: 12),
            BiChartCard(
              title: 'Trend by $_grain',
              subtitle: 'Switch the form from the menu — the data does not change, only how it reads',
              categories: _trend.map((p) => (p['label'] ?? '').toString()).toList(),
              series: [
                SeriesSpec(_measureLabel, _trend.map((p) => (p[_measure] as num?)?.toDouble() ?? 0).toList()),
              ],
              currency: _measureIsCurrency,
              height: 220,
              types: const [BiChartType.line, BiChartType.area, BiChartType.column],
              insights: _insightsFor(const ['trend', 'latest-change', 'outlier', 'forecast', 'half-shift']),
            ),
            const SizedBox(height: 16),
            BiChartCard(
              title: 'By $_dimLabel',
              subtitle: 'Tap to add it to the filter',
              currency: _measureIsCurrency,
              bars: ((_breakdown?['rows'] as List?) ?? const []).cast<Map>().map((r) {
                final name = (r['name'] ?? '—').toString();
                return BarDatum(name, (r[_measure] as num?)?.toDouble() ?? 0,
                    selected: filters.sales(_dimension).contains(name));
              }).toList(),
              onBarTap: (c) => filters.toggleSales(_dimension, c),
              types: const [BiChartType.bar, BiChartType.column, BiChartType.donut, BiChartType.treemap],
              insights: _insightsFor(const ['leader', 'concentration', 'margin-spread', 'negatives']),
            ),
            const SizedBox(height: 16),
            _pivotCard(t),
            const SizedBox(height: 20),
            _momSection(t),
            const SizedBox(height: 20),
            _paretoSection(t),
            const SizedBox(height: 20),
            _detailCard(t),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Filter bar ──────────────────────────────────────────────────────

  Widget _filterBar(BiTokens t, FilterState filters) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: _dropdown(t, 'Break down by', _dimOptions.map((e) => e['label'].toString()).toList(), _dimLabel,
                  (label) {
                final key = _dimOptions.firstWhere((e) => e['label'] == label)['key'].toString();
                setState(() => _dimension = key);
                _load();
              }),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _dropdown(t, 'Measure', _measureOptions.map((e) => e['label'].toString()).toList(), _measureLabel,
                  (label) {
                final key = _measureOptions.firstWhere((e) => e['label'] == label)['key'].toString();
                setState(() => _measure = key);
                _load();
              }),
            ),
          ]),
          const SizedBox(height: 12),
          _eyebrow(t, 'Time grain'),
          const SizedBox(height: 6),
          Row(children: [
            for (final g in _grains)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: g == _grains.last ? 0 : 6),
                  child: _grainButton(t, g),
                ),
              ),
          ]),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: _barButton(t,
                icon: Icons.filter_list_outlined,
                label: 'Advanced filters',
                badge: filters.activeSalesCount,
                onTap: () => showSalesFilterSheet(context)),
          ),
        ]),
      ),
    );
  }

  Widget _eyebrow(BiTokens t, String s) => Text(s.toUpperCase(),
      style: TextStyle(fontSize: 10.5, letterSpacing: 0.5, fontWeight: FontWeight.w600, color: t.textMuted));

  Widget _dropdown(BiTokens t, String label, List<String> items, String value, ValueChanged<String> onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _eyebrow(t, label),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: t.gridline),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: items.contains(value) ? value : (items.isEmpty ? null : items.first),
            style: TextStyle(fontSize: 13, color: t.textPrimary),
            iconEnabledColor: t.textSecondary,
            items: [
              for (final i in items)
                DropdownMenuItem(
                  value: i,
                  child: Text(i, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: t.textPrimary)),
                ),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ),
    ]);
  }

  Widget _grainButton(BiTokens t, String g) {
    final active = g == _grain;
    return InkWell(
      onTap: () {
        setState(() => _grain = g);
        _load();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: active ? t.brand : t.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? t.brand : t.gridline),
        ),
        child: Text(g[0].toUpperCase() + g.substring(1),
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: active ? t.brandInk : t.textSecondary)),
      ),
    );
  }

  Widget _barButton(BiTokens t,
      {required IconData icon, required String label, int badge = 0, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: t.gridline),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: t.textSecondary),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.textPrimary)),
          if (badge > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: t.brandSoft, borderRadius: BorderRadius.circular(999)),
              child: Text('$badge', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: t.brand)),
            ),
          ],
        ]),
      ),
    );
  }

  // ── Quarterly mix ───────────────────────────────────────────────────

  Widget _pivotCard(BiTokens t) {
    final columns = ((_mix?['columns'] as List?) ?? const []).map((e) => e.toString()).toList();
    final rows = ((_mix?['rows'] as List?) ?? const [])
        .cast<Map>()
        .map((r) => PivotRow(
              (r['name'] ?? '—').toString(),
              ((r['values'] as List?) ?? const []).map((v) => (v as num?)?.toDouble() ?? 0).toList(),
              (r['total'] as num?)?.toDouble() ?? 0,
            ))
        .toList();
    final totals = ((_mix?['columnTotals'] as List?) ?? const []).map((v) => (v as num?)?.toDouble() ?? 0).toList();
    final grand = (_mix?['grandTotal'] as num?)?.toDouble() ?? 0;
    return BiPivotCard(
      title: 'Quarterly mix',
      subtitle: '$_dimLabel × quarter — grand total ${Fmt.money(grand)}',
      rowLabel: _dimLabel,
      columns: columns,
      rows: rows,
      columnTotals: totals,
      currency: _measureIsCurrency,
      onRowTap: (name) => context.read<FilterState>().toggleSales(_dimension, name),
    );
  }

  // ── Month on month ──────────────────────────────────────────────────

  Widget _momSection(BiTokens t) {
    final all = ((_mom?['rows'] as List?) ?? const []).cast<Map>();
    final rows = all.length > 12 ? all.sublist(all.length - 12) : all;
    final trimmed = all.length - rows.length;
    final latest = rows.isEmpty ? null : rows.last;
    final hasPartial = rows.any((r) => r['partial'] == true);
    final labels = rows.map((r) => (r['label'] ?? '').toString()).toList();

    List<double> pick(String side, String m) =>
        rows.map((r) => ((r[side] as Map?)?[m] as num?)?.toDouble() ?? 0).toList();
    List<double> growth(String m) =>
        rows.map((r) => ((r['growth'] as Map?)?[m] as num?)?.toDouble() ?? 0).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Month on month', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.textPrimary)),
      const SizedBox(height: 2),
      Text(
          'Each month against the one before it, over the full history rather than the date window above. The most recent twelve months are shown here; the whole series is in Period reports.',
          style: TextStyle(fontSize: 11.5, color: t.textMuted)),
      if (hasPartial) ...[
        const SizedBox(height: 4),
        Text('Dashed outlines mark periods still in progress.', style: TextStyle(fontSize: 11.5, color: t.textMuted)),
      ],
      const SizedBox(height: 12),
      if (latest != null)
        KpiGrid(tiles: [
          KpiTile(
              label: 'Net sales — ${latest['label']}',
              value: (latest['current'] as Map?)?['sales'],
              format: 'currency',
              delta: (latest['growth'] as Map?)?['sales'],
              deltaLabel: 'vs prior month',
              loading: _loading),
          KpiTile(
              label: 'Gross profit — ${latest['label']}',
              value: (latest['current'] as Map?)?['grossProfit'],
              format: 'currency',
              delta: (latest['growth'] as Map?)?['grossProfit'],
              deltaLabel: 'vs prior month',
              loading: _loading),
          KpiTile(
              label: 'Gross margin — ${latest['label']}',
              value: (latest['current'] as Map?)?['gmPercent'],
              format: 'percent',
              delta: (latest['growth'] as Map?)?['gmPercent'],
              deltaIsPoints: true,
              deltaLabel: 'vs prior month',
              loading: _loading),
          KpiTile(
              label: 'Compared with',
              value: (latest['comparedTo'] ?? '—').toString(),
              format: 'number',
              loading: _loading,
              sub: '${rows.length} periods shown'),
        ]),
      const SizedBox(height: 12),
      BiChartCard(
        title: 'Net sales — current vs prior month',
        subtitle: 'Two bars per period, side by side — the comparison is the point',
        categories: labels,
        series: [SeriesSpec('Current', pick('current', 'sales')), SeriesSpec('Prior month', pick('prior', 'sales'))],
        currency: true,
        height: 200,
        initialType: BiChartType.column,
        types: const [BiChartType.column, BiChartType.line, BiChartType.bar],
      ),
      const SizedBox(height: 16),
      BiChartCard(
        title: 'Gross profit — current vs prior month',
        subtitle: 'A panel of its own rather than a second axis: gross profit is far smaller than sales, and one shared scale would flatten it',
        categories: labels,
        series: [
          SeriesSpec('Current', pick('current', 'grossProfit')),
          SeriesSpec('Prior month', pick('prior', 'grossProfit')),
        ],
        currency: true,
        height: 200,
        initialType: BiChartType.column,
        types: const [BiChartType.column, BiChartType.line, BiChartType.bar],
      ),
      const SizedBox(height: 16),
      BiChartCard(
        title: 'Growth against the prior month',
        subtitle: 'Both series are percentages, so they share one axis. Gross profit running below sales means margin is being given away to hold volume.',
        categories: labels,
        series: [SeriesSpec('Net sales', growth('sales')), SeriesSpec('Gross profit', growth('grossProfit'))],
        currency: false,
        percent: true,
        height: 200,
        defaultTable: true,
        types: const [BiChartType.column, BiChartType.line, BiChartType.bar],
      ),
      const SizedBox(height: 16),
      _momTable(t, rows, trimmed),
    ]);
  }

  Widget _momTable(BiTokens t, List<Map> rows, int trimmed) {
    final widths = const <double>[104, 88, 88, 88, 84, 88, 88, 84, 72, 84];
    return Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            columnWidths: {for (var i = 0; i < widths.length; i++) i: FixedColumnWidth(widths[i])},
            children: [
              TableRow(
                children: [
                  for (final h in const [
                    'Period', 'Compared to', 'Net sales', 'Prior', 'Change',
                    'Gross profit', 'Prior', 'Change', 'GM% now', 'GM% shift',
                  ])
                    _momHeader(t, h, left: h == 'Period' || h == 'Compared to'),
                ],
              ),
              for (final r in rows.reversed) _momRow(t, r),
            ],
          ),
        ),
        if (trimmed > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text('Showing the most recent ${rows.length} periods; $trimmed earlier periods are in Period reports.',
                style: TextStyle(fontSize: 10.5, color: t.textMuted)),
          ),
      ]),
    );
  }

  Widget _momHeader(BiTokens t, String s, {bool left = false}) => Container(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.gridline))),
        child: Text(s.toUpperCase(),
            textAlign: left ? TextAlign.left : TextAlign.right,
            style: TextStyle(fontSize: 10, letterSpacing: 0.5, fontWeight: FontWeight.w600, color: t.textMuted)),
      );

  TableRow _momRow(BiTokens t, Map r) {
    final cur = (r['current'] as Map?) ?? const {};
    final pri = (r['prior'] as Map?) ?? const {};
    final gr = (r['growth'] as Map?) ?? const {};
    final partial = r['partial'] == true;

    Widget numCell(dynamic v, String Function(dynamic) fmt, {Color? color, bool bold = false}) => Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.gridline))),
          child: Text(fmt(v),
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 11.5, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: color ?? t.textSecondary)),
        );

    Widget changeCell(dynamic g, {bool points = false}) {
      final v = (g as num?)?.toDouble();
      final color = v == null ? t.textMuted : (v >= 0 ? t.deltaUp : AppColors.deltaDown);
      final text = v == null
          ? '—'
          : points
              ? '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)} pts'
              : '${v >= 0 ? '▲ ' : '▼ '}${Fmt.delta(v)}';
      return numCell(text, (s) => s.toString(), color: color, bold: true);
    }

    return TableRow(children: [
      Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.gridline))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text((r['label'] ?? '—').toString(), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: t.textPrimary)),
          if (partial) ...[
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: t.brandSoft, borderRadius: BorderRadius.circular(999)),
              child: Text('in progress', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: t.brand)),
            ),
          ],
        ]),
      ),
      numCell((r['comparedTo'] ?? '—').toString(), (s) => s.toString()),
      numCell(cur['sales'], Fmt.money),
      numCell(pri['sales'], Fmt.money),
      changeCell(gr['sales']),
      numCell(cur['grossProfit'], Fmt.money),
      numCell(pri['grossProfit'], Fmt.money),
      changeCell(gr['grossProfit']),
      numCell(cur['gmPercent'], (v) => Fmt.percent(v)),
      changeCell(gr['gmPercent'], points: true),
    ]);
  }

  // ── Pareto and ABC ──────────────────────────────────────────────────

  Widget _paretoSection(BiTokens t) {
    final rows = ((_pareto?['rows'] as List?) ?? const []).cast<Map>().take(25).toList();
    final classes = ((_pareto?['classes'] as List?) ?? const []).cast<Map>();
    final cats = rows.map((r) => (r['name'] ?? '').toString()).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Pareto and ABC analysis', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.textPrimary)),
            const SizedBox(height: 2),
            Text('Value on top, cumulative share below — two panels rather than two y-axes on one plot.',
                style: TextStyle(fontSize: 11.5, color: t.textMuted)),
          ]),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 150,
          child: _dropdown(t, 'Rank', _dimOptions.map((e) => e['label'].toString()).toList(), _paretoLabel, (label) {
            final key = _dimOptions.firstWhere((e) => e['label'] == label)['key'].toString();
            setState(() => _paretoDim = key);
            _load();
          }),
        ),
      ]),
      const SizedBox(height: 12),
      BiChartCard(
        title: 'Value by $_paretoLabel',
        categories: cats,
        series: [SeriesSpec('Value', rows.map((r) => (r[_measure] as num?)?.toDouble() ?? 0).toList())],
        currency: _measureIsCurrency,
        height: 200,
        initialType: BiChartType.column,
        types: const [BiChartType.column, BiChartType.bar],
      ),
      const SizedBox(height: 16),
      BiChartCard(
        title: 'Cumulative share',
        subtitle: 'Cumulative share of the total',
        categories: cats,
        series: [SeriesSpec('Cumulative share', rows.map((r) => (r['cumulative'] as num?)?.toDouble() ?? 0).toList())],
        currency: false,
        percent: true,
        height: 160,
        markLines: const [MarkLineSpec('80% — class A boundary', 80)],
        types: const [BiChartType.line, BiChartType.area],
      ),
      const SizedBox(height: 16),
      if (classes.isNotEmpty)
        Row(children: [
          for (var i = 0; i < classes.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: _classCard(t, classes[i])),
          ],
        ]),
    ]);
  }

  Widget _classCard(BiTokens t, Map c) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _eyebrow(t, 'Class ${c['class']}'),
            const SizedBox(height: 6),
            Text(Fmt.number(c['count']), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: t.textPrimary)),
            const SizedBox(height: 2),
            Text('${Fmt.percent(c['share'])} of value — ${Fmt.money(c['value'])}',
                style: TextStyle(fontSize: 10.5, color: t.textMuted)),
          ]),
        ),
      );

  // ── Transaction detail ──────────────────────────────────────────────

  static const _detailCols = [
    ('date', 'Date', 86.0, false),
    ('invoice', 'Invoice', 84.0, false),
    ('customer', 'Customer', 150.0, false),
    ('salesman', 'Salesman', 130.0, false),
    ('brand', 'Brand', 84.0, false),
    ('item', 'Item', 100.0, false),
    ('qty', 'Qty', 44.0, true),
    ('sales', 'Net sales', 84.0, true),
    ('grossProfit', 'Gross profit', 104.0, true),
    ('gmPercent', 'GM %', 56.0, true),
  ];

  Widget _detailCard(BiTokens t) {
    final pages = max(1, (_detailTotal / _pageSize).ceil());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Transaction detail', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.textPrimary)),
            const Spacer(),
            Text('${Fmt.number(_detailTotal)} rows', style: TextStyle(fontSize: 11.5, color: t.textMuted)),
            const SizedBox(width: 8),
            InkWell(
              onTap: _exportCsv,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: t.gridline)),
                child: Text('Export CSV', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.textPrimary)),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          if (_detail.isEmpty && !_detailLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(child: Text('No transactions for this selection', style: TextStyle(color: t.textMuted, fontSize: 12))),
            )
          else
            Opacity(
              opacity: _detailLoading ? 0.4 : 1,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Table(
                  columnWidths: {for (var i = 0; i < _detailCols.length; i++) i: FixedColumnWidth(_detailCols[i].$3)},
                  children: [
                    TableRow(children: [for (final c in _detailCols) _detailHeader(t, c.$1, c.$2, c.$4)]),
                    for (final r in _detail.cast<Map>()) _detailRow(t, r),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: _page > 1
                  ? () {
                      setState(() => _page--);
                      _loadDetail();
                    }
                  : null,
              icon: const Icon(Icons.chevron_left, size: 18),
            ),
            Text('Page $_page of $pages', style: TextStyle(fontSize: 11.5, color: t.textMuted)),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: _page < pages
                  ? () {
                      setState(() => _page++);
                      _loadDetail();
                    }
                  : null,
              icon: const Icon(Icons.chevron_right, size: 18),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _detailHeader(BiTokens t, String key, String label, bool numeric) {
    final sorted = _sortBy == key;
    return InkWell(
      onTap: () => _sortDetail(key),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.gridline))),
        child: Row(
          mainAxisAlignment: numeric ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Flexible(
              child: Text(label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: numeric ? TextAlign.right : TextAlign.left,
                  style: TextStyle(fontSize: 10, letterSpacing: 0.5, fontWeight: FontWeight.w600,
                      color: sorted ? t.brand : t.textMuted)),
            ),
            if (sorted) Icon(_sortDir == 'asc' ? Icons.arrow_upward : Icons.arrow_downward, size: 11, color: t.brand),
          ],
        ),
      ),
    );
  }

  TableRow _detailRow(BiTokens t, Map r) {
    Widget cell(String text, {bool numeric = false, int maxLines = 2, bool bold = false}) => Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.gridline))),
          child: Text(text,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              textAlign: numeric ? TextAlign.right : TextAlign.left,
              style: TextStyle(fontSize: 11.5, fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
                  color: bold ? t.textPrimary : t.textSecondary)),
        );
    return TableRow(children: [
      cell(Fmt.date(r['date']), maxLines: 1),
      cell('${r['invoice'] ?? '—'}', maxLines: 1),
      cell('${r['customer'] ?? '—'}'),
      cell('${r['salesman'] ?? '—'}'),
      cell('${r['brand'] ?? '—'}', maxLines: 1),
      cell('${r['item'] ?? '—'}', maxLines: 1),
      cell(Fmt.number(r['qty']), numeric: true, maxLines: 1),
      cell(Fmt.money(r['sales']), numeric: true, maxLines: 1, bold: true),
      cell(Fmt.money(r['grossProfit']), numeric: true, maxLines: 1),
      cell(Fmt.percent(r['gmPercent']), numeric: true, maxLines: 1),
    ]);
  }
}
