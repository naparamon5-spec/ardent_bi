import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../state/auth_state.dart';
import '../state/filter_state.dart';
import '../widgets/bi_chart.dart';
import '../widgets/common.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/kpi_tile.dart';

/// Accrued Incidentals — charges booked against job orders. The headline is the
/// incidental rate (cost per peso of job-order value), not the raw total.
class AccruedScreen extends StatefulWidget {
  const AccruedScreen({super.key});
  @override
  State<AccruedScreen> createState() => _AccruedScreenState();
}

class _AccruedScreenState extends State<AccruedScreen> {
  late FilterState _filters;
  Timer? _debounce;

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _kpis;
  List<dynamic> _trend = [];
  Map<String, dynamic>? _breakdown;

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
    // Accrued filters on the job-order date; opens on the year to date.
    final body = {'filters': _filters.payload('accrued')};
    try {
      final results = await Future.wait([
        api.post('/api/accrued/kpis', body),
        api.post('/api/accrued/timeseries', body),
        api.post('/api/accrued/breakdown', {...body, 'dimension': 'brand', 'measure': 'amount', 'limit': 12}),
      ]);
      if (!mounted) return;
      setState(() {
        _kpis = results[0] as Map<String, dynamic>;
        _trend = (results[1] as Map)['points'] as List? ?? [];
        _breakdown = results[2] as Map<String, dynamic>;
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
    final filters = context.watch<FilterState>();
    final k = _kpis ?? const {};
    final rows = (_breakdown?['rows'] as List?) ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accrued Incidentals'),
        actions: [FilterButton(count: filters.activeCount('accrued'), onTap: () => showFilterSheet(context, FilterModule.accrued))],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (_error != null) ErrorBanner(_error!),
            KpiGrid(tiles: [
              KpiTile(label: 'Incidental cost', value: k['amount'], format: 'currency', loading: _loading),
              KpiTile(label: 'Incidental rate', value: k['incidentalRate'], format: 'percent', loading: _loading, sub: 'per ₱ of job-order value'),
              KpiTile(label: 'Job orders', value: k['jobOrders'], format: 'number', loading: _loading),
              KpiTile(label: 'Avg per job order', value: k['avgPerJobOrder'], format: 'currency', loading: _loading),
            ]),
            const SizedBox(height: 16),
            BiChartCard(
              title: 'Incidental cost by month',
              subtitle: 'Charges booked against job orders',
              categories: _trend.map((p) => (p['label'] ?? '').toString()).toList(),
              series: [SeriesSpec('Incidental cost', _trend.map((p) => (p['amount'] as num?)?.toDouble() ?? 0).toList())],
              height: 220,
            ),
            const SizedBox(height: 16),
            BiChartCard(
              title: 'Incidental cost by brand',
              bars: rows.map((r) => BarDatum((r['name'] ?? '—').toString(), (r['amount'] as num?)?.toDouble() ?? 0)).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
