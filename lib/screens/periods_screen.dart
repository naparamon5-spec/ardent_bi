import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../format.dart';
import '../state/auth_state.dart';
import '../state/filter_state.dart';
import '../state/ui_state.dart';
import '../theme.dart';
import '../widgets/bi_chart.dart';
import '../widgets/common.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/kpi_tile.dart';

/// Period reports — the mobile counterpart of `web/app/pages/periods.vue`: the
/// comparison / measure choosers and the like-for-like toggle, four headline
/// KPIs (latest, strongest, weakest, periods compared), current-vs-prior and
/// growth-rate charts, the brand-by-period pivot, then the per-period detail.
class PeriodsScreen extends StatefulWidget {
  const PeriodsScreen({super.key});
  @override
  State<PeriodsScreen> createState() => _PeriodsScreenState();
}

class _PeriodsScreenState extends State<PeriodsScreen> {
  late FilterState _filters;
  Timer? _debounce;

  bool _loading = true;
  String? _error;
  List<dynamic> _rows = [];

  Map<String, dynamic>? _brandPivot;
  Map<String, dynamic>? _analysis;

  String _mode = 'yoy';
  String _measure = 'sales';
  bool _likeForLike = true;
  int _selectedYear = DateTime.now().year;
  String? _selectedQuarter;

  static const _modes = {
    'yoy': 'Year on year',
    'qoq': 'Quarter on quarter',
    'mom': 'Month on month',
  };
  static const _measures = {
    'sales': 'Net sales',
    'grossProfit': 'Gross profit',
    'qty': 'Quantity',
  };

  bool get _measureIsCurrency => _measure != 'qty';
  String get _modeLabel => _modes[_mode] ?? 'Year on year';

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

  Map<String, dynamic> get _body => {
    'filters': _filters.payload('periods'),
    'mode': _mode,
    'alignPartial': _likeForLike,
    if (_selectedQuarter != null) 'quarter': _selectedQuarter,
  };

  Future<Map<String, dynamic>?> _tryPost(String path, Object body) async {
    try {
      final res = await context.read<AuthState>().client.post(path, body);
      return res is Map ? Map<String, dynamic>.from(res) : null;
    } on ApiException catch (e) {
      if (mounted) reportSectionFailure(context, e.message, status: e.status);
      return null;
    }
  }

  // Responses from an older call (filters changed mid-flight) are dropped.
  int _loadGen = 0;

  Future<void> _load() async {
    if (!mounted) return;
    final gen = ++_loadGen;
    setState(() {
      _loading = true;
      _error = null;
    });
    final loading = context.read<LoadingState>()..show();
    final api = context.read<AuthState>().client;
    try {
      final res = await api.post('/api/sales/comparison', _body);
      final pivot = await _tryPost('/api/sales/pivot', {
        'filters': _filters.payload('periods'),
        'rows': 'brand',
        'cols': _mode == 'mom'
            ? 'month'
            : _mode == 'qoq'
            ? 'quarter'
            : 'year',
        'measure': _measure,
      });
      // Customer movement (vw_sales_analysis). Its windows are fixed, so the
      // date range doesn't move it — only the other filters do, as on the web.
      final analysis = await _tryPost('/api/sales/analysis', {'filters': _filters.payload('periods')});
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _rows = (res as Map)['rows'] as List? ?? [];
        _brandPivot = pivot;
        _analysis = analysis;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } finally {
      loading.hide();
    }
  }

  // ── Row readers ─────────────────────────────────────────────────────

  double _cur(Map r) =>
      ((r['current'] as Map?)?[_measure] as num?)?.toDouble() ?? 0;
  double _prior(Map r) =>
      ((r['prior'] as Map?)?[_measure] as num?)?.toDouble() ?? 0;
  double? _growth(Map r) {
    final g = (r['growth'] as Map?)?[_measure];
    return g == null ? null : (g as num).toDouble();
  }

  String _v(dynamic value) =>
      _measureIsCurrency ? Fmt.money(value) : Fmt.number(value);

  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    final filters = context.watch<FilterState>();
    final rows = _rows.cast<Map>();
    // A prior under 1% of the current period (e.g. a partial first year of
    // data) turns into a six-digit growth % that flattens every other bar and
    // wins "strongest period" on noise. Keep those out of growth comparisons;
    // the detail table still lists them.
    final growthRows = rows.where((r) {
      final prior = _prior(r).abs();
      return prior > 0 && prior >= _cur(r).abs() * 0.01;
    }).toList();

    // Headline KPIs, all derived from the comparison rows.
    Map? latest = rows.isNotEmpty ? rows.last : null;
    Map? strongest;
    Map? weakest;
    for (final r in growthRows) {
      final g = _growth(r);
      if (g == null) continue;
      if (strongest == null ||
          g > (_growth(strongest) ?? double.negativeInfinity))
        strongest = r;
      if (weakest == null || g < (_growth(weakest) ?? double.infinity))
        weakest = r;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Period reports'),
        actions: [
          FilterButton(
            count: filters.activeCount('periods'),
            onTap: () => showFilterSheet(context, FilterModule.periods),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            if (_error != null) ErrorBanner(_error!),
            _controls(t, filters),
            const SizedBox(height: 16),
            KpiGrid(
              tiles: [
                KpiTile(
                  label: latest == null
                      ? 'Latest'
                      : 'Latest — ${latest['label']}',
                  value: latest == null ? 0 : _cur(latest),
                  format: _measureIsCurrency ? 'currency' : 'number',
                  delta: latest == null ? null : _growth(latest),
                  deltaLabel: _mode == 'yoy'
                      ? 'vs prior year'
                      : 'vs prior period',
                  loading: _loading,
                ),
                KpiTile(
                  label: 'Strongest period',
                  value: (strongest?['label'] ?? '—').toString(),
                  delta: strongest == null ? null : _growth(strongest),
                  deltaLabel: 'growth',
                  loading: _loading,
                ),
                KpiTile(
                  label: 'Weakest period',
                  value: (weakest?['label'] ?? '—').toString(),
                  delta: weakest == null ? null : _growth(weakest),
                  deltaLabel: 'growth',
                  loading: _loading,
                ),
                KpiTile(
                  label: 'Periods compared',
                  value: rows.length,
                  format: 'number',
                  loading: _loading,
                  sub: '$_modeLabel basis',
                ),
              ],
            ),
            const SizedBox(height: 16),
            BiChartCard(
              title: 'Current vs prior',
              subtitle: 'Two bars per period — the comparison is the point',
              currency: _measureIsCurrency,
              categories: rows
                  .map((r) => (r['label'] ?? '').toString())
                  .toList(),
              series: [
                SeriesSpec('Current', rows.map(_cur).toList()),
                SeriesSpec('Prior', rows.map(_prior).toList()),
              ],
              height: 240,
              initialType: BiChartType.column,
              types: const [
                BiChartType.column,
                BiChartType.stacked,
                BiChartType.line,
                BiChartType.bar,
              ],
            ),
            const SizedBox(height: 16),
            BiChartCard(
              title: 'Growth rate',
              subtitle: (_mode == 'yoy'
                      ? 'Percentage change against the prior year'
                      : 'Percentage change against the prior period') +
                  (growthRows.length < rows.length
                      ? ' · periods with a negligible prior base are left out'
                      : ''),
              currency: false,
              percent: true,
              categories: growthRows
                  .map((r) => (r['label'] ?? '').toString())
                  .toList(),
              series: [
                SeriesSpec('Growth', growthRows.map((r) => _growth(r) ?? 0).toList()),
              ],
              height: 240,
              initialType: BiChartType.column,
              types: const [
                BiChartType.column,
                BiChartType.bar,
                BiChartType.line,
              ],
            ),
            const SizedBox(height: 16),
            _brandCard(t),
            const SizedBox(height: 16),
            _detailCard(t, rows),
            const SizedBox(height: 24),
            ..._customerMovement(t),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Controls ────────────────────────────────────────────────────────

  Widget _controls(BiTokens t, FilterState filters) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _eyebrow(t, 'Comparison'),
            const SizedBox(height: 8),
            ChipChooser<String>(
              options: _modes,
              value: _mode,
              onChanged: (m) {
                setState(() => _mode = m);
                _load();
              },
            ),
            const SizedBox(height: 14),
            _eyebrow(t, 'Measure'),
            const SizedBox(height: 8),
            ChipChooser<String>(
              options: _measures,
              value: _measure,
              onChanged: (m) {
                setState(() => _measure = m);
                _load();
              },
            ),
            if (_mode == 'yoy') ...[
              const SizedBox(height: 6),
              InkWell(
                onTap: () {
                  setState(() => _likeForLike = !_likeForLike);
                  _load();
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: Checkbox(
                          value: _likeForLike,
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onChanged: (v) {
                            setState(() => _likeForLike = v ?? true);
                            _load();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Like-for-like — trim the prior year to the same elapsed months',
                          style: TextStyle(
                            fontSize: 12,
                            color: t.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.info_outline, size: 13, color: t.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Dashed outlines mark periods still in progress.',
                    style: TextStyle(fontSize: 11.5, color: t.textMuted),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Customer movement ───────────────────────────────────────────────

  List<Map> _saList(String k) => ((_analysis?[k] as List?) ?? const []).whereType<Map>().toList();
  double _num(dynamic v) => (v as num?)?.toDouble() ?? 0;

  /// The web's "Customer movement" block: the sales-analysis rules applied to
  /// the filtered sales, with fixed this-year / last-year windows.
  List<Widget> _customerMovement(BiTokens t) {
    final win = (_analysis?['windows'] as Map?) ?? const {};
    final thisYear = (win['thisYear'] ?? 'This year').toString();
    final lastYear = (win['lastYear'] ?? 'last year').toString();
    final base = (win['movementBase'] ?? 'the base period').toString();
    final brands = _saList('brands');
    final churned = _saList('churned');
    final contraction = _saList('contraction');
    String who(Map r) => '${r['customer'] ?? '—'} · ${r['brand'] ?? '—'}';
    String lossTotal(List<Map> l) => Fmt.money(l.fold<double>(0, (s, r) => s + _num(r['amount'])));

    List<SeriesSpec> lossSeries(List<Map> l) => [
          SeriesSpec(base, l.map((r) => _num(r['lastYear'])).toList()),
          SeriesSpec(thisYear, l.map((r) => _num(r['thisYear'])).toList()),
          SeriesSpec('Change', l.map((r) => _num(r['amount'])).toList()),
        ];

    // Older servers don't have the endpoint; leave the section out entirely.
    if (_analysis == null || _analysis!['available'] == false) return const [];

    return [
      _eyebrow(t, 'CUSTOMER MOVEMENT'),
      const SizedBox(height: 6),
      Text(
        'Every filter above narrows these except the dates: the windows stay $thisYear against '
        '$lastYear, with customer movement measured against $base.',
        style: TextStyle(fontSize: 11.5, color: t.textMuted),
      ),
      const SizedBox(height: 12),
      BiChartCard(
        title: 'Revenue by brand, this year against last',
        subtitle: '$thisYear against $lastYear. The current year is still running, so a shorter bar is not yet a decline.',
        categories: brands.map((b) => (b['brand'] ?? '—').toString()).toList(),
        series: [
          SeriesSpec(thisYear, brands.map((b) => _num(b['thisYear'])).toList()),
          SeriesSpec(lastYear, brands.map((b) => _num(b['lastYear'])).toList()),
        ],
        height: 300,
        initialType: BiChartType.column,
        types: const [BiChartType.column],
      ),
      const SizedBox(height: 16),
      BiChartCard(
        title: 'Where revenue moved',
        subtitle: 'Customer gains and losses this year, measured against $base.',
        bars: _saList('movements').map((r) => BarDatum((r['category'] ?? '—').toString(), _num(r['amount']))).toList(),
        signColors: true,
        initialType: BiChartType.bar,
        types: const [BiChartType.bar, BiChartType.column],
      ),
      const SizedBox(height: 16),
      BiChartCard(
        title: 'Largest customer movements',
        subtitle: 'The twelve biggest swings, gains and losses together. Each bar is one customer within one brand.',
        bars: _saList('customers').map((r) => BarDatum(who(r), _num(r['amount']))).toList(),
        signColors: true,
        initialType: BiChartType.bar,
        types: const [BiChartType.bar],
      ),
      const SizedBox(height: 16),
      BiChartCard(
        title: 'Lost from churned customers — ${lossTotal(churned)}',
        subtitle: 'Bought over ₱1M in $base and under ₱1M, or under a fifth of that, in $thisYear. Biggest loss first.',
        categories: churned.map(who).toList(),
        series: lossSeries(churned),
        defaultTable: true,
        types: const [BiChartType.column],
      ),
      const SizedBox(height: 16),
      BiChartCard(
        title: 'Customers under contraction — ${lossTotal(contraction)}',
        subtitle: 'Bought over ₱1M in $base and still buying, but less: above a fifth of that and below it in $thisYear.',
        categories: contraction.map(who).toList(),
        series: lossSeries(contraction),
        defaultTable: true,
        types: const [BiChartType.column],
      ),
    ];
  }

  Widget _eyebrow(BiTokens t, String s) => Text(
    s.toUpperCase(),
    style: TextStyle(
      fontSize: 10.5,
      letterSpacing: 0.5,
      fontWeight: FontWeight.w600,
      color: t.textMuted,
    ),
  );

  // ── Brand by period ─────────────────────────────────────────────────

  Widget _brandCard(BiTokens t) {
    final periods = ((_brandPivot?['columns'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
    final rows = ((_brandPivot?['rows'] as List?) ?? const []).cast<Map>();
    final grand = _brandPivot?['grandTotal'];
    // Largest single cell anchors the heat-map scale, as on the web.
    var maxCell = 0.0;
    for (final r in rows) {
      for (final v in (r['values'] as List?) ?? const []) {
        final d = (v as num?)?.toDouble() ?? 0;
        if (d > maxCell) maxCell = d;
      }
    }
    final labelW = 150.0;
    final valW = 108.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Brand by period',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: t.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Brand × period — grand total ${_v(grand)}',
              style: TextStyle(fontSize: 11.5, color: t.textMuted),
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty && !_loading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'Nothing to compare',
                    style: TextStyle(color: t.textMuted, fontSize: 12),
                  ),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Table(
                  columnWidths: {
                    0: FixedColumnWidth(labelW),
                    for (var i = 0; i < periods.length; i++)
                      i + 1: FixedColumnWidth(valW),
                    periods.length + 1: FixedColumnWidth(valW),
                  },
                  children: [
                    TableRow(
                      children: [
                        _plainHeader(t, 'Brand', false),
                        for (final p in periods) _plainHeader(t, p, true),
                        _plainHeader(t, 'Total', true),
                      ],
                    ),
                    for (final r in rows)
                      TableRow(
                        children: [
                          _cell(t, (r['name'] ?? '—').toString(), maxLines: 2),
                          for (var i = 0; i < periods.length; i++)
                            _heatCell(
                              t,
                              _pivotVal(r, i),
                              _rawVal(r, i),
                              maxCell,
                            ),
                          _cell(
                            t,
                            _v(r['total']),
                            numeric: true,
                            maxLines: 1,
                            bold: true,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  double _rawVal(Map r, int i) {
    final vals = (r['values'] as List?) ?? const [];
    return i < vals.length ? (vals[i] as num?)?.toDouble() ?? 0 : 0.0;
  }

  /// Blue ramp from pale to navy by share of the largest cell; small values
  /// stay unshaded so the leaders stand out.
  Widget _heatCell(BiTokens t, String text, double v, double max) {
    final ratio = max <= 0 ? 0.0 : (v / max).clamp(0.0, 1.0);
    if (ratio < 0.04) return _cell(t, text, numeric: true, maxLines: 1);
    final fill = Color.lerp(
      const Color(0xFFBCD6F6),
      const Color(0xFF0B3266),
      ratio,
    )!;
    return Container(
      color: fill,
      child: _cell(
        t,
        text,
        numeric: true,
        maxLines: 1,
        color: ratio > 0.4 ? Colors.white : const Color(0xFF0B3266),
      ),
    );
  }

  String _pivotVal(Map r, int i) {
    final vals = (r['values'] as List?) ?? const [];
    final v = i < vals.length ? (vals[i] as num?)?.toDouble() ?? 0 : 0.0;
    return v == 0 ? '—' : _v(v);
  }

  // ── Per-period detail ───────────────────────────────────────────────

  Widget _detailCard(BiTokens t, List<Map> rows) {
    const labelW = 96.0;
    const w = 104.0;
    final cols = <(String, bool)>[
      ('Period', false),
      ('Compared to', false),
      ('Current', true),
      ('Prior', true),
      ('Variance', true),
      ('Change', true),
      ('GM% now', true),
      ('GM% shift', true),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$_modeLabel detail',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: t.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Every period with its comparison base, variance and margin shift.',
              style: TextStyle(fontSize: 11.5, color: t.textMuted),
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty && !_loading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'No periods to compare',
                    style: TextStyle(color: t.textMuted, fontSize: 12),
                  ),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Table(
                  columnWidths: {
                    0: const FixedColumnWidth(labelW),
                    for (var i = 1; i < cols.length; i++)
                      i: const FixedColumnWidth(w),
                  },
                  children: [
                    TableRow(
                      children: [
                        for (final c in cols) _plainHeader(t, c.$1, c.$2),
                      ],
                    ),
                    for (var i = 0; i < rows.length; i++)
                      _detailRow(t, rows, i),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Period label, plus an "in progress" chip and the aligned span
  /// (e.g. Jan–Oct) for periods that aren't finished yet, as on the web.
  Widget _periodCell(BiTokens t, Map r) {
    final partial = r['partial'] == true;
    final aligned = r['alignedTo']?.toString();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.gridline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (r['label'] ?? '—').toString(),
            maxLines: 1,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: t.textPrimary,
            ),
          ),
          if (partial) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.critical.withValues(alpha: 0.1),
                border: Border.all(
                  color: AppColors.critical.withValues(alpha: 0.3),
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'in progress',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.critical,
                ),
              ),
            ),
          ],
          if (aligned != null && aligned.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              '($aligned)',
              maxLines: 1,
              style: TextStyle(fontSize: 10, color: t.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  TableRow _detailRow(BiTokens t, List<Map> rows, int i) {
    final r = rows[i];
    final cur = _cur(r);
    final prior = _prior(r);
    final variance = cur - prior;
    final g = _growth(r);
    final gmNow = ((r['current'] as Map?)?['gmPercent'] as num?)?.toDouble();
    final gmShift = (r['growth'] as Map?)?['gmPercent'];
    final gmShiftV = gmShift == null ? null : (gmShift as num).toDouble();
    final comparedTo = i > 0 ? (rows[i - 1]['label'] ?? '—').toString() : '—';

    final gColor = g == null
        ? t.textMuted
        : (g >= 0 ? t.deltaUp : AppColors.deltaDown);
    final varColor = variance >= 0 ? t.deltaUp : AppColors.deltaDown;
    final shiftColor = gmShiftV == null
        ? t.textMuted
        : (gmShiftV >= 0 ? t.deltaUp : AppColors.deltaDown);

    // The period cell sets the row height (it may carry a chip); the rest
    // stretch to it so the row's bottom border lines up.
    return TableRow(
      children: [
        _periodCell(t, r),
        for (final c in <Widget>[
          _cell(t, comparedTo, maxLines: 1),
          _cell(t, _v(cur), numeric: true, maxLines: 1),
          _cell(t, _v(prior), numeric: true, maxLines: 1),
          _cell(
            t,
            '${variance >= 0 ? '+' : '-'}${_v(variance.abs())}',
            numeric: true,
            maxLines: 1,
            color: varColor,
          ),
          _cell(
            t,
            g == null ? Fmt.delta(g) : '${g >= 0 ? '▲' : '▼'} ${Fmt.delta(g)}',
            numeric: true,
            maxLines: 1,
            bold: true,
            color: gColor,
          ),
          _cell(
            t,
            gmNow == null ? '—' : Fmt.percent(gmNow),
            numeric: true,
            maxLines: 1,
          ),
          _cell(
            t,
            gmShiftV == null
                ? '—'
                : '${gmShiftV >= 0 ? '+' : ''}${gmShiftV.toStringAsFixed(1)} pts',
            numeric: true,
            maxLines: 1,
            color: shiftColor,
          ),
        ])
          TableCell(
            verticalAlignment: TableCellVerticalAlignment.fill,
            child: c,
          ),
      ],
    );
  }

  // ── Table plumbing ──────────────────────────────────────────────────

  Widget _plainHeader(BiTokens t, String label, bool numeric) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: t.gridline)),
    ),
    child: Text(
      label.toUpperCase(),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: numeric ? TextAlign.right : TextAlign.left,
      style: TextStyle(
        fontSize: 10,
        letterSpacing: 0.5,
        fontWeight: FontWeight.w600,
        color: t.textMuted,
      ),
    ),
  );

  Widget _cell(
    BiTokens t,
    String text, {
    bool numeric = false,
    int maxLines = 2,
    bool bold = false,
    Color? color,
  }) => Container(
    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: t.gridline)),
    ),
    child: Text(
      text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: numeric ? TextAlign.right : TextAlign.left,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        color: color ?? (bold ? t.textPrimary : t.textSecondary),
      ),
    ),
  );
}
