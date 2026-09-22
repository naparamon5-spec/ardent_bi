import 'package:flutter/material.dart';
import '../format.dart';
import '../theme.dart';

/// A single KPI card — mobile counterpart of `KpiTile.vue`. Shows a value, an
/// optional signed delta (green up / red down, "n/a" when there is no basis)
/// and an optional sub-line.
class KpiTile extends StatelessWidget {
  final String label;
  final dynamic value;
  final String format; // currency | percent | number
  final dynamic delta; // percentage; null → no basis to compare
  final bool deltaIsPoints;
  final String deltaLabel;
  final String? sub;
  final bool loading;

  const KpiTile({
    super.key,
    required this.label,
    required this.value,
    this.format = 'number',
    this.delta,
    this.deltaIsPoints = false,
    this.deltaLabel = 'vs prior period',
    this.sub,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    final valueStr = value is String ? value.toString() : Fmt.byFormat(value, format);
    final num? d = delta == null
        ? null
        : (delta is num)
            ? (delta as num).toDouble()
            : double.tryParse('$delta');
    final good = d != null && d >= 0;
    final deltaColor = d == null ? null : (good ? t.deltaUp : AppColors.deltaDown);
    final accent = deltaColor ?? t.brand;

    Widget chip() {
      final text = deltaIsPoints
          ? '${good ? '+' : ''}${d!.toStringAsFixed(1)} pts'
          : Fmt.delta(d);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: deltaColor!.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(good ? Icons.arrow_upward : Icons.arrow_downward, size: 12, color: deltaColor),
          const SizedBox(width: 2),
          Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: deltaColor)),
        ]),
      );
    }

    // Mirrors the web tile: no delta means no chip — the sub-line takes its
    // place ("9,422 invoices") rather than an "n/a" that reads as missing data.
    Widget deltaRow() {
      if (d != null) {
        return Row(children: [
          chip(),
          const SizedBox(width: 6),
          Flexible(
            child: Text(deltaLabel,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, color: t.textMuted)),
          ),
        ]);
      }
      if (sub != null) {
        return Text(sub!, style: TextStyle(fontSize: 10.5, color: t.textMuted));
      }
      return const SizedBox.shrink();
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 4, color: loading ? t.gridline : accent),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label.toUpperCase(),
                    style: TextStyle(
                        fontSize: 10.5, letterSpacing: 0.5, fontWeight: FontWeight.w600, color: t.textMuted)),
                const SizedBox(height: 8),
                if (loading)
                  _Skeleton(width: 90, height: 22, color: t.gridline)
                else
                  Text(valueStr,
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w700, color: t.textPrimary, height: 1.1)),
                const SizedBox(height: 6),
                if (!loading) deltaRow(),
                if (!loading && d != null && sub != null) ...[
                  const SizedBox(height: 4),
                  Text(sub!, style: TextStyle(fontSize: 10.5, color: t.textMuted)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lays KPI tiles two-per-row, each row sized to its tallest tile's content
/// (via IntrinsicHeight) so there is no fixed-aspect empty space below a tile.
class KpiGrid extends StatelessWidget {
  final List<KpiTile> tiles;
  final double spacing;
  const KpiGrid({super.key, required this.tiles, this.spacing = 10});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      final left = tiles[i];
      final right = i + 1 < tiles.length ? tiles[i + 1] : null;
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: left),
            SizedBox(width: spacing),
            Expanded(child: right ?? const SizedBox.shrink()),
          ],
        ),
      ));
      if (i + 2 < tiles.length) rows.add(SizedBox(height: spacing));
    }
    return Column(children: rows);
  }
}

class _Skeleton extends StatelessWidget {
  final double width, height;
  final Color color;
  const _Skeleton({required this.width, required this.height, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      );
}
