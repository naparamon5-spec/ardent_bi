import 'package:flutter/material.dart';
import '../format.dart';
import '../theme.dart';

/// One row of a pivot: a member of the row dimension plus one value per column.
class PivotRow {
  final String name;
  final List<double> values;
  final double total;
  const PivotRow(this.name, this.values, this.total);
}

/// The web's PivotTable as a mobile card: rows × columns with a heat shade on
/// each cell (value against the biggest cell) so the mix reads without scanning
/// numbers, plus a bold total column. Row names tap through to the filter.
class BiPivotCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String rowLabel;
  final List<String> columns;
  final List<PivotRow> rows;
  final List<double> columnTotals;
  final bool currency;
  final void Function(String name)? onRowTap;

  const BiPivotCard({
    super.key,
    required this.title,
    required this.rowLabel,
    required this.columns,
    required this.rows,
    this.subtitle,
    this.columnTotals = const [],
    this.currency = true,
    this.onRowTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    double maxCell = 0;
    for (final r in rows) {
      for (final v in r.values) {
        if (v > maxCell) maxCell = v;
      }
    }
    final denom = maxCell == 0 ? 1.0 : maxCell;
    final heat = t.series[0];

    String fmt(double v) => currency ? Fmt.money(v) : Fmt.number(v);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.textPrimary)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: TextStyle(fontSize: 11.5, color: t.textMuted)),
            ],
            const SizedBox(height: 12),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No data for this selection', style: TextStyle(color: t.textMuted, fontSize: 12))),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Table(
                  columnWidths: {
                    0: const FixedColumnWidth(150),
                    for (var c = 1; c <= columns.length + 1; c++) c: const FixedColumnWidth(92),
                  },
                  children: [
                    TableRow(
                      children: [
                        _header(t, rowLabel, left: true),
                        for (final c in columns) _header(t, c),
                        _header(t, 'Total'),
                      ],
                    ),
                    for (final r in rows)
                      TableRow(
                        children: [
                          _nameCell(t, r.name),
                          for (var i = 0; i < columns.length; i++)
                            _heatCell(t, heat, i < r.values.length ? r.values[i] : 0, denom, fmt),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.gridline))),
                            child: Text(fmt(r.total),
                                textAlign: TextAlign.right,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: t.textPrimary)),
                          ),
                        ],
                      ),
                    TableRow(
                      children: [
                        _header(t, 'Total', left: true, bold: true),
                        for (var i = 0; i < columns.length; i++)
                          _totalCell(t, i < columnTotals.length ? columnTotals[i] : 0, fmt),
                        _totalCell(t, columnTotals.fold<double>(0, (a, b) => a + b), fmt),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _header(BiTokens t, String s, {bool left = false, bool bold = false}) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.gridline))),
        child: Text(
          s.toUpperCase(),
          textAlign: left ? TextAlign.left : TextAlign.right,
          style: TextStyle(
            fontSize: 10.5,
            letterSpacing: 0.5,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            color: bold ? t.textPrimary : t.textMuted,
          ),
        ),
      );

  Widget _nameCell(BiTokens t, String name) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.gridline))),
        child: InkWell(
          onTap: onRowTap == null ? null : () => onRowTap!(name),
          child: Text(name,
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: t.textPrimary)),
        ),
      );

  Widget _heatCell(BiTokens t, Color heat, double v, double denom, String Function(double) fmt) {
    final intensity = v <= 0 ? 0.0 : (v / denom).clamp(0.0, 1.0);
    final shade = intensity == 0 ? null : Color.alphaBlend(heat.withValues(alpha: 0.12 + 0.78 * intensity), t.elevated);
    final ink = intensity > 0.45 ? Colors.white : t.textPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: shade,
        border: Border(bottom: BorderSide(color: t.gridline)),
      ),
      child: Text(fmt(v),
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: ink)),
    );
  }

  Widget _totalCell(BiTokens t, double v, String Function(double) fmt) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.gridline))),
        child: Text(fmt(v),
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: t.textPrimary)),
      );
}
