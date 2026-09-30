import 'package:flutter/foundation.dart';

String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Every dated module opens on the year to date: 1 Jan of the current year →
/// today. A calendar year holds still and lines up with the year-on-year panels.
String defaultFrom() => _iso(DateTime(DateTime.now().year, 1, 1));
String defaultTo() => _iso(DateTime.now());

/// Filter state for every module, the mobile counterpart of the parts of
/// `web/app/stores/filters.js` the app uses. Storage is keyed by module
/// ('sales', 'inventory', 'reorder', 'accrued', 'periods') so one generic
/// filter sheet drives them all. Payload getters strip empties and sort arrays
/// so the server-side cache key stays stable — matching the web.
class FilterState extends ChangeNotifier {
  final Map<String, Map<String, List<String>>> _dims = {};
  final Map<String, String> _dateFrom = {};
  final Map<String, String> _dateTo = {};
  bool _excludeReturns = false;
  bool _excludeCreditMemos = false;
  bool _toOrderOnly = false;
  int? _stockAgeDays;
  String? _searchQuery;
  List<String>? _months;
  String? _savedViewName;

  FilterState() {
    // Dated modules start on the year to date.
    for (final m in const ['sales', 'accrued', 'periods']) {
      _dateFrom[m] = defaultFrom();
      _dateTo[m] = defaultTo();
    }
  }

  // ── Generic, module-driven API ─────────────────────────────────────
  List<String> dim(String module, String key) => _dims[module]?[key] ?? const [];

  void toggleDim(String module, String key, String value) {
    final map = _dims.putIfAbsent(module, () => {});
    final list = map.putIfAbsent(key, () => []);
    list.contains(value) ? list.remove(value) : list.add(value);
    notifyListeners();
  }

  void setDim(String module, String key, List<String> values) {
    final map = _dims.putIfAbsent(module, () => {});
    map[key] = List.of(values);
    notifyListeners();
  }

  bool hasDate(String module) => _dateFrom.containsKey(module);
  String dateFromOf(String module) => _dateFrom[module] ?? defaultFrom();
  String dateToOf(String module) => _dateTo[module] ?? defaultTo();

  void setDateRangeOf(String module, String from, String to) {
    _dateFrom[module] = from;
    _dateTo[module] = to;
    notifyListeners();
  }

  bool excludeReturnsOf(String module) => module == 'sales' && _excludeReturns;
  void setExcludeReturnsOf(String module, bool v) {
    if (module == 'sales') {
      _excludeReturns = v;
      notifyListeners();
    }
  }

  bool excludeCreditMemosOf(String module) => _excludeCreditMemos;
  void setExcludeCreditMemosOf(String module, bool v) {
    _excludeCreditMemos = v;
    notifyListeners();
  }

  bool toOrderOnlyOf(String module) => module == 'reorder' && _toOrderOnly;
  void setToOrderOnlyOf(String module, bool v) {
    if (module == 'reorder') {
      _toOrderOnly = v;
      notifyListeners();
    }
  }

  int? stockAgeDaysOf(String module) => module == 'inventory' ? _stockAgeDays : null;
  void setStockAgeDaysOf(String module, int? days) {
    if (module == 'inventory') {
      _stockAgeDays = days;
      notifyListeners();
    }
  }

  String? searchQueryOf(String module) => _searchQuery;
  void setSearchQueryOf(String module, String? query) {
    _searchQuery = query?.isEmpty == true ? null : query;
    notifyListeners();
  }

  List<String>? monthsOf(String module) => _months;
  void setMonthsOf(String module, List<String>? months) {
    _months = months;
    notifyListeners();
  }

  String? savedViewNameOf(String module) => _savedViewName;
  void setSavedViewNameOf(String module, String? name) {
    _savedViewName = name;
    notifyListeners();
  }

  /// Count of active narrowings for the module's badge (dimensions + flags;
  /// the always-present date range is not counted).
  int activeCount(String module) {
    final dims = _dims[module]?.values.fold<int>(0, (s, l) => s + l.length) ?? 0;
    var count = dims;
    if (excludeReturnsOf(module)) count++;
    if (excludeCreditMemosOf(module)) count++;
    if (toOrderOnlyOf(module)) count++;
    if (_stockAgeDays != null) count++;
    if (_searchQuery != null) count++;
    if (_months != null && _months!.isNotEmpty) count++;
    return count;
  }

  Map<String, dynamic> payload(String module) {
    final out = <String, dynamic>{};
    if (hasDate(module)) {
      out['dateFrom'] = dateFromOf(module);
      out['dateTo'] = dateToOf(module);
    }
    _dims[module]?.forEach((k, v) {
      if (v.isNotEmpty) out[k] = (List.of(v)..sort());
    });
    if (excludeReturnsOf(module)) out['excludeReturns'] = true;
    if (excludeCreditMemosOf(module)) out['excludeCreditMemos'] = true;
    if (toOrderOnlyOf(module)) out['toOrderOnly'] = true;
    if (_stockAgeDays != null) out['stockAgeDays'] = _stockAgeDays;
    if (_searchQuery != null) out['search'] = _searchQuery;
    if (_months != null && _months!.isNotEmpty) out['months'] = _months;
    if (_savedViewName != null) out['savedView'] = _savedViewName;
    return out;
  }

  void reset(String module) {
    if (hasDate(module)) {
      _dateFrom[module] = defaultFrom();
      _dateTo[module] = defaultTo();
    }
    _dims[module]?.updateAll((_, _) => []);
    if (module == 'sales') _excludeReturns = false;
    _excludeCreditMemos = false;
    _toOrderOnly = false;
    _stockAgeDays = null;
    _searchQuery = null;
    _months = null;
    _savedViewName = null;
    notifyListeners();
  }

  // ── Back-compatible convenience wrappers (sales / inventory) ───────
  String get dateFrom => dateFromOf('sales');
  String get dateTo => dateToOf('sales');
  bool get excludeReturns => _excludeReturns;

  List<String> sales(String key) => dim('sales', key);
  List<String> inventory(String key) => dim('inventory', key);

  int get activeSalesCount => activeCount('sales');
  int get activeInventoryCount => activeCount('inventory');

  void toggleSales(String key, String value) => toggleDim('sales', key, value);
  void setSales(String key, List<String> values) => setDim('sales', key, values);
  void toggleInventory(String key, String value) => toggleDim('inventory', key, value);
  void setInventory(String key, List<String> values) => setDim('inventory', key, values);

  void setDateRange(String from, String to) => setDateRangeOf('sales', from, to);
  void setExcludeReturns(bool v) => setExcludeReturnsOf('sales', v);
  void resetSales() => reset('sales');
  void resetInventory() => reset('inventory');

  Map<String, dynamic> get salesPayload => payload('sales');
  Map<String, dynamic> get inventoryPayload => payload('inventory');
}
