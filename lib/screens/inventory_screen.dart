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

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  late FilterState _filters;
  Timer? _debounce;

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _kpis;
  Map<String, dynamic>? _breakdown;

  String _dimension = 'brand';
  static const _dimensions = {
    'brand': 'Brand',
    'productManager': 'Prod. manager',
    'productGroup': 'Product group',
    'warehouse': 'Warehouse',
  };

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
    final body = {'filters': _filters.inventoryPayload};
    try {
      final results = await Future.wait([
        api.post('/api/inventory/kpis', body),
        api.post('/api/inventory/breakdown', {...body, 'dimension': _dimension, 'measure': 'value', 'limit': 15}),
      ]);
      if (!mounted) return;
      setState(() {
        _kpis = results[0] as Map<String, dynamic>;
        _breakdown = results[1] as Map<String, dynamic>;
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

  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    final filters = context.watch<FilterState>();
    final k = _kpis ?? const {};
    final ageing = (k['ageing'] as List?) ?? const [];
    final rows = (_breakdown?['rows'] as List?) ?? const [];
    final over90 = (k['over90Share'] as num?)?.toDouble() ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [FilterButton(count: filters.activeInventoryCount, onTap: () => showFilterSheet(context, FilterModule.inventory))],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            if (_error != null) ErrorBanner(_error!),
            KpiGrid(tiles: [
              KpiTile(label: 'Stock value', value: k['value'], format: 'currency', loading: _loading),
              KpiTile(label: 'SKUs on hand', value: k['skus'], format: 'number', loading: _loading),
              KpiTile(label: 'Aged over 90d', value: over90, format: 'percent', loading: _loading),
              KpiTile(label: 'Slow-moving', value: k['slowMovingShare'], format: 'percent', loading: _loading),
            ]),
            const SizedBox(height: 16),
            BiCard(
              title: 'Ageing profile',
              subtitle: 'Stock value by days on hand',
              child: _ageingBars(t, ageing),
            ),
            const SizedBox(height: 16),
            BiChartCard(
              title: 'Stock value breakdown',
              above: ChipChooser<String>(
                options: _dimensions,
                value: _dimension,
                onChanged: (dim) {
                  setState(() => _dimension = dim);
                  _load();
                },
              ),
              bars: rows
                  .map((r) => BarDatum((r['name'] ?? '—').toString(), (r['value'] as num?)?.toDouble() ?? 0))
                  .toList(),
            ),
            const SizedBox(height: 16),
            _deadStockCard(t, k),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _ageingBars(BiTokens t, List ageing) {
    if (ageing.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(child: Text('No ageing data', style: TextStyle(color: t.textMuted, fontSize: 12))),
      );
    }
    final maxV = ageing.fold<double>(0, (a, b) {
      final v = (b['value'] as num?)?.toDouble() ?? 0;
      return v > a ? v : a;
    });
    final denom = maxV == 0 ? 1.0 : maxV;
    return Column(
      children: [
        for (var i = 0; i < ageing.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text((ageing[i]['label'] ?? '').toString(),
                        style: TextStyle(fontSize: 12, color: t.textPrimary)),
                  ),
                  Text(Fmt.money(ageing[i]['value']),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.textSecondary)),
                ]),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(children: [
                    Container(height: 8, color: t.gridline),
                    FractionallySizedBox(
                      widthFactor: (((ageing[i]['value'] as num?)?.toDouble() ?? 0) / denom).clamp(0.001, 1.0),
                      child: Container(height: 8, color: t.ageing[i % t.ageing.length]),
                    ),
                  ]),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _deadStockCard(BiTokens t, Map k) {
    final dead = (k['deadStock'] as Map?) ?? const {};
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.critical.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.inventory_2_outlined, color: AppColors.critical, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Dead stock', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: t.textPrimary)),
              Text('${Fmt.number(dead['skus'] ?? 0)} SKUs with no recent movement',
                  style: TextStyle(fontSize: 11.5, color: t.textMuted)),
            ]),
          ),
          Text(Fmt.moneyShort(dead['value'] ?? 0),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.critical)),
        ]),
      ),
    );
  }
}
