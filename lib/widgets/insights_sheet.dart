import 'package:flutter/material.dart';
import '../theme.dart';

Color insightSeverityColor(BiTokens t, String severity) => switch (severity) {
      'good' => AppColors.good,
      'warning' => AppColors.warning,
      'serious' => AppColors.serious,
      'critical' => AppColors.critical,
      _ => t.series[0],
    };

/// Bottom sheet listing the insight bundle for the current selection — the
/// mobile stand-in for the web's Insights drawer.
void showInsightsSheet(BuildContext context, List<dynamic> items) {
  final t = BiTokens.of(context);
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Insights',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: t.textPrimary)),
            const SizedBox(height: 2),
            Text('What stands out in the current selection',
                style: TextStyle(fontSize: 11.5, color: t.textMuted)),
            const SizedBox(height: 14),
            Flexible(
              child: items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                          child: Text('Nothing unusual in this window',
                              style: TextStyle(color: t.textMuted, fontSize: 12))),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => InsightTile(item: items[i] as Map),
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}

class InsightTile extends StatelessWidget {
  final Map item;
  const InsightTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    final color = insightSeverityColor(t, (item['severity'] ?? 'info').toString());
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text((item['title'] ?? '').toString(),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: t.textPrimary)),
        const SizedBox(height: 4),
        Text((item['detail'] ?? '').toString(),
            style: TextStyle(fontSize: 12, height: 1.35, color: t.textSecondary)),
      ]),
    );
  }
}
