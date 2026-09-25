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

  String _mode = 'yoy';
  String _measure = 'sales';
  bool _likeForLike = true;

  static const _modes = {'yoy': 'Year on year', 'qoq': 'Quarter on quarter', 'mom': 'Month on month'};
  static const _measures = {'sales': 'Net sales', 'grossProfit': 'Gross profit', 'qty': 'Quantity'};

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

  Map<String, dynamic> get _body =>
      {'filters': _filters.payload('periods'), 'mode': _mode, 'likeForLike': _likeForLike};

  Future<Map<String, dynamic>?> _tryPost(String path, Object body) async {
    try {
      final res = await context.read<AuthState>().client.post(path, body);
      return res is Map ? Map<String, dynamic>.from(res) : null;
    } on ApiException {
      return null;
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final loading = context.read<LoadingState>()..show();
    final api = context.read<AuthState>().client;
    try {
      final res = await api.post('/api/sales/comparison', _body);
      final pivot = await _tryPost('/api/sales/comparison-breakdown', _body);
      if (!mounted) return;
      setState(() {
        _rows = (res as Map)['rows'] as List? ?? [];
        _brandPivot = pivot;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } finally {
      loading.hide();
    }
  }

  // ── Row readers ─────────────────────────────────────────────────────

  double _cur(Map r) => ((r['current'] as Map?)?[_measure] as num?)?.toDouble() ?? 0;
  double _prior(Map r) => ((r['prior'] as Map?)?[_measure] as num?)?.toDouble() ?? 0;
  double? _growth(Map r) {
    final g = (r['growth'] as Map?)?[_measure];
    return g == null ? null : (g as num).toDouble();
  }

  String _v(dynamic value) => _measureIsCurrency ? Fmt.money(value) : Fmt.number(value);

  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    final filters = context.watch<FilterState>();
    final rows = _rows.cast<Map>();

    // Headline KPIs, all derived from the comparison rows.
    Map? latest = rows.isNotEmpty ? rows.last : null;
    Map? strongest;
    Map? weakest;
    for (final r in rows) {
      final g = _growth(r);
      if (g == null) continue;
      if (strongest == null || g > (_growth(strongest) ?? double.negativeInfinity)) strongest = r;
      if (weakest == null || g < (_growth(weakest) ?? double.infinity)) weakest = r;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Period reports'),
        actions: [FilterButton(count: filters.activeCount('periods'), onTap: () => showFilterSheet(context, FilterModule.periods))],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            if (_error != null) ErrorBanner(_error!),
            _controls(t, filters),
            const SizedBox(height: 16),
            KpiGrid(tiles: [
              KpiTile(
                label: latest == null ? 'Latest' : 'Latest — ${latest['label']}',
                value: latest == null ? 0 : _cur(latest),
                format: _measureIsCurrency ? 'currency' : 'number',
                delta: latest == null ? null : _growth(latest),
                deltaLabel: _mode == 'yoy' ? 'vs prior year' : 'vs prior period',
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
            ]),
            const SizedBox(height: 16),
            BiChartCard(
              title: 'Current vs prior',
              subtitle: 'Two bars per period — the comparison is the point',
              currency: _measureIsCurrency,
              categories: rows.map((r) => (r['label'] ?? '').toString()).toList(),
              series: [
                SeriesSpec('Current', rows.map(_cur).toList()),
                SeriesSpec('Prior', rows.map(_prior).toList()),
              ],
              height: 240,
              initialType: BiChartType.column,
              types: const [BiChartType.column, BiChartType.line, BiChartType.area, BiChartType.bar],
            ),
            const SizedBox(height: 16),
            BiChartCard(
              title: 'Growth rate',
              subtitle: _mode == 'yoy' ? 'Percentage change against the prior year' : 'Percentage change against the prior period',
              currency: false,
              percent: true,
              categories: rows.map((r) => (r['label'] ?? '').toString()).toList(),
              series: [SeriesSpec('Growth', rows.map((r) => _growth(r) ?? 0).toList())],
              height: 240,
              initialType: BiChartType.column,
              types: const [BiChartType.column, BiChartType.line, BiChartType.area],
            ),
            const SizedBox(height: 16),
            _brandCard(t),
            const SizedBox(height: 16),
            _detailCard(t, rows),
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
            onChanged: (m) => setState(() => _measure = m),
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
                child: Row(children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Checkbox(
                      value: _likeForLike,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (v) {
                        setState(() => _likeForLike = v ?? true);
                        _load();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Like-for-like — trim the prior year to the same elapsed months',
                        style: TextStyle(fontSize: 12, color: t.textSecondary)),
                  ),
                ]),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.info_outline, size: 13, color: t.textMuted),
            const SizedBox(width: 6),
            Expanded(
              child: Text('Dashed outlines mark periods still in progress.',
                  style: TextStyle(fontSize: 11.5, color: t.textMuted)),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _eyebrow(BiTokens t, String s) => Text(s.toUpperCase(),
      style: TextStyle(fontSize: 10.5, letterSpacing: 0.5, fontWeight: FontWeight.w600, color: t.textMuted));

  // ── Brand by period ─────────────────────────────────────────────────

  Widget _brandCard(BiTokens t) {
    final periods = ((_brandPivot?['periods'] as List?) ?? const []).map((e) => e.toString()).toList();
    final rows = ((_brandPivot?['rows'] as List?) ?? const []).cast<Map>();
    final grand = _brandPivot?['grandTotal'];
    final labelW = 150.0;
    final valW = 108.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Brand by period', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.textPrimary)),
          const SizedBox(height: 2),
          Text('Brand × period — grand total ${_v(grand)}', style: TextStyle(fontSize: 11.5, color: t.textMuted)),
          const SizedBox(height: 12),
          if (rows.isEmpty && !_loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(child: Text('Nothing to compare', style: TextStyle(color: t.textMuted, fontSize: 12))),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                columnWidths: {
                  0: FixedColumnWidth(labelW),
                  for (var i = 0; i < periods.length; i++) i + 1: FixedColumnWidth(valW),
                  periods.length + 1: FixedColumnWidth(valW),
                },
                children: [
                  TableRow(children: [
                    _plainHeader(t, 'Brand', false),
                    for (final p in periods) _plainHeader(t, p, true),
                    _plainHeader(t, 'Total', true),
                  ]),
                  for (final r in rows)
                    TableRow(children: [
                      _cell(t, (r['name'] ?? '—').toString(), maxLines: 2),
                      for (var i = 0; i < periods.length; i++)
                        _cell(t, _pivotVal(r, i), numeric: true, maxLines: 1),
                      _cell(t, _v(r['total']), numeric: true, maxLines: 1, bold: true),
                    ]),
                ],
              ),
            ),
        ]),
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$_modeLabel detail', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.textPrimary)),
          const SizedBox(height: 2),
          Text('Every period with its comparison base, variance and margin shift.',
              style: TextStyle(fontSize: 11.5, color: t.textMuted)),
          const SizedBox(height: 12),
          if (rows.isEmpty && !_loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(child: Text('No periods to compare', style: TextStyle(color: t.textMuted, fontSize: 12))),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                columnWidths: {
                  0: const FixedColumnWidth(labelW),
                  for (var i = 1; i < cols.length; i++) i: const FixedColumnWidth(w),
                },
                children: [
                  TableRow(children: [for (final c in cols) _plainHeader(t, c.$1, c.$2)]),
                  for (var i = 0; i < rows.length; i++) _detailRow(t, rows, i),
                ],
              ),
            ),
        ]),
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

    final gColor = g == null ? t.textMuted : (g >= 0 ? t.deltaUp : AppColors.deltaDown);
    final varColor = variance >= 0 ? t.deltaUp : AppColors.deltaDown;
    final shiftColor = gmShiftV == null ? t.textMuted : (gmShiftV >= 0 ? t.deltaUp : AppColors.deltaDown);

    return TableRow(children: [
      _cell(t, (r['label'] ?? '—').toString(), maxLines: 1, bold: true),
      _cell(t, comparedTo, maxLines: 1),
      _cell(t, _v(cur), numeric: true, maxLines: 1),
      _cell(t, _v(prior), numeric: true, maxLines: 1),
      _cell(t, '${variance >= 0 ? '+' : '-'}${_v(variance.abs())}', numeric: true, maxLines: 1, color: varColor),
      _cell(t, Fmt.delta(g), numeric: true, maxLines: 1, bold: true, color: gColor),
      _cell(t, gmNow == null ? '—' : Fmt.percent(gmNow), numeric: true, maxLines: 1),
      _cell(t, gmShiftV == null ? '—' : '${gmShiftV >= 0 ? '+' : ''}${gmShiftV.toStringAsFixed(1)} pts',
          numeric: true, maxLines: 1, color: shiftColor),
    ]);
  }

  // ── Table plumbing ──────────────────────────────────────────────────

  Widget _plainHeader(BiTokens t, String label, bool numeric) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.gridline))),
        child: Text(label.toUpperCase(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: numeric ? TextAlign.right : TextAlign.left,
            style: TextStyle(fontSize: 10, letterSpacing: 0.5, fontWeight: FontWeight.w600, color: t.textMuted)),
      );

  Widget _cell(BiTokens t, String text, {bool numeric = false, int maxLines = 2, bool bold = false, Color? color}) =>
      Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.gridline))),
        child: Text(text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            textAlign: numeric ? TextAlign.right : TextAlign.left,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
                color: color ?? (bold ? t.textPrimary : t.textSecondary))),
      );
}
