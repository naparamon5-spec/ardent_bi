import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../state/auth_state.dart';
import '../state/filter_state.dart';
import '../theme.dart';

/// Describes the filters a module offers, so one sheet drives them all.
class FilterModule {
  final String key; // matches FilterState module + used for options endpoint
  final String optionsBase; // e.g. '/api/sales/options/'
  final bool hasDate;
  final bool hasExcludeReturns;
  final Map<String, String> dimensions; // dimensionKey -> label

  const FilterModule({
    required this.key,
    required this.optionsBase,
    required this.dimensions,
    this.hasDate = false,
    this.hasExcludeReturns = false,
  });

  static const sales = FilterModule(
    key: 'sales',
    optionsBase: '/api/sales/options/',
    hasDate: true,
    hasExcludeReturns: true,
    dimensions: {
      'brand': 'Brand',
      'salesman': 'Salesman',
      'customer': 'Customer',
      'productGroup': 'Product group',
      'productManager': 'Product manager',
      'salesGroup': 'Sales group',
    },
  );

  static const inventory = FilterModule(
    key: 'inventory',
    optionsBase: '/api/inventory/options/',
    dimensions: {
      'brand': 'Brand',
      'productManager': 'Product manager',
      'productGroup': 'Product group',
      'warehouse': 'Warehouse',
    },
  );

  static const reorder = FilterModule(
    key: 'reorder',
    optionsBase: '/api/reorder-point/options/',
    dimensions: {
      'brand': 'Brand',
      'productManager': 'Product manager',
      'productGroup': 'Product group',
    },
  );

  static const accrued = FilterModule(
    key: 'accrued',
    optionsBase: '/api/accrued/options/',
    hasDate: true,
    dimensions: {
      'brand': 'Brand',
      'customer': 'Customer',
      'salesman': 'Salesman',
      'type': 'Charge type',
    },
  );

  // Period reports carry no date range on purpose: a within-year window would
  // collapse a year-on-year comparison to a single year.
  static const periods = FilterModule(
    key: 'periods',
    optionsBase: '/api/sales/options/',
    dimensions: {
      'brand': 'Brand',
      'salesman': 'Salesman',
      'customer': 'Customer',
      'productGroup': 'Product group',
      'productManager': 'Product manager',
    },
  );
}

/// Opens the filter sheet for [module].
Future<void> showFilterSheet(BuildContext context, FilterModule module) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.9,
      child: _FilterSheet(module: module),
    ),
  );
}

/// Back-compatible helper used by Overview and Sales.
Future<void> showSalesFilterSheet(BuildContext context) =>
    showFilterSheet(context, FilterModule.sales);

class _FilterSheet extends StatelessWidget {
  final FilterModule module;
  const _FilterSheet({required this.module});

  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    final filters = context.watch<FilterState>();

    Future<void> pickDate(bool isFrom) async {
      final current = DateTime.tryParse(isFrom ? filters.dateFromOf(module.key) : filters.dateToOf(module.key)) ?? DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: current,
        firstDate: DateTime(2015),
        lastDate: DateTime(DateTime.now().year + 1, 12, 31),
      );
      if (picked != null) {
        final iso = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
        filters.setDateRangeOf(
          module.key,
          isFrom ? iso : filters.dateFromOf(module.key),
          isFrom ? filters.dateToOf(module.key) : iso,
        );
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
          child: Row(children: [
            Text('Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: t.textPrimary)),
            const Spacer(),
            TextButton(onPressed: () => filters.reset(module.key), child: const Text('Reset')),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
          ]),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              if (module.hasDate) ...[
                _label(t, 'DATE RANGE'),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _DateField(label: 'From', value: filters.dateFromOf(module.key), onTap: () => pickDate(true))),
                  const SizedBox(width: 10),
                  Expanded(child: _DateField(label: 'To', value: filters.dateToOf(module.key), onTap: () => pickDate(false))),
                ]),
                const SizedBox(height: 8),
              ],
              if (module.hasExcludeReturns)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Exclude returns', style: TextStyle(fontSize: 13, color: t.textPrimary)),
                  value: filters.excludeReturnsOf(module.key),
                  onChanged: (v) => filters.setExcludeReturnsOf(module.key, v),
                ),
              if (module.hasDate || module.hasExcludeReturns) const Divider(height: 24),
              _label(t, 'DIMENSIONS'),
              const SizedBox(height: 4),
              for (final e in module.dimensions.entries)
                _DimensionTile(
                  module: module,
                  dimension: e.key,
                  label: e.value,
                  selected: filters.dim(module.key, e.key),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Show results (${filters.activeCount(module.key)} active)'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _label(BiTokens t, String s) => Text(s,
      style: TextStyle(fontSize: 10.5, letterSpacing: 0.5, fontWeight: FontWeight.w600, color: t.textMuted));
}

class _DateField extends StatelessWidget {
  final String label, value;
  final VoidCallback onTap;
  const _DateField({required this.label, required this.value, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, isDense: true),
        child: Text(value, style: TextStyle(fontSize: 13, color: t.textPrimary)),
      ),
    );
  }
}

class _DimensionTile extends StatelessWidget {
  final FilterModule module;
  final String dimension, label;
  final List<String> selected;
  const _DimensionTile({required this.module, required this.dimension, required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: TextStyle(fontSize: 14, color: t.textPrimary)),
      subtitle: selected.isEmpty
          ? Text('All', style: TextStyle(fontSize: 12, color: t.textMuted))
          : Text(selected.join(', '),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: t.brand)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (selected.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: t.brandSoft, borderRadius: BorderRadius.circular(10)),
            child: Text('${selected.length}',
                style: TextStyle(color: t.brand, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        const Icon(Icons.chevron_right),
      ]),
      onTap: () async {
        final filters = context.read<FilterState>();
        final cascade = filters.payload(module.key);
        final picked = await showModalBottomSheet<List<String>>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => FractionallySizedBox(
            heightFactor: 0.85,
            child: _OptionsPicker(
              dimension: dimension,
              label: label,
              initial: selected,
              optionsBase: module.optionsBase,
              cascade: cascade,
            ),
          ),
        );
        if (picked != null && context.mounted) {
          context.read<FilterState>().setDim(module.key, dimension, picked);
        }
      },
    );
  }
}

/// Searchable multi-select that fetches options for one dimension from the API,
/// applying the other active filters as the cascade.
class _OptionsPicker extends StatefulWidget {
  final String dimension, label;
  final List<String> initial;
  final String optionsBase;
  final Map<String, dynamic> cascade;

  const _OptionsPicker({
    required this.dimension,
    required this.label,
    required this.initial,
    required this.optionsBase,
    required this.cascade,
  });
  @override
  State<_OptionsPicker> createState() => _OptionsPickerState();
}

class _OptionsPickerState extends State<_OptionsPicker> {
  final Set<String> _chosen = {};
  List<String> _options = [];
  bool _loading = true;
  String? _error;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _chosen.addAll(widget.initial);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthState>();
      // Cascade: send the other active filters (omit this dimension).
      final f = Map<String, dynamic>.from(widget.cascade)..remove(widget.dimension);
      final res = await auth.client.post('${widget.optionsBase}${widget.dimension}', {
        'filters': f,
        if (_search.isNotEmpty) 'search': _search,
      });
      final values = (res['values'] as List?) ?? const [];
      setState(() {
        _options = values.map((e) => e.toString()).toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
          child: Row(children: [
            Text(widget.label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: t.textPrimary)),
            const Spacer(),
            if (_chosen.isNotEmpty)
              TextButton(onPressed: () => setState(() => _chosen.clear()), child: const Text('Clear')),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search', isDense: true),
            onSubmitted: (v) {
              _search = v.trim();
              _load();
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!, style: TextStyle(color: AppColors.critical)))
                  : ListView(
                      children: [
                        for (final opt in _options)
                          CheckboxListTile(
                            dense: true,
                            value: _chosen.contains(opt),
                            title: Text(opt, style: TextStyle(fontSize: 13, color: t.textPrimary)),
                            onChanged: (_) => setState(() {
                              _chosen.contains(opt) ? _chosen.remove(opt) : _chosen.add(opt);
                            }),
                          ),
                        if (_options.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(child: Text('No options', style: TextStyle(color: t.textMuted))),
                          ),
                      ],
                    ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _chosen.toList()),
                child: Text('Apply (${_chosen.length})'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
