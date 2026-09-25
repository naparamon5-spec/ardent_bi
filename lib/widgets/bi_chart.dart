import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import '../format.dart';
import '../theme.dart';
import 'insights_sheet.dart';

/// A titled chart/section card, the mobile stand-in for the `BiChart` shell.
class BiCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  const BiCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: t.textPrimary)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: TextStyle(fontSize: 11.5, color: t.textMuted)),
                  ],
                ]),
              ),
              ?trailing,
            ]),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class SeriesSpec {
  final String name;
  final List<double> data;
  const SeriesSpec(this.name, this.data);
}

class BarDatum {
  final String name;
  final double value;
  final bool selected;
  const BarDatum(this.name, this.value, {this.selected = false});
}

/// A dashed reference line across a series chart (e.g. the 80% class-A boundary).
class MarkLineSpec {
  final String name;
  final double value;
  const MarkLineSpec(this.name, this.value);
}

enum BiChartType { line, column, area, stacked, stacked100, bar, pie, donut, funnel, treemap, waterfall }

const _typeLabels = <BiChartType, String>{
  BiChartType.line: 'Line',
  BiChartType.column: 'Column',
  BiChartType.area: 'Area',
  BiChartType.stacked: 'Stacked column',
  BiChartType.stacked100: '100% stacked',
  BiChartType.bar: 'Bar',
  BiChartType.pie: 'Pie',
  BiChartType.donut: 'Donut',
  BiChartType.funnel: 'Funnel',
  BiChartType.treemap: 'Treemap',
  BiChartType.waterfall: 'Waterfall',
};

const _typeHints = <BiChartType, String>{
  BiChartType.line: 'Change over time',
  BiChartType.column: 'Magnitude across periods',
  BiChartType.area: 'Change over time where the total matters',
  BiChartType.stacked: 'Composition within each period',
  BiChartType.stacked100: 'Composition as a share of each period',
  BiChartType.bar: 'Ranked categories',
  BiChartType.pie: 'Share of the total',
  BiChartType.donut: 'Share of the total',
  BiChartType.funnel: 'Stages from largest to smallest',
  BiChartType.treemap: 'Relative size at a glance',
  BiChartType.waterfall: 'Cumulative effect of changes',
};

class _MenuChoice {
  final BiChartType? type;
  final String? action;
  const _MenuChoice.type(this.type) : action = null;
  const _MenuChoice.action(this.action) : type = null;
}

/// Chart card with the web's per-visual controls: a Table toggle and a
/// chart-type menu (Line/Column/Area/Stacked for series, Bar/Column for
/// ranked breakdowns). The table view renders the same numbers as rows.
class BiChartCard extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<String> categories;
  final List<SeriesSpec> series;
  final List<BarDatum> bars;
  final bool currency;
  final bool percent;
  final bool signColors;
  final double height;
  final Widget? above;
  final void Function(String category)? onBarTap;
  final List<BiChartType>? types;
  final List<MarkLineSpec> markLines;
  final bool defaultTable;
  final BiChartType? initialType;
  /// Overrides the categorical series palette — the ageing charts are painted
  /// with the fixed, positional ageing palette, as on the web.
  final List<Color>? palette;
  /// Per-chart insights — the bulb in the card header opens them inline, the
  /// mobile stand-in for the web's per-visual insight panel.
  final List<Map<String, dynamic>> insights;

  const BiChartCard({
    super.key,
    required this.title,
    this.subtitle,
    this.categories = const [],
    this.series = const [],
    this.bars = const [],
    this.currency = true,
    this.percent = false,
    this.signColors = false,
    this.height = 240,
    this.above,
    this.onBarTap,
    this.types,
    this.markLines = const [],
    this.defaultTable = false,
    this.initialType,
    this.palette,
    this.insights = const [],
  });

  @override
  State<BiChartCard> createState() => _BiChartCardState();
}

class _BiChartCardState extends State<BiChartCard> {
  BiChartType? _type;
  bool _table = false;
  bool _showInsights = false;
  final GlobalKey _shotKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _table = widget.defaultTable;
  }

  bool get _seriesMode => widget.series.isNotEmpty;

  /// Bars to draw for bar/pie/funnel/donut when the card was given series
  /// instead of bars (e.g. the period charts): fall back to the first series,
  /// one bar per category.
  List<BarDatum> get _effectiveBars {
    if (widget.bars.isNotEmpty) return widget.bars;
    if (_seriesMode && widget.categories.isNotEmpty) {
      final s = widget.series.first;
      return [
        for (var i = 0; i < widget.categories.length; i++)
          BarDatum(widget.categories[i], i < s.data.length ? s.data[i] : 0),
      ];
    }
    return const [];
  }

  List<BiChartType> get _allowed =>
      widget.types ??
      (_seriesMode
          ? const [BiChartType.line, BiChartType.column, BiChartType.area, BiChartType.stacked]
          : const [BiChartType.bar, BiChartType.column]);

  BiChartType get _effective =>
      _type ?? (_seriesMode ? BiChartType.line : BiChartType.bar);

  String get _slug =>
      widget.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');

  String _fmt(double v) =>
      widget.percent ? '${v.toStringAsFixed(1)}%' : (widget.currency ? Fmt.compact(v) : Fmt.number(v));

  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.title,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.textPrimary)),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(widget.subtitle!, style: TextStyle(fontSize: 11.5, color: t.textMuted)),
                  ],
                ]),
              ),
              if (widget.insights.isNotEmpty) ...[
                _insightsPill(t),
                const SizedBox(width: 4),
              ],
              _tablePill(t),
              const SizedBox(width: 4),
              _cardMenu(t),
            ]),
            const SizedBox(height: 14),
            if (_showInsights && widget.insights.isNotEmpty) ...[
              _insightsPanel(t),
              const SizedBox(height: 12),
            ],
            if (widget.above != null) ...[
              widget.above!,
              const SizedBox(height: 12),
            ],
            RepaintBoundary(
              key: _shotKey,
              child: _table ? _tableView(t) : _chart(t),
            ),
          ],
        ),
      ),
    );
  }

  /// The bulb in the header — count badge, tinted solid when the panel is open
  /// (high-contrast active state, per the web's red-tinted open pill).
  Widget _insightsPill(BiTokens t) {
    final on = _showInsights;
    return InkWell(
      onTap: () => setState(() => _showInsights = !_showInsights),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: on ? t.brandSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: on ? t.brand.withValues(alpha: 0.22) : Colors.transparent),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(on ? Icons.lightbulb : Icons.lightbulb_outline,
              size: 15, color: on ? t.brand : t.textSecondary),
          const SizedBox(width: 4),
          Text('${widget.insights.length}',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: on ? t.brand : t.textSecondary)),
        ]),
      ),
    );
  }

  /// Inline explanation of this chart, the mobile stand-in for the web's
  /// per-visual insight panel. Beige plane so it reads as an inset, not a card.
  Widget _insightsPanel(BiTokens t) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.plane,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.gridline),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Why this chart matters',
            style: TextStyle(fontSize: 11, letterSpacing: 0.4, fontWeight: FontWeight.w700, color: t.textMuted)),
        const SizedBox(height: 10),
        for (var i = 0; i < widget.insights.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          InsightTile(item: widget.insights[i]),
        ],
      ]),
    );
  }

  Widget _tablePill(BiTokens t) {
    final on = _table;
    return InkWell(
      onTap: () => setState(() => _table = !_table),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: on ? t.brandSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: on ? t.brand.withValues(alpha: 0.22) : Colors.transparent),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.table_view_outlined, size: 15, color: on ? t.brand : t.textSecondary),
          const SizedBox(width: 4),
          Text('Table',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: on ? t.brand : t.textSecondary)),
        ]),
      ),
    );
  }

  Widget _cardMenu(BiTokens t) {
    final current = _effective;
    return PopupMenuButton<_MenuChoice>(
      tooltip: 'Chart options',
      onSelected: (choice) {
        if (choice.type != null) {
          setState(() => _type = choice.type);
        } else if (choice.action == 'png') {
          _downloadPng();
        } else if (choice.action == 'csv') {
          _downloadCsv();
        }
      },
      itemBuilder: (_) => [
        for (final v in _allowed)
          PopupMenuItem<_MenuChoice>(
            value: _MenuChoice.type(v),
            height: 52,
            child: Row(children: [
              Icon(Icons.check, size: 16, color: v == current ? t.brand : Colors.transparent),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(_typeLabels[v]!,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.textPrimary)),
                  Text(_typeHints[v]!, style: TextStyle(fontSize: 11, color: t.textMuted)),
                ]),
              ),
            ]),
          ),
        const PopupMenuDivider(height: 8),
        PopupMenuItem<_MenuChoice>(
          value: const _MenuChoice.action('png'),
          height: 44,
          child: Row(children: [
            Icon(Icons.image_outlined, size: 17, color: t.textSecondary),
            const SizedBox(width: 10),
            Text('Download PNG',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.textPrimary)),
          ]),
        ),
        PopupMenuItem<_MenuChoice>(
          value: const _MenuChoice.action('csv'),
          height: 44,
          child: Row(children: [
            Icon(Icons.table_chart_outlined, size: 17, color: t.textSecondary),
            const SizedBox(width: 10),
            Text('Download CSV',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.textPrimary)),
          ]),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(_typeLabels[current]!,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.textSecondary)),
          Icon(Icons.arrow_drop_down, size: 18, color: t.textSecondary),
        ]),
      ),
    );
  }

  Future<void> _downloadPng() async {
    final ctx = _shotKey.currentContext;
    if (ctx == null) return;
    final boundary = ctx.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return;
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(bytes.buffer.asUint8List(), mimeType: 'image/png', name: '$_slug.png')],
      subject: widget.title,
    ));
  }

  Future<void> _downloadCsv() async {
    final lines = <String>[];
    if (_seriesMode) {
      lines.add(['Category', for (final s in widget.series) s.name].map(_csvRow).join(','));
      for (var r = 0; r < widget.categories.length; r++) {
        lines.add([
          widget.categories[r],
          for (final s in widget.series)
            (s.data.length > r ? s.data[r] : 0.0).toStringAsFixed(2),
        ].map(_csvRow).join(','));
      }
    } else {
      lines.add('Category,Value');
      for (final b in widget.bars) {
        lines.add([b.name, b.value.toStringAsFixed(2)].map(_csvRow).join(','));
      }
    }
    final bytes = utf8.encode(lines.join('\n'));
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(bytes, mimeType: 'text/csv', name: '$_slug.csv')],
      subject: widget.title,
    ));
  }

  static String _csvRow(String cell) {
    if (cell.contains(RegExp(r'[",\n]'))) {
      return '"${cell.replaceAll('"', '""')}"';
    }
    return cell;
  }

  Widget _chart(BiTokens t) {
    switch (_effective) {
      case BiChartType.line:
        return _LineView(categories: widget.categories, series: widget.series, currency: widget.currency, percent: widget.percent, height: widget.height, fill: false, markLines: widget.markLines);
      case BiChartType.area:
        return _LineView(categories: widget.categories, series: widget.series, currency: widget.currency, percent: widget.percent, height: widget.height, fill: true, markLines: widget.markLines);
      case BiChartType.column:
        return _seriesMode
            ? _ColumnsView(categories: widget.categories, series: widget.series, currency: widget.currency, percent: widget.percent, height: widget.height, stacked: false, palette: widget.palette)
            : _BarsColumnView(bars: widget.bars, currency: widget.currency, signColors: widget.signColors, height: widget.height, onTap: widget.onBarTap, palette: widget.palette);
      case BiChartType.stacked:
        return _ColumnsView(categories: widget.categories, series: widget.series, currency: widget.currency, percent: widget.percent, height: widget.height, stacked: true, palette: widget.palette);
      case BiChartType.stacked100:
        return _ColumnsView(categories: widget.categories, series: widget.series, currency: widget.currency, percent: widget.percent, height: widget.height, stacked: true, normalize: true, palette: widget.palette);
      case BiChartType.bar:
        return _HBarView(bars: _effectiveBars, currency: widget.currency, percent: widget.percent, signColors: widget.signColors, onTap: widget.onBarTap, palette: widget.palette);
      case BiChartType.pie:
        return _DonutView(bars: _effectiveBars, currency: widget.currency, height: widget.height, hole: false);
      case BiChartType.donut:
        return _DonutView(bars: _effectiveBars, currency: widget.currency, height: widget.height);
      case BiChartType.funnel:
        return _FunnelView(bars: _effectiveBars, currency: widget.currency, percent: widget.percent, height: widget.height, palette: widget.palette);
      case BiChartType.treemap:
        return _TreemapView(bars: widget.bars, currency: widget.currency, height: widget.height);
      case BiChartType.waterfall:
        return _WaterfallView(bars: widget.bars, currency: widget.currency, height: widget.height);
    }
  }

  Widget _tableView(BiTokens t) {
    final headers = _seriesMode
        ? ['Category', for (final s in widget.series) s.name]
        : ['Category', 'Value'];
    final rows = _seriesMode
        ? [
            for (var r = 0; r < widget.categories.length; r++)
              [widget.categories[r], for (final s in widget.series) _fmt(s.data.length > r ? s.data[r] : 0)],
          ]
        : [
            for (final b in widget.bars) [b.name, _fmt(b.value)],
          ];
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('No data for this selection', style: TextStyle(color: t.textMuted, fontSize: 12))),
      );
    }
    return LayoutBuilder(
      builder: (context, cons) => ConstrainedBox(
        constraints: BoxConstraints(minWidth: cons.maxWidth),
        child: Table(
          columnWidths: {
            0: const FlexColumnWidth(1.4),
            for (var c = 1; c < headers.length; c++) c: const FixedColumnWidth(104),
          },
          children: [
            TableRow(
              children: [
                for (var c = 0; c < headers.length; c++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      headers[c].toUpperCase(),
                      textAlign: c == 0 ? TextAlign.left : TextAlign.right,
                      style: TextStyle(fontSize: 10.5, letterSpacing: 0.5, fontWeight: FontWeight.w600, color: t.textMuted),
                    ),
                  ),
              ],
            ),
            for (final row in rows)
              TableRow(
                children: [
                  for (var c = 0; c < row.length; c++)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.gridline))),
                      child: Text(
                        row[c],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: c == 0 ? TextAlign.left : TextAlign.right,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: c == 0 ? FontWeight.w500 : FontWeight.w600,
                          color: c == 0 ? t.textPrimary : t.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

Widget _empty(BiTokens t, double height) => SizedBox(
      height: height,
      child: Center(
        child: Text('No data for this selection', style: TextStyle(color: t.textMuted, fontSize: 12)),
      ),
    );

FlTitlesData _titles(BiTokens t, List<String> categories, bool currency, double maxY, {bool percent = false}) => FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 44,
          interval: maxY / 2,
          getTitlesWidget: (v, meta) {
            if (v == 0) return const SizedBox.shrink();
            final label = percent ? '${v.toStringAsFixed(0)}%' : Fmt.compact(v);
            return Text(label, style: TextStyle(fontSize: 9, color: t.textMuted));
          },
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 26,
          interval: (categories.length / 5).ceilToDouble().clamp(1, 999),
          getTitlesWidget: (v, meta) {
            final i = v.toInt();
            if (i < 0 || i >= categories.length) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: SizedBox(
                width: 46,
                child: Text(categories[i],
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 9, color: t.textMuted)),
              ),
            );
          },
        ),
      ),
    );

Widget _legend(BiTokens t, List<SeriesSpec> series, [List<Color>? palette]) => Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        for (var i = 0; i < series.length; i++)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 10, height: 10,
                decoration: BoxDecoration(
                    color: (palette ?? t.series)[i % (palette ?? t.series).length],
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 5),
            Text(series[i].name, style: TextStyle(fontSize: 11, color: t.textSecondary)),
          ]),
      ],
    );

class _LineView extends StatelessWidget {
  final List<String> categories;
  final List<SeriesSpec> series;
  final bool currency;
  final bool percent;
  final double height;
  final bool fill;
  final List<MarkLineSpec> markLines;
  const _LineView({
    required this.categories,
    required this.series,
    required this.currency,
    required this.height,
    required this.fill,
    this.percent = false,
    this.markLines = const [],
  });

  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    if (categories.isEmpty) return _empty(t, height);
    double maxY = 0;
    for (final s in series) {
      for (final v in s.data) {
        if (v > maxY) maxY = v;
      }
    }
    if (maxY == 0) maxY = 1;
    for (final m in markLines) {
      if (m.value > maxY) maxY = m.value;
    }
    maxY *= 1.12;

    return Column(
      children: [
        SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY / 4,
                getDrawingHorizontalLine: (_) => FlLine(color: t.gridline, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  for (final m in markLines)
                    HorizontalLine(
                      y: m.value,
                      color: t.textMuted,
                      strokeWidth: 1,
                      dashArray: [6, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        style: TextStyle(fontSize: 9, color: t.textMuted),
                        labelResolver: (_) => m.name,
                      ),
                    ),
                ],
              ),
              titlesData: _titles(t, categories, currency, maxY, percent: percent),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => t.elevated,
                  getTooltipItems: (spots) => spots.map((s) {
                    final c = t.series[s.barIndex % t.series.length];
                    return LineTooltipItem(
                      percent ? Fmt.percent(s.y) : (currency ? Fmt.money(s.y) : Fmt.number(s.y)),
                      TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 11),
                    );
                  }).toList(),
                ),
              ),
              lineBarsData: [
                for (var i = 0; i < series.length; i++)
                  LineChartBarData(
                    spots: [
                      for (var x = 0; x < series[i].data.length; x++)
                        FlSpot(x.toDouble(), series[i].data[x]),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.25,
                    color: t.series[i % t.series.length],
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: fill || series.length == 1,
                      color: t.series[i % t.series.length].withValues(alpha: fill ? 0.18 : 0.10),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _legend(t, series),
      ],
    );
  }
}

class _ColumnsView extends StatelessWidget {
  final List<String> categories;
  final List<SeriesSpec> series;
  final bool currency;
  final bool percent;
  final double height;
  final bool stacked;
  /// 100% stacked: each category is scaled so its bars sum to 100%.
  final bool normalize;
  final List<Color>? palette;
  const _ColumnsView({
    required this.categories,
    required this.series,
    required this.currency,
    required this.height,
    required this.stacked,
    this.normalize = false,
    this.percent = false,
    this.palette,
  });

  List<Color> _colors(BiTokens t) => palette ?? t.series;

  bool get _pct => percent || normalize;

  /// Total across all series for a category (denominator for normalize).
  double _catTotal(int x) {
    double sum = 0;
    for (final s in series) {
      sum += s.data.length > x ? s.data[x] : 0.0;
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    if (categories.isEmpty) return _empty(t, height);
    double maxY = 0;
    if (normalize) {
      maxY = 100;
    } else {
      for (var x = 0; x < categories.length; x++) {
        double per = 0;
        for (final s in series) {
          final v = s.data.length > x ? s.data[x] : 0.0;
          if (stacked) {
            per += v;
          } else if (v > per) {
            per = v;
          }
        }
        if (per > maxY) maxY = per;
      }
    }
    if (maxY == 0) maxY = 1;

    return Column(
      children: [
        SizedBox(
          height: height,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              minY: 0,
              maxY: normalize ? 100 : maxY * 1.12,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY / 4,
                getDrawingHorizontalLine: (_) => FlLine(color: t.gridline, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: _titles(t, categories, currency, maxY, percent: _pct),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => t.elevated,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                    _pct ? Fmt.percent(rod.toY) : (currency ? Fmt.money(rod.toY) : Fmt.number(rod.toY)),
                    TextStyle(
                      color: stacked ? _colors(t)[rodIndex % _colors(t).length] : rod.color ?? t.brand,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
              barGroups: [
                for (var x = 0; x < categories.length; x++)
                  BarChartGroupData(
                    x: x,
                    barRods: stacked
                        ? [_stackedRod(t, x)]
                        : [
                            for (var i = 0; i < series.length; i++)
                              BarChartRodData(
                                toY: series[i].data.length > x ? series[i].data[x] : 0.0,
                                color: _colors(t)[i % _colors(t).length],
                                width: series.length == 1 ? 18 : 10,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                              ),
                          ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _legend(t, series, palette),
      ],
    );
  }

  BarChartRodData _stackedRod(BiTokens t, int x) {
    final items = <BarChartRodStackItem>[];
    var from = 0.0;
    final denom = normalize ? _catTotal(x) : 0.0;
    for (var i = 0; i < series.length; i++) {
      var v = series[i].data.length > x ? series[i].data[x] : 0.0;
      if (normalize) v = denom == 0 ? 0.0 : v / denom * 100;
      items.add(BarChartRodStackItem(from, from + v, _colors(t)[i % _colors(t).length]));
      from += v;
    }
    return BarChartRodData(
      toY: from,
      width: 18,
      rodStackItems: items,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
    );
  }
}

class _BarsColumnView extends StatelessWidget {
  final List<BarDatum> bars;
  final bool currency;
  final bool signColors;
  final double height;
  final void Function(String category)? onTap;
  final List<Color>? palette;
  const _BarsColumnView({
    required this.bars,
    required this.currency,
    required this.signColors,
    required this.height,
    this.onTap,
    this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    if (bars.isEmpty) return _empty(t, height);
    double maxY = 0;
    double minY = 0;
    for (final b in bars) {
      if (b.value > maxY) maxY = b.value;
      if (b.value < minY) minY = b.value;
    }
    if (maxY == 0 && minY == 0) maxY = 1;

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          minY: minY == 0 ? 0 : minY * 1.12,
          maxY: maxY == 0 ? 1 : maxY * 1.12,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: t.gridline, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: _titles(t, bars.map((b) => b.name).toList(), currency, maxY == 0 ? 1 : maxY),
          barTouchData: BarTouchData(
            touchCallback: (event, response) {
              if (onTap == null) return;
              final idx = response?.spot?.touchedBarGroupIndex;
              if (idx != null && idx >= 0 && idx < bars.length) {
                if (event is! FlTapUpEvent) return;
                onTap!(bars[idx].name);
              }
            },
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => t.elevated,
              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                currency ? Fmt.money(rod.toY) : Fmt.number(rod.toY),
                TextStyle(color: rod.color ?? t.brand, fontWeight: FontWeight.w600, fontSize: 11),
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < bars.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: bars[i].value,
                    // A single-series column chart is one colour (series[0] blue),
                    // matching the web — not a per-bar rainbow. Sign colouring is a
                    // status encoding; a selected bar wears brand red so the active
                    // filter reads solid, not tinted.
                    color: signColors
                        ? (bars[i].value < 0 ? AppColors.critical : AppColors.good)
                        : bars[i].selected
                            ? t.brand
                            : palette == null
                                ? t.series[0]
                                : palette![i % palette!.length],
                    width: 14,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Tappable horizontal bars — the mobile take on the web's clickable hbar, used
/// for "by brand / by salesman" breakdowns and biggest movers. `signColors`
/// paints negatives red / positives green (a status encoding).
class _HBarView extends StatelessWidget {
  final List<BarDatum> bars;
  final bool currency;
  final bool percent;
  final bool signColors;
  final void Function(String category)? onTap;
  final List<Color>? palette;
  const _HBarView({
    required this.bars,
    required this.currency,
    required this.signColors,
    this.percent = false,
    this.onTap,
    this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    if (bars.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('No data for this selection', style: TextStyle(color: t.textMuted, fontSize: 12))),
      );
    }
    final maxAbs = bars.map((b) => b.value.abs()).fold<double>(0, (a, b) => a > b ? a : b);
    final denom = maxAbs == 0 ? 1 : maxAbs;

    return Column(
      children: [
        for (var i = 0; i < bars.length; i++)
          _row(context, t, bars[i], i, denom.toDouble()),
      ],
    );
  }

  Widget _row(BuildContext context, BiTokens t, BarDatum b, int i, double denom) {
    final frac = (b.value.abs() / denom).clamp(0.0, 1.0);
    // One colour for the whole ranked set (series[0] blue) like the web hbar —
    // sign colouring is a status encoding, and a selected bar wears solid brand
    // red so the active filter is unmistakable rather than a subtle tint.
    final Color color = signColors
        ? (b.value < 0 ? AppColors.critical : AppColors.good)
        : b.selected
            ? t.brand
            : palette == null
                ? t.series[0]
                : palette![i % palette!.length];
    return InkWell(
      onTap: onTap == null ? null : () => onTap!(b.name),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(
                  b.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: b.selected ? t.brand : t.textPrimary,
                    fontWeight: b.selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(percent ? Fmt.percent(b.value) : (currency ? Fmt.money(b.value) : Fmt.number(b.value)),
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: t.textSecondary)),
            ]),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(children: [
                Container(height: 8, color: t.gridline),
                FractionallySizedBox(
                  widthFactor: frac == 0 ? 0.001 : frac,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      border: b.selected ? Border.all(color: t.brand, width: 1.5) : null,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Share-of-total ring with the grand total in the middle, mirroring the web
/// donut. Labels only appear on slices big enough to hold them.
class _DonutView extends StatelessWidget {
  final List<BarDatum> bars;
  final bool currency;
  final double height;
  /// Donut (a hole with the total in the middle) vs. pie (solid, no hole).
  final bool hole;
  const _DonutView({required this.bars, required this.currency, required this.height, this.hole = true});

  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    final slices = bars.where((b) => b.value > 0).toList();
    if (slices.isEmpty) return _empty(t, height);
    final total = slices.fold<double>(0, (a, b) => a + b.value);

    return Column(
      children: [
        SizedBox(
          height: height,
          child: Stack(alignment: Alignment.center, children: [
            PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: hole ? height * 0.24 : 0,
                startDegreeOffset: -90,
                sections: [
                  for (var i = 0; i < slices.length; i++)
                    PieChartSectionData(
                      value: slices[i].value,
                      color: t.series[i % t.series.length],
                      radius: hole ? height * 0.19 : height * 0.42,
                      title: slices[i].value / total >= 0.07
                          ? '${(slices[i].value / total * 100).round()}%'
                          : '',
                      titleStyle: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                ],
              ),
            ),
            if (hole)
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text(currency ? Fmt.compact(total) : Fmt.number(total),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: t.textPrimary)),
                Text('Total', style: TextStyle(fontSize: 10.5, letterSpacing: 0.5, color: t.textMuted)),
              ]),
          ]),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            for (var i = 0; i < slices.length; i++)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 10, height: 10,
                    decoration: BoxDecoration(
                        color: t.series[i % t.series.length], borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 5),
                Text('${slices[i].name} · ${currency ? Fmt.compact(slices[i].value) : Fmt.number(slices[i].value)}',
                    style: TextStyle(fontSize: 11, color: t.textSecondary)),
              ]),
          ],
        ),
      ],
    );
  }
}

/// Funnel — stages sorted largest to smallest as centered, tapering bars. Width
/// encodes each stage's value relative to the largest; the label shows its share.
class _FunnelView extends StatelessWidget {
  final List<BarDatum> bars;
  final bool currency;
  final bool percent;
  final double height;
  final List<Color>? palette;
  const _FunnelView({required this.bars, required this.currency, required this.height, this.percent = false, this.palette});

  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    final items = bars.where((b) => b.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (items.isEmpty) return _empty(t, height);
    final colors = palette ?? t.series;
    final maxV = items.first.value;
    final total = items.fold<double>(0, (a, b) => a + b.value);
    final barH = ((height - (items.length - 1) * 8) / items.length).clamp(20.0, 60.0);

    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(items[i].name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: t.textPrimary, fontWeight: FontWeight.w500)),
                ),
                const SizedBox(width: 8),
                Text(percent ? Fmt.percent(items[i].value) : (currency ? Fmt.money(items[i].value) : Fmt.number(items[i].value)),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.textSecondary)),
              ]),
              const SizedBox(height: 4),
              Center(
                child: FractionallySizedBox(
                  widthFactor: maxV == 0 ? 0.02 : (items[i].value / maxV).clamp(0.04, 1.0),
                  child: Container(
                    height: barH,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors[i % colors.length],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      total == 0 ? '' : '${(items[i].value / total * 100).round()}%',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Squarified treemap — area encodes value, so the biggest contributors jump
/// out without reading an axis.
class _TreemapView extends StatelessWidget {
  final List<BarDatum> bars;
  final bool currency;
  final double height;
  const _TreemapView({required this.bars, required this.currency, required this.height});

  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    final cells = bars.where((b) => b.value > 0).toList();
    if (cells.isEmpty) return _empty(t, height);

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, cons) {
          final area = Rect.fromLTWH(0, 0, cons.maxWidth, height);
          final rects = _squarify(cells.map((c) => c.value).toList(), area);
          return CustomPaint(
            size: Size(cons.maxWidth, height),
            painter: _TreemapPainter(cells, rects, t, currency),
          );
        },
      ),
    );
  }
}

class _TreemapPainter extends CustomPainter {
  final List<BarDatum> cells;
  final List<Rect> rects;
  final BiTokens t;
  final bool currency;
  _TreemapPainter(this.cells, this.rects, this.t, this.currency);

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < cells.length; i++) {
      final r = RRect.fromRectAndRadius(rects[i].deflate(1.5), const Radius.circular(3));
      canvas.drawRRect(r, Paint()..color = t.series[i % t.series.length]);
      final box = rects[i].deflate(6);
      if (box.width < 58 || box.height < 28) continue;
      _label(canvas, cells[i].name, TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white), box, 0);
      _label(
          canvas,
          currency ? Fmt.compact(cells[i].value) : Fmt.number(cells[i].value),
          const TextStyle(fontSize: 10.5, color: Color(0xE6FFFFFF)),
          box,
          14);
    }
  }

  void _label(Canvas canvas, String text, TextStyle style, Rect box, double dy) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: box.width);
    tp.paint(canvas, Offset(box.left, box.top + dy));
  }

  @override
  bool shouldRepaint(_TreemapPainter old) =>
      old.cells != cells || old.rects != rects || old.t != t;
}

List<Rect> _squarify(List<double> values, Rect area) {
  final n = values.length;
  final rects = List<Rect>.filled(n, Rect.zero);
  final total = values.fold<double>(0, (a, b) => a + b);
  if (total <= 0 || area.width <= 0 || area.height <= 0) return rects;

  final scaled = [for (final v in values) v / total * area.width * area.height];
  var rest = area;
  var i = 0;
  while (i < n && rest.width > 0 && rest.height > 0) {
    final horizontal = rest.width >= rest.height;
    final side = horizontal ? rest.height : rest.width;
    var row = <double>[scaled[i]];
    var rowSum = scaled[i];
    var worst = _aspect(row, rowSum, side);
    var j = i + 1;
    while (j < n) {
      final cand = [...row, scaled[j]];
      final w = _aspect(cand, rowSum + scaled[j], side);
      if (w > worst) break;
      row = cand;
      rowSum += scaled[j];
      worst = w;
      j++;
    }
    final thick = rowSum / side;
    var offset = horizontal ? rest.top : rest.left;
    for (var k = 0; k < row.length; k++) {
      final len = row[k] / thick;
      rects[i + k] = horizontal
          ? Rect.fromLTRB(rest.left, offset, rest.left + thick, offset + len)
          : Rect.fromLTRB(offset, rest.top, offset + len, rest.top + thick);
      offset += len;
    }
    rest = horizontal
        ? Rect.fromLTRB(rest.left + thick, rest.top, rest.right, rest.bottom)
        : Rect.fromLTRB(rest.left, rest.top + thick, rest.right, rest.bottom);
    i = j;
  }
  return rects;
}

double _aspect(List<double> row, double sum, double side) {
  var mx = 0.0;
  var mn = double.infinity;
  for (final v in row) {
    if (v > mx) mx = v;
    if (v < mn) mn = v;
  }
  final s2 = sum * sum;
  final d2 = side * side;
  final a = d2 * mx / s2;
  final b = s2 / (d2 * mn);
  return a > b ? a : b;
}

/// Cumulative walk: each mover's delta is stacked from the running total, with
/// a closing "Net" bar so the end state reads at a glance.
class _WaterfallView extends StatelessWidget {
  final List<BarDatum> bars;
  final bool currency;
  final double height;
  const _WaterfallView({required this.bars, required this.currency, required this.height});

  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    if (bars.isEmpty) return _empty(t, height);

    var running = 0.0;
    final steps = <_Step>[];
    for (final b in bars) {
      steps.add(_Step(b.name, running, running + b.value, b.value >= 0 ? AppColors.good : AppColors.critical, b.value));
      running += b.value;
    }
    steps.add(_Step('Net', 0, running, t.brand, running));

    var minY = 0.0;
    var maxY = 0.0;
    for (final s in steps) {
      if (s.from < minY) minY = s.from;
      if (s.to < minY) minY = s.to;
      if (s.from > maxY) maxY = s.from;
      if (s.to > maxY) maxY = s.to;
    }
    if (minY == maxY) {
      minY = -1;
      maxY = 1;
    }
    final span = maxY - minY;

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          minY: minY - span * 0.06,
          maxY: maxY + span * 0.06,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: t.gridline, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: _titles(t, steps.map((s) => s.label).toList(), currency, maxY == 0 ? 1 : maxY),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => t.elevated,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final d = steps[groupIndex].delta;
                return BarTooltipItem(
                  '${d >= 0 ? '+' : ''}${currency ? Fmt.money(d) : Fmt.number(d)}',
                  TextStyle(color: rod.color ?? t.brand, fontWeight: FontWeight.w600, fontSize: 11),
                );
              },
            ),
          ),
          barGroups: [
            for (var i = 0; i < steps.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    fromY: steps[i].low,
                    toY: steps[i].high,
                    color: steps[i].color,
                    width: 14,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Step {
  final String label;
  final double from;
  final double to;
  final Color color;
  final double delta;
  const _Step(this.label, this.from, this.to, this.color, this.delta);
  double get low => from < to ? from : to;
  double get high => from < to ? to : from;
}
