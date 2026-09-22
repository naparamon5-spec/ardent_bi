import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../format.dart';
import '../state/auth_state.dart';
import '../state/filter_state.dart';
import '../theme.dart';
import '../widgets/bi_chart.dart';
import '../widgets/common.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/kpi_tile.dart';

/// Re-Order Point — what to order and how much. Gated to BU-head-and-above by
/// the API (and hidden from the menu otherwise).
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
  Map<String, dynamic>? _kpis;
  Map<String, dynamic>? _breakdown;
  List<dynamic> _detail = [];

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
    final body = {'filters': _filters.payload('reorder')};
    try {
      final results = await Future.wait([
        api.post('/api/reorder-point/kpis', body),
        api.post('/api/reorder-point/breakdown', {...body, 'dimension': 'brand', 'measure': 'forecast', 'limit': 12}),
        api.post('/api/reorder-point/detail', {...body, 'page': 1, 'pageSize': 25, 'sortBy': 'forecast', 'sortDir': 'desc'}),
      ]);
      if (!mounted) return;
      setState(() {
        _kpis = results[0] as Map<String, dynamic>;
        _breakdown = results[1] as Map<String, dynamic>;
        _detail = (results[2] as Map)['rows'] as List? ?? [];
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    final filters = context.watch<FilterState>();
    final k = _kpis ?? const {};
    final rows = (_breakdown?['rows'] as List?) ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Re-Order Point'),
        actions: [FilterButton(count: filters.activeCount('reorder'), onTap: () => showFilterSheet(context, FilterModule.reorder))],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (_error != null) ErrorBanner(_error!),
            KpiGrid(tiles: [
              KpiTile(label: 'Items to order', value: k['itemsToOrder'], format: 'number', loading: _loading, sub: '${Fmt.percent(k['toOrderShare'])} of catalogue'),
              KpiTile(label: 'Below ROP', value: k['belowRop'], format: 'number', loading: _loading, sub: Fmt.percent(k['belowRopShare'])),
              KpiTile(label: 'Order amount', value: k['amount'], format: 'currency', loading: _loading),
              KpiTile(label: 'Forecast qty', value: k['forecast'], format: 'number', loading: _loading),
            ]),
            if ((k['itemsWithoutCost'] ?? 0) != 0) ...[
              const SizedBox(height: 12),
              _noteBanner(t, '${Fmt.number(k['itemsWithoutCost'])} items to order have no cost on file, so their order amount reads as zero.'),
            ],
            const SizedBox(height: 16),
            BiChartCard(
              title: 'Forecast demand by brand',
              subtitle: 'Units to order over the forecast window',
              bars: rows.map((r) => BarDatum((r['name'] ?? '—').toString(), (r['forecast'] as num?)?.toDouble() ?? 0)).toList(),
              currency: false,
            ),
            const SizedBox(height: 16),
            _detailCard(t),
          ],
        ),
      ),
    );
  }

  Widget _detailCard(BiTokens t) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Items to order', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.textPrimary)),
          const SizedBox(height: 6),
          if (_detail.isEmpty && !_loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('Nothing to order right now', style: TextStyle(color: t.textMuted, fontSize: 12)),
            ),
          for (final r in _detail.take(25)) _row(t, r as Map),
        ]),
      ),
    );
  }

  Widget _row(BiTokens t, Map r) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text((r['itemDescription'] ?? r['item'] ?? '—').toString(),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.textPrimary)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: t.brand.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Text('Order ${Fmt.number(r['forecast'])}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: t.brand)),
            ),
          ]),
          const SizedBox(height: 2),
          Row(children: [
            Expanded(
              child: Text(
                '${r['brand'] ?? '—'} · on hand ${Fmt.number(r['onHand'])} · ROP ${Fmt.number(r['rop'])}',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: t.textMuted),
              ),
            ),
            Text(Fmt.money(r['orderAmount']), style: TextStyle(fontSize: 11, color: t.textSecondary)),
          ]),
          const SizedBox(height: 8),
          Divider(height: 1, color: t.gridline),
        ]),
      );

  Widget _noteBanner(BiTokens t, String msg) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(child: Text(msg, style: TextStyle(fontSize: 12, color: t.textSecondary))),
        ]),
      );
}
