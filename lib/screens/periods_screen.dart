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

/// Period reports — year-on-year, quarter-on-quarter and month-on-month
/// comparison of net sales, derived server-side from one monthly aggregate.
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
  String _mode = 'yoy';

  static const _modes = {'yoy': 'Year on year', 'qoq': 'Quarter on quarter', 'mom': 'Month on month'};

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
    try {
      final res = await api.post('/api/sales/comparison', {'filters': _filters.payload('periods'), 'mode': _mode});
      if (!mounted) return;
      setState(() {
        _rows = (res as Map)['rows'] as List? ?? [];
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Period reports'),
        actions: [FilterButton(count: filters.activeCount('periods'), onTap: () => showFilterSheet(context, FilterModule.periods))],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (_error != null) ErrorBanner(_error!),
            ChipChooser<String>(
              options: _modes,
              value: _mode,
              onChanged: (m) {
                setState(() => _mode = m);
                _load();
              },
            ),
            const SizedBox(height: 16),
            BiChartCard(
              title: 'Net sales by period',
              subtitle: _mode == 'yoy'
                  ? 'Prior year trimmed to the same elapsed months for a fair read'
                  : 'Each period against the one before it',
              bars: _rows
                  .map((r) => BarDatum(
                        (r['label'] ?? '—').toString(),
                        ((r['current'] as Map?)?['sales'] as num?)?.toDouble() ?? 0,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            _table(t),
          ],
        ),
      ),
    );
  }

  Widget _table(BiTokens t) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Growth detail', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.textPrimary)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(flex: 3, child: _h(t, 'Period')),
            Expanded(flex: 4, child: _h(t, 'Net sales', end: true)),
            Expanded(flex: 3, child: _h(t, 'Growth', end: true)),
          ]),
          const SizedBox(height: 4),
          Divider(height: 1, color: t.gridline),
          if (_rows.isEmpty && !_loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('No periods to compare', style: TextStyle(color: t.textMuted, fontSize: 12)),
            ),
          for (final r in _rows) _tr(t, r as Map),
        ]),
      ),
    );
  }

  Widget _h(BiTokens t, String s, {bool end = false}) => Text(
        s,
        textAlign: end ? TextAlign.end : TextAlign.start,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: t.textMuted),
      );

  Widget _tr(BiTokens t, Map r) {
    final sales = (r['current'] as Map?)?['sales'];
    final g = (r['growth'] as Map?)?['sales'];
    final gv = g == null ? null : (g as num).toDouble();
    final color = gv == null ? t.textMuted : (gv >= 0 ? t.deltaUp : AppColors.deltaDown);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(children: [
        Expanded(flex: 3, child: Text((r['label'] ?? '—').toString(), style: TextStyle(fontSize: 13, color: t.textPrimary))),
        Expanded(flex: 4, child: Text(Fmt.money(sales), textAlign: TextAlign.end, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.textPrimary))),
        Expanded(
          flex: 3,
          child: Text(Fmt.delta(gv), textAlign: TextAlign.end, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ),
      ]),
    );
  }
}
