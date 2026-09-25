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
import '../state/ui_state.dart';
import '../theme.dart';
import '../widgets/bi_chart.dart';
import '../widgets/common.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/kpi_tile.dart';

/// Re-Order Point — the mobile counterpart of `web/app/pages/reorder-point.vue`:
/// the break-down-by / measure bar, the six headline KPIs, the forecast measure
/// by dimension, the ordering-verdict split, then the re-order-point-by-item
/// detail table, in the web's order. Gated to BU-head-and-above by the API (and
/// hidden from the menu otherwise).
class ReorderPointScreen extends StatefulWidget {
  const ReorderPointScreen({super.key});
  @override
  State<ReorderPointScreen> createState() => _ReorderPointScreenState();
}

class _ReorderPointScreenState extends State<ReorderPointScreen> {
  late FilterState _filters;
  Timer? _debounce;

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _dimOptions = _fallbackDims.map((e) => Map<String, dynamic>.from(e)).toList();
  List<Map<String, dynamic>> _measureOptions = _fallbackMeasures.map((e) => Map<String, dynamic>.from(e)).toList();

  Map<String, dynamic>? _kpis;
  Map<String, dynamic>? _breakdown;
  Map<String, dynamic>? _verdict;

  bool _detailLoading = true;
  List<dynamic> _detail = [];
  int _detailTotal = 0;

  String _dimension = 'brand';
  String _measure = 'forecast';
  int _page = 1;
  String _sortBy = 'forecast';
  String _sortDir = 'desc';

  static const _fallbackDims = [
    {'key': 'brand', 'label': 'Brand'},
    {'key': 'productGroup', 'label': 'Product Group'},
    {'key': 'verdict', 'label': 'Ordering Verdict'},
  ];
  static const _fallbackMeasures = [
    {'key': 'forecast', 'label': 'Forecast Qty', 'format': 'number'},
    {'key': 'amount', 'label': 'Order Amount', 'format': 'currency'},
    {'key': 'items', 'label': 'Items', 'format': 'number'},
    {'key': 'onHand', 'label': 'On Hand', 'format': 'number'},
  ];
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
  Map<String, dynamic> get _measureMeta =>
      _measureOptions.firstWhere((m) => m['key'] == _measure, orElse: () => _fallbackMeasures[0]);
  String get _measureLabel => (_measureMeta['label'] ?? 'Forecast Qty').toString();
  bool get _measureIsCurrency => (_measureMeta['format'] ?? 'number') == 'currency';

  static String _labelFor(List<Map<String, dynamic>> opts, String key) =>
      (opts.firstWhere((d) => d['key'] == key, orElse: () => {'label': key})['label'] ?? key).toString();

  Map<String, dynamic> get _body => {'filters': _filters.payload('reorder')};

  Future<Map<String, dynamic>?> _tryPost(String path, Object body) async {
    try {
      final res = await context.read<AuthState>().client.post(path, body);
      return res is Map ? Map<String, dynamic>.from(res) : null;
    } on ApiException {
      return null;
    }
  }

  Future<void> _loadMeta() async {
    try {
      final res = await context.read<AuthState>().client.get('/api/reorder-point/meta') as Map;
      if (!mounted) return;
      setState(() {
        final dims = ((res['dimensions'] as List?) ?? const []).cast<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        final measures = ((res['measures'] as List?) ?? const []).cast<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        if (dims.isNotEmpty) _dimOptions = dims;
        if (measures.isNotEmpty) _measureOptions = measures;
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
    final loading = context.read<LoadingState>()..show();
    final api = context.read<AuthState>().client;
    _loadDetail();
    try {
      final kpis = await api.post('/api/reorder-point/kpis', _body) as Map<String, dynamic>;
      final rest = await Future.wait([
        _tryPost('/api/reorder-point/breakdown', {..._body, 'dimension': _dimension, 'measure': _measure, 'limit': 15}),
        _tryPost('/api/reorder-point/breakdown', {..._body, 'dimension': 'verdict', 'measure': 'items', 'limit': 8}),
      ]);
      if (!mounted) return;
      setState(() {
        _kpis = kpis;
        _breakdown = rest[0];
        _verdict = rest[1];
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.status == 403
            ? 'Re-Order Point is available to business unit heads and executives only.'
            : e.message;
        _loading = false;
      });
    } finally {
      loading.hide();
    }
  }

  Future<void> _loadDetail() async {
    if (!mounted) return;
    setState(() => _detailLoading = true);
    final res = await _tryPost('/api/reorder-point/detail', {
      ..._body,
      'page': _page,
      'pageSize': _pageSize,
      'sortBy': _sortBy,
      'sortDir': _sortDir,
    });
    if (!mounted) return;
    setState(() {
      _detail = (res?['rows'] as List?) ?? const [];
      _detailTotal = (res?['total'] as num?)?.toInt() ?? 0;
      _detailLoading = false;
    });
  }

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

  String get _stamp => DateTime.now().toIso8601String().substring(0, 10);

  Future<void> _exportDetail() async {
    try {
      final csv = await context.read<AuthState>().client
          .postText('/api/reorder-point/export', {..._body, 'limit': 20000});
      await _share('ardent-reorder-point-$_stamp.csv', csv);
    } on ApiException {
      // The export endpoint may not be served in every environment; fall back to
      // the page that is already in hand rather than failing the tap.
      const cols = ['sku', 'itemDescription', 'brand', 'productGroup', 'onHand', 'backOrder', 'safetyStock',
        'leadTimeDemand', 'rop', 'forecast', 'avgNetCost'];
      await _share('ardent-reorder-point-$_stamp.csv', _csv(cols, _detail.cast<Map>()));
    }
  }

  static String _csv(List<String> cols, List<Map> rows) {
    final lines = <String>[cols.join(',')];
    for (final r in rows) {
      lines.add(cols.map((c) {
        final v = r[c];
        final s = v is num ? v.toString() : '${v ?? ''}';
        return s.contains(RegExp(r'[",\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
      }).join(','));
    }
    return lines.join('\n');
  }

  Future<void> _share(String name, String csv) => SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(utf8.encode(csv), mimeType: 'text/csv', name: name)],
        subject: name,
      ));

  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    final filters = context.watch<FilterState>();
    final k = _kpis ?? const {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Re-Order Point'),
        actions: [FilterButton(count: filters.activeCount('reorder'), onTap: () => showFilterSheet(context, FilterModule.reorder))],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            if (_error != null) ErrorBanner(_error!),
            _filterBar(t, filters),
            const SizedBox(height: 12),
            KpiGrid(tiles: [
              KpiTile(
                  label: 'Items forecast',
                  value: k['items'],
                  format: 'number',
                  loading: _loading,
                  sub: '${Fmt.number(k['brands'] ?? 0)} brands'),
              KpiTile(
                  label: 'Items to order',
                  value: k['itemsToOrder'],
                  format: 'number',
                  loading: _loading,
                  sub: '${Fmt.percent(k['toOrderShare'])} of items'),
              KpiTile(
                  label: 'Forecast quantity',
                  value: k['forecast'],
                  format: 'number',
                  loading: _loading),
              KpiTile(
                  label: 'Order amount',
                  value: k['amount'],
                  format: 'currency',
                  loading: _loading,
                  sub: (k['itemsWithoutCost'] ?? 0) != 0
                      ? '${Fmt.number(k['itemsWithoutCost'])} item(s) carry no cost, counted as zero'
                      : null),
              KpiTile(
                  label: 'Quantity on hand',
                  value: k['onHand'],
                  format: 'number',
                  loading: _loading),
              KpiTile(
                  label: 'Below reorder point',
                  value: k['belowRop'],
                  format: 'number',
                  loading: _loading,
                  sub: '${Fmt.percent(k['belowRopShare'])} of items'),
            ]),
            const SizedBox(height: 16),
            BiChartCard(
              title: '$_measureLabel by $_dimLabel',
              subtitle: 'Amounts are the forecast to order over the window — tap a bar to add it to the filter',
              currency: _measureIsCurrency,
              bars: ((_breakdown?['rows'] as List?) ?? const []).cast<Map>().map((r) {
                final name = (r['name'] ?? '—').toString();
                final v = r[_measure] ?? r['forecast'];
                return BarDatum(name, v is num ? v.toDouble() : 0,
                    selected: filters.dim('reorder', _dimension).contains(name));
              }).toList(),
              onBarTap: (c) => filters.toggleDim('reorder', _dimension, c),
              types: const [BiChartType.bar, BiChartType.column, BiChartType.treemap],
            ),
            const SizedBox(height: 16),
            BiChartCard(
              title: 'Items by ordering verdict',
              subtitle: "The view's own verdict on each item — hold, or prepare a PRS",
              currency: false,
              bars: ((_verdict?['rows'] as List?) ?? const []).cast<Map>().map((r) {
                return BarDatum((r['name'] ?? '—').toString(), (r['items'] as num?)?.toDouble() ?? 0);
              }).toList(),
              types: const [BiChartType.bar, BiChartType.column],
            ),
            const SizedBox(height: 16),
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
                setState(() => _dimension = _dimOptions.firstWhere((e) => e['label'] == label)['key'].toString());
                _load();
              }),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _dropdown(t, 'Measure', _measureOptions.map((e) => e['label'].toString()).toList(), _measureLabel,
                  (label) {
                setState(() => _measure = _measureOptions.firstWhere((e) => e['label'] == label)['key'].toString());
                _load();
              }),
            ),
          ]),
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
                  child: Text(i,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  // ── Re-order point by item ──────────────────────────────────────────

  static const _detailCols = [
    ('sku', 'SKU', 96.0, false),
    ('itemDescription', 'Description', 220.0, false),
    ('brand', 'Brand', 110.0, false),
    ('productGroup', 'Product Group', 150.0, false),
    ('onHand', 'On Hand', 78.0, true),
    ('backOrder', 'Back Order', 84.0, true),
    ('safetyStock', 'Safety Stock', 92.0, true),
    ('leadTimeDemand', 'Lead Time Demand', 118.0, true),
    ('rop', 'ROP', 64.0, true),
    ('forecast', 'Forecast Qty', 96.0, true),
    ('avgNetCost', 'Avg Net Cost', 96.0, true),
  ];

  Widget _detailCard(BiTokens t) {
    final pages = max(1, (_detailTotal / _pageSize).ceil());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text('Re-order point by item',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.textPrimary)),
            ),
            Text('${Fmt.number(_detailTotal)} rows', style: TextStyle(fontSize: 11.5, color: t.textMuted)),
            const SizedBox(width: 8),
            _exportButton(t, _detail.isEmpty ? null : _exportDetail),
          ]),
          const SizedBox(height: 12),
          if (_detail.isEmpty && !_detailLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(child: Text('Nothing to order right now', style: TextStyle(color: t.textMuted, fontSize: 12))),
            )
          else
            Opacity(
              opacity: _detailLoading ? 0.4 : 1,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Table(
                  columnWidths: {for (var i = 0; i < _detailCols.length; i++) i: FixedColumnWidth(_detailCols[i].$3)},
                  children: [
                    TableRow(children: [for (final c in _detailCols) _sortHeader(t, c.$1, c.$2, c.$4)]),
                    for (final r in _detail.cast<Map>())
                      TableRow(children: [
                        _cell(t, '${r['sku'] ?? r['item'] ?? '—'}', maxLines: 1, bold: true),
                        _cell(t, '${r['itemDescription'] ?? '—'}'),
                        _cell(t, '${r['brand'] ?? '—'}', maxLines: 1),
                        _cell(t, '${r['productGroup'] ?? '—'}', maxLines: 2),
                        _cell(t, Fmt.number(r['onHand']), numeric: true, maxLines: 1),
                        _cell(t, Fmt.number(r['backOrder']), numeric: true, maxLines: 1),
                        _cell(t, Fmt.number(r['safetyStock']), numeric: true, maxLines: 1),
                        _cell(t, Fmt.number(r['leadTimeDemand']), numeric: true, maxLines: 1),
                        _cell(t, Fmt.number(r['rop']), numeric: true, maxLines: 1, bold: true),
                        _cell(t, Fmt.number(r['forecast']), numeric: true, maxLines: 1),
                        _cell(t, Fmt.money(r['avgNetCost']), numeric: true, maxLines: 1),
                      ]),
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

  // ── Table plumbing ──────────────────────────────────────────────────

  Widget _exportButton(BiTokens t, VoidCallback? onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: t.gridline)),
          child: Text('Export CSV',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: onTap == null ? t.textMuted : t.textPrimary)),
        ),
      );

  Widget _sortHeader(BiTokens t, String key, String label, bool numeric) {
    final sorted = _sortBy == key;
    return InkWell(
      onTap: () => _sortDetail(key),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.gridline))),
        child: Row(
          mainAxisAlignment: numeric ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Flexible(
              child: Text(label.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: numeric ? TextAlign.right : TextAlign.left,
                  style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w600,
                      color: sorted ? t.brand : t.textMuted)),
            ),
            if (sorted) Icon(_sortDir == 'asc' ? Icons.arrow_upward : Icons.arrow_downward, size: 11, color: t.brand),
          ],
        ),
      ),
    );
  }

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
