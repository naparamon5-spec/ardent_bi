import 'dart:convert';
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
  final bool hasExcludeCreditMemos;
  final bool hasToOrderOnly;
  final bool hasStockAge;
  final bool hasSearch;
  final bool hasMonths;
  final Map<String, String> dimensions; // dimensionKey -> label (primary filter-by)
  final Map<String, String>? advancedDimensions; // dimensionKey -> label (advanced filters)

  const FilterModule({
    required this.key,
    required this.optionsBase,
    required this.dimensions,
    this.advancedDimensions,
    this.hasDate = false,
    this.hasExcludeReturns = false,
    this.hasExcludeCreditMemos = false,
    this.hasToOrderOnly = false,
    this.hasStockAge = false,
    this.hasSearch = false,
    this.hasMonths = false,
  });

  static const sales = FilterModule(
    key: 'sales',
    optionsBase: '/api/sales/options/',
    hasDate: true,
    hasExcludeCreditMemos: true,
    hasSearch: true,
    hasMonths: true,
    dimensions: {
      'brand': 'Brand',
      'salesman': 'Salesman',
      'customer': 'Customer',
      'productManager': 'Product Manager',
    },
    advancedDimensions: {
      'productGroup': 'Product Group',
      'className': 'Class',
      'businessUnit': 'Business Unit',
      'salesGroup': 'Sales Group',
      'category': 'Category',
      'customerGroup': 'Customer Group',
      'transactionType': 'Transaction Type',
    },
  );

  static const inventory = FilterModule(
    key: 'inventory',
    optionsBase: '/api/inventory/options/',
    hasStockAge: true,
    dimensions: {
      'productManager': 'Product Manager',
      'productGroup': 'Product Group',
      'brand': 'Brand',
      'businessUnit': 'Business Unit',
      'warehouse': 'Warehouse',
    },
    // Item is a free-text search, not a dimension dropdown.
  );

  static const reorder = FilterModule(
    key: 'reorder',
    optionsBase: '/api/reorder-point/options/',
    hasToOrderOnly: true,
    dimensions: {
      'brand': 'Brand',
      'productGroup': 'Product Group',
      'instruction': 'Ordering Instruction',
    },
    // Item is a free-text search, not a dimension dropdown.
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

  // Period reports carry date range (year-on-year comparison uses full year).
  static const periods = FilterModule(
    key: 'periods',
    optionsBase: '/api/sales/options/',
    hasDate: true,
    hasExcludeCreditMemos: true,
    hasSearch: true,
    hasMonths: true,
    dimensions: {
      'brand': 'Brand',
      'salesman': 'Salesman',
      'customer': 'Customer',
      'productManager': 'Product Manager',
    },
    advancedDimensions: {
      'productGroup': 'Product Group',
      'className': 'Class',
      'businessUnit': 'Business Unit',
      'salesGroup': 'Sales Group',
      'category': 'Category',
      'customerGroup': 'Customer Group',
      'transactionType': 'Transaction Type',
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

class _FilterSheet extends StatefulWidget {
  final FilterModule module;
  const _FilterSheet({required this.module});
  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  bool _showAdvanced = false;
  late TextEditingController _searchController;
  late TextEditingController _saveViewController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _saveViewController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sync controllers with filter state on every rebuild.
    final filters = context.read<FilterState>();
    final currentSearch = filters.searchQueryOf(widget.module.key) ?? '';
    if (_searchController.text != currentSearch) _searchController.text = currentSearch;
    final currentSave = filters.savedViewNameOf(widget.module.key) ?? '';
    if (_saveViewController.text != currentSave) _saveViewController.text = currentSave;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _saveViewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    final filters = context.watch<FilterState>();

    Future<void> pickDate(bool isFrom) async {
      final current = DateTime.tryParse(isFrom ? filters.dateFromOf(widget.module.key) : filters.dateToOf(widget.module.key)) ?? DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: current,
        firstDate: DateTime(2015),
        lastDate: DateTime(DateTime.now().year + 1, 12, 31),
      );
      if (picked != null) {
        final iso = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
        filters.setDateRangeOf(
          widget.module.key,
          isFrom ? iso : filters.dateFromOf(widget.module.key),
          isFrom ? filters.dateToOf(widget.module.key) : iso,
        );
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.critical.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.filter_alt, color: AppColors.critical, size: 20),
            ),
            const SizedBox(width: 10),
            Text('Advanced Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: t.textPrimary)),
            const Spacer(),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
          ]),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              // ─ PERIOD section ───────────────────────────────────────
              if (widget.module.hasDate) ...[
                _label(t, 'PERIOD'),
                const SizedBox(height: 8),
                // Range dropdown
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: t.gridline),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(fontSize: 13, color: t.textPrimary),
                          children: [
                            TextSpan(text: 'RANGE  ', style: TextStyle(fontWeight: FontWeight.w600, color: t.textMuted)),
                            const TextSpan(text: 'Custom'),
                          ],
                        ),
                      ),
                    ),
                    Icon(Icons.expand_more, size: 18, color: t.textMuted),
                  ]),
                ),
                // From / To date fields
                Row(children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => pickDate(true),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: t.gridline),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(children: [
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(fontSize: 13, color: t.textPrimary),
                                children: [
                                  TextSpan(text: 'FROM  ', style: TextStyle(fontWeight: FontWeight.w600, color: t.textMuted)),
                                  TextSpan(text: filters.dateFromOf(widget.module.key)),
                                ],
                              ),
                            ),
                          ),
                          Icon(Icons.calendar_today_outlined, size: 16, color: t.textMuted),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () => pickDate(false),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: t.gridline),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(children: [
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(fontSize: 13, color: t.textPrimary),
                                children: [
                                  TextSpan(text: 'TO  ', style: TextStyle(fontWeight: FontWeight.w600, color: t.textMuted)),
                                  TextSpan(text: filters.dateToOf(widget.module.key)),
                                ],
                              ),
                            ),
                          ),
                          Icon(Icons.calendar_today_outlined, size: 16, color: t.textMuted),
                        ]),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                // Year + Quarter row
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _label(t, 'YEAR'),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(border: Border.all(color: t.gridline), borderRadius: BorderRadius.circular(10)),
                        child: Row(children: [
                          for (var i = 0; i < 4; i++)
                            Expanded(
                              child: InkWell(
                                onTap: () {},
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      right: i < 3 ? BorderSide(color: t.gridline) : BorderSide.none,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text('${DateTime.now().year - i}',
                                      style: TextStyle(fontSize: 13, color: t.textPrimary)),
                                ),
                              ),
                            ),
                        ]),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _label(t, 'QUARTER'),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(border: Border.all(color: t.gridline), borderRadius: BorderRadius.circular(10)),
                        child: Row(children: [
                          for (var i = 0; i < 4; i++)
                            Expanded(
                              child: InkWell(
                                onTap: () {},
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      right: i < 3 ? BorderSide(color: t.gridline) : BorderSide.none,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text('Q${i + 1}',
                                      style: TextStyle(fontSize: 13, color: t.textPrimary)),
                                ),
                              ),
                            ),
                        ]),
                      ),
                    ]),
                  ),
                ]),
                const Divider(height: 32),
              ],
              // ── FILTER BY section ──────────────────────────────────
              // To order only full-width toggle (reorder screen, at top)
              if (widget.module.hasToOrderOnly) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => filters.setToOrderOnlyOf(widget.module.key, !filters.toOrderOnlyOf(widget.module.key)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: filters.toOrderOnlyOf(widget.module.key) ? AppColors.critical : t.gridline),
                      backgroundColor: filters.toOrderOnlyOf(widget.module.key) ? AppColors.critical.withValues(alpha: 0.10) : null,
                    ),
                    child: Text('To order only',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: filters.toOrderOnlyOf(widget.module.key) ? AppColors.critical : t.textPrimary,
                        )),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _label(t, 'FILTER BY'),
              const SizedBox(height: 4),
              for (final e in widget.module.dimensions.entries)
                _DimensionDropdown(
                  module: widget.module,
                  dimension: e.key,
                  label: e.value,
                ),
              // ITEM single-row text input for inventory and reorder
              if (widget.module.key == 'inventory' || widget.module.key == 'reorder') ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: t.gridline),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    Text('ITEM', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: t.textMuted)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: widget.module.key == 'inventory' ? 'Code or description...' : 'SKU or description...',
                          hintStyle: TextStyle(fontSize: 13, color: t.textMuted),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: TextStyle(fontSize: 13, color: t.textPrimary),
                        onSubmitted: (v) => filters.setSearchQueryOf(widget.module.key, v.trim().isEmpty ? null : v.trim()),
                      ),
                    ),
                  ]),
                ),
              ],
              // Stock age selector (inventory screen) — always visible, segmented buttons
              if (widget.module.hasStockAge) ...[
                const SizedBox(height: 16),
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  _label(t, 'STOCK AGE'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(border: Border.all(color: t.gridline), borderRadius: BorderRadius.circular(10)),
                      child: Row(children: [
                        for (var i = 0; i < 4; i++)
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                final ages = [null, 90, 180, 365];
                                filters.setStockAgeDaysOf(widget.module.key, ages[i]);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: filters.stockAgeDaysOf(widget.module.key) == [null, 90, 180, 365][i]
                                      ? AppColors.critical.withValues(alpha: 0.85)
                                      : Colors.transparent,
                                  border: Border(
                                    right: i < 3 ? BorderSide(color: t.gridline) : BorderSide.none,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  ['All ages', 'Over 90 days', 'Over 180 days', 'Over a year'][i],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: filters.stockAgeDaysOf(widget.module.key) == [null, 90, 180, 365][i]
                                        ? Colors.white
                                        : t.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ]),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => filters.setExcludeCreditMemosOf(widget.module.key, !filters.excludeCreditMemosOf(widget.module.key)),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      SizedBox(
                        height: 20,
                        width: 20,
                        child: Checkbox(
                          value: filters.excludeCreditMemosOf(widget.module.key),
                          onChanged: (v) => filters.setExcludeCreditMemosOf(widget.module.key, v ?? false),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('Exclude zero-cost items', style: TextStyle(fontSize: 14, color: t.textPrimary)),
                    ]),
                  ),
                ),
                // "Why no date filter?" explanatory text for inventory
                if (widget.module.key == 'inventory') ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: t.elevated,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 16, color: t.textMuted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Inventory is tracked by current stock levels, not by transaction dates. Use Stock Age to focus on older inventory.',
                            style: TextStyle(fontSize: 12, color: t.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              // More/Fewer filters toggle
              if (widget.module.advancedDimensions != null && widget.module.advancedDimensions!.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => setState(() => _showAdvanced = !_showAdvanced),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: Text(_showAdvanced ? 'Fewer filters' : 'More filters',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.textPrimary)),
                  ),
                ),
              ],
              // ─ Advanced content (only visible when expanded) ───────
              if (_showAdvanced) ...[
                const SizedBox(height: 16),
                // Advanced dimension dropdowns
                if (widget.module.advancedDimensions != null)
                  for (final e in widget.module.advancedDimensions!.entries)
                    _DimensionDropdown(
                      module: widget.module,
                      dimension: e.key,
                      label: e.value,
                    ),
                // Search field
                if (widget.module.hasSearch) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: t.gridline),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      Icon(Icons.search, size: 18, color: t.textMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Customer, item or invoice...',
                            hintStyle: TextStyle(fontSize: 13, color: t.textMuted),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: TextStyle(fontSize: 13, color: t.textPrimary),
                          onSubmitted: (v) => filters.setSearchQueryOf(widget.module.key, v.trim()),
                        ),
                      ),
                    ]),
                  ),
                ],
                // Exclude credit memos checkbox (sales/periods)
                if (widget.module.hasExcludeCreditMemos) ...[
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () => filters.setExcludeCreditMemosOf(widget.module.key, !filters.excludeCreditMemosOf(widget.module.key)),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        SizedBox(
                          height: 20,
                          width: 20,
                          child: Checkbox(
                            value: filters.excludeCreditMemosOf(widget.module.key),
                            onChanged: (v) => filters.setExcludeCreditMemosOf(widget.module.key, v ?? false),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('Exclude credit memos and adjustments',
                            style: TextStyle(fontSize: 14, color: t.textPrimary)),
                      ]),
                    ),
                  ),
                ],
                // Month chips in bordered container (sales/periods)
                if (widget.module.hasMonths) ...[
                  const SizedBox(height: 16),
                  _label(t, 'MONTH'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(border: Border.all(color: t.gridline), borderRadius: BorderRadius.circular(10)),
                    child: Wrap(
                      spacing: 0,
                      runSpacing: 0,
                      children: [
                        for (var i = 0; i < 12; i++)
                          _MonthChip(
                            label: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][i],
                            selected: (filters.monthsOf(widget.module.key) ?? []).contains(
                                ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][i]),
                            isFirst: i == 0,
                            isLast: i == 11,
                            isRowEnd: (i + 1) % 10 == 0,
                            onTap: () {
                              final m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][i];
                              final current = List<String>.from(filters.monthsOf(widget.module.key) ?? []);
                              if (current.contains(m)) {
                                current.remove(m);
                              } else {
                                current.add(m);
                              }
                              filters.setMonthsOf(widget.module.key, current.isEmpty ? null : current);
                            },
                          ),
                      ],
                    ),
                  ),
                ],
                // Save this filter set
                const SizedBox(height: 20),
                _label(t, 'SAVE THIS FILTER SET'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: t.gridline),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: _saveViewController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Cisco — Visayas, YTD',
                      hintStyle: TextStyle(fontSize: 13, color: t.textMuted),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    style: TextStyle(fontSize: 13, color: t.textPrimary),
                    onSubmitted: (v) => filters.setSavedViewNameOf(widget.module.key, v.trim().isEmpty ? null : v.trim()),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: () {
                      filters.setSavedViewNameOf(widget.module.key, _saveViewController.text.trim().isEmpty ? null : _saveViewController.text.trim());
                      Navigator.pop(context);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.critical.withValues(alpha: 0.7),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Save view', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // Reset all filters at bottom
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton(
                  onPressed: () => filters.reset(widget.module.key),
                  style: OutlinedButton.styleFrom(foregroundColor: t.textSecondary),
                  child: const Text('Reset all filters', style: TextStyle(fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _label(BiTokens t, String s) => Text(s.toUpperCase(),
      style: TextStyle(fontSize: 10.5, letterSpacing: 0.5, fontWeight: FontWeight.w600, color: t.textMuted));
}

/// Dropdown-style dimension selector matching the reference UI.
class _DimensionDropdown extends StatelessWidget {
  final FilterModule module;
  final String dimension, label;
  const _DimensionDropdown({required this.module, required this.dimension, required this.label});

  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    final filters = context.watch<FilterState>();
    final selected = filters.dim(module.key, dimension);
    final displayText = selected.isEmpty ? 'All' : '${selected.length} selected';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: t.gridline),
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: () async {
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
        child: Row(children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 13, color: t.textPrimary),
                children: [
                  TextSpan(text: '${label.toUpperCase()}  ', style: TextStyle(fontWeight: FontWeight.w600, color: t.textMuted)),
                  TextSpan(text: displayText, style: TextStyle(color: selected.isEmpty ? t.textMuted : t.brand)),
                ],
              ),
            ),
          ),
          Icon(Icons.expand_more, size: 18, color: t.textMuted),
        ]),
      ),
    );
  }
}

/// Month chip inside the bordered month container.
class _MonthChip extends StatelessWidget {
  final String label;
  final bool selected, isFirst, isLast, isRowEnd;
  final VoidCallback onTap;
  const _MonthChip({
    required this.label,
    required this.selected,
    required this.isFirst,
    required this.isLast,
    required this.isRowEnd,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border(
            right: isRowEnd || isLast ? BorderSide.none : BorderSide(color: t.gridline),
            bottom: isLast ? BorderSide.none : BorderSide(color: t.gridline),
          ),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? t.brand : t.textPrimary,
            )),
      ),
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
  final Set<Map<String, dynamic>> _chosen = {};
  List<Map<String, dynamic>> _options = [];
  bool _loading = true;
  String? _error;
  String _search = '';

  @override
  void initState() {
    super.initState();
    // Convert initial string values to maps for consistency
    for (final v in widget.initial) {
      _chosen.add({'value': v, 'label': v});
    }
    _load();
  }

  String _formatAmount(num amount) {
    if (amount.abs() >= 1e9) {
      return '₱${(amount / 1e9).toStringAsFixed(1)}B';
    } else if (amount.abs() >= 1e6) {
      return '₱${(amount / 1e6).toStringAsFixed(1)}M';
    } else if (amount.abs() >= 1e3) {
      return '₱${(amount / 1e3).toStringAsFixed(1)}K';
    }
    return '₱${amount.toStringAsFixed(0)}';
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
      
      // Backend expects GET with query parameter 'f' containing filters as JSON
      final filtersJson = Uri.encodeComponent(jsonEncode(f));
      final searchParam = _search.isNotEmpty ? '&search=${Uri.encodeComponent(_search)}' : '';
      final path = '${widget.optionsBase}${widget.dimension}?f=$filtersJson$searchParam';
      
      final res = await auth.client.get(path);
      final values = (res['values'] as List?) ?? const [];
      setState(() {
        _options = values.map((e) {
          if (e is Map) {
            // Backend returned an object with value/label/amount
            return Map<String, dynamic>.from(e);
          } else if (e is String) {
            // Backend returned a simple string - wrap it
            return {'value': e, 'label': e};
          }
          // Fallback for any other type
          return {'value': e.toString(), 'label': e.toString()};
        }).toList();
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
                  : ListView.builder(
                      itemCount: _options.length,
                      itemBuilder: (_, i) {
                        final opt = _options[i];
                        final label = opt['label']?.toString() ?? opt['value']?.toString() ?? opt.toString();
                        final amount = opt['amount'];
                        final amountStr = amount is num ? _formatAmount(amount) : '';
                        
                        return InkWell(
                          onTap: () => setState(() {
                            _chosen.contains(opt) ? _chosen.remove(opt) : _chosen.add(opt);
                          }),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Checkbox(
                                    value: _chosen.contains(opt),
                                    onChanged: (_) => setState(() {
                                      _chosen.contains(opt) ? _chosen.remove(opt) : _chosen.add(opt);
                                    }),
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(label,
                                      style: TextStyle(fontSize: 13, color: t.textPrimary)),
                                ),
                                if (amountStr.isNotEmpty)
                                  Text(amountStr,
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.textSecondary)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final values = _chosen.map((m) => m['value']?.toString() ?? m['label']?.toString() ?? '').toList();
                  Navigator.pop(context, values);
                },
                child: Text('Apply (${_chosen.length})'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
