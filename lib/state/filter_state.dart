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

  FilterState() {
    // Dated modules start on the year to date.
    for (final m in const ['sales', 'accrued']) {
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

  /// Count of active narrowings for the module's badge (dimensions + flags;
  /// the always-present date range is not counted).
  int activeCount(String module) {
    final dims = _dims[module]?.values.fold<int>(0, (s, l) => s + l.length) ?? 0;
    return dims + (excludeReturnsOf(module) ? 1 : 0);
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
    return out;
  }

  void reset(String module) {
    if (hasDate(module)) {
      _dateFrom[module] = defaultFrom();
      _dateTo[module] = defaultTo();
    }
    _dims[module]?.updateAll((_, _) => []);
    if (module == 'sales') _excludeReturns = false;
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
