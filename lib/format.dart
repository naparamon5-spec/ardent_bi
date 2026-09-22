import 'package:intl/intl.dart';

/// Locale-aware formatting, mirroring `web/app/composables/useFormat.js` so the
/// mobile figures agree with the web's tiles, axes and tables. Currency is
/// expressed in millions from ₱1M up (the "house unit"), exact below that.
class Fmt {
  static const locale = 'en_PH';
  static const symbol = '₱';

  static double _n(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  /// The million is the house unit for money.
  static String money(dynamic v, {bool withSymbol = true}) {
    final n = _n(v);
    final abs = n.abs();
    final sign = n < 0 ? '-' : '';
    final pre = withSymbol ? symbol : '';
    if (abs < 1e6) {
      return '$sign$pre${NumberFormat.decimalPattern(locale).format(abs.round())}';
    }
    final m = abs / 1e6;
    final digits = m >= 1000 ? 0 : m >= 10 ? 1 : 2;
    final f = NumberFormat.decimalPattern(locale)
      ..minimumFractionDigits = digits
      ..maximumFractionDigits = digits;
    return '$sign$pre${f.format(m)} M';
  }

  static String moneyShort(dynamic v) => money(v);

  static String number(dynamic v, [int digits = 0]) {
    final f = NumberFormat.decimalPattern(locale)..maximumFractionDigits = digits;
    return f.format(_n(v));
  }

  /// Magnitude-stepped abbreviation, for counts/quantities (not money).
  static String compact(dynamic v) {
    final n = _n(v);
    final abs = n.abs();
    final sign = n < 0 ? '-' : '';
    if (abs >= 1e12) return '$sign${(abs / 1e12).toStringAsFixed(abs >= 1e13 ? 0 : 1)}T';
    if (abs >= 1e9) return '$sign${(abs / 1e9).toStringAsFixed(abs >= 1e10 ? 0 : 1)}B';
    if (abs >= 1e6) return '$sign${(abs / 1e6).toStringAsFixed(abs >= 1e7 ? 0 : 1)}M';
    if (abs >= 1e3) return '$sign${(abs / 1e3).toStringAsFixed(abs >= 1e4 ? 0 : 1)}K';
    return '$sign${abs.toStringAsFixed(0)}';
  }

  static String percent(dynamic v, [int digits = 1]) {
    if (v == null) return '—';
    final n = _n(v);
    return '${n.toStringAsFixed(digits)}%';
  }

  /// Signed percentage for deltas — null renders as "n/a" (no basis to compare).
  static String delta(dynamic v, [int digits = 1]) {
    if (v == null) return 'n/a';
    final n = _n(v);
    return '${n >= 0 ? '+' : ''}${n.toStringAsFixed(digits)}%';
  }

  static String byFormat(dynamic v, String? fmt) {
    if (fmt == 'currency') return money(v);
    if (fmt == 'percent') return '${_n(v).toStringAsFixed(1)}%';
    return number(v);
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// "02 Sep 2026". Formatted by hand so it never depends on intl locale data
  /// being initialized (DateFormat with a named locale throws otherwise).
  static String date(dynamic v) {
    if (v == null) return '';
    final d = DateTime.tryParse(v.toString());
    if (d == null) return v.toString();
    final dd = d.day.toString().padLeft(2, '0');
    return '$dd ${_months[d.month - 1]} ${d.year}';
  }
}
