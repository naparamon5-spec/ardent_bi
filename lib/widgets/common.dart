import 'package:flutter/material.dart';
import '../theme.dart';

/// AppBar filter button with an active-count badge, shared across pages.
class FilterButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const FilterButton({super.key, required this.count, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(clipBehavior: Clip.none, children: [
        IconButton(onPressed: onTap, icon: const Icon(Icons.tune)),
        if (count > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: t.brandSoft, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text('$count',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: t.brand, fontSize: 9, fontWeight: FontWeight.w700)),
            ),
          ),
      ]),
    );
  }
}

/// AppBar insights button with a count badge, shared across pages.
class InsightsButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const InsightsButton({super.key, required this.count, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    return Stack(clipBehavior: Clip.none, children: [
      IconButton(onPressed: onTap, icon: const Icon(Icons.auto_awesome_outlined)),
      if (count > 0)
        Positioned(
          right: 4,
          top: 4,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: t.brandSoft, shape: BoxShape.circle),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            child: Text('$count',
                textAlign: TextAlign.center,
                style: TextStyle(color: t.brand, fontSize: 9, fontWeight: FontWeight.w700)),
          ),
        ),
    ]);
  }
}

class ErrorBanner extends StatelessWidget {
  final String message;
  const ErrorBanner(this.message, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.critical.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.critical.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.critical),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 12.5, color: AppColors.critical))),
        ]),
      );
}

/// Small segmented chooser (measure/dimension pickers).
class ChipChooser<T> extends StatelessWidget {
  final Map<T, String> options;
  final T value;
  final ValueChanged<T> onChanged;
  const ChipChooser({super.key, required this.options, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    return Wrap(
      spacing: 8,
      children: [
        for (final e in options.entries)
          ChoiceChip(
            label: Text(e.value, style: const TextStyle(fontSize: 12)),
            selected: e.key == value,
            onSelected: (_) => onChanged(e.key),
            showCheckmark: false,
            backgroundColor: t.surface,
            selectedColor: t.brand,
            side: BorderSide(color: e.key == value ? t.brand : t.gridline),
            labelStyle: TextStyle(color: e.key == value ? t.brandInk : t.textSecondary),
          ),
      ],
    );
  }
}

/// Year + quarter selector row for period screens.
class YearQuarterSelector extends StatelessWidget {
  final int year;
  final String? quarter; // null = all quarters
  final List<int> years;
  final ValueChanged<int> onYearChanged;
  final ValueChanged<String?> onQuarterChanged;
  const YearQuarterSelector({
    super.key,
    required this.year,
    this.quarter,
    this.years = const [2026, 2025, 2024, 2023],
    required this.onYearChanged,
    required this.onQuarterChanged,
  });
  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: _eyebrow(t, 'YEAR'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _eyebrow(t, 'QUARTER'),
        ),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: Wrap(spacing: 6, runSpacing: 6, children: [
            for (final y in years)
              FilterChip(
                label: Text('$y'),
                selected: year == y,
                onSelected: (s) {
                  if (s) onYearChanged(y);
                },
              ),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(spacing: 6, runSpacing: 6, children: [
            FilterChip(
              label: const Text('All'),
              selected: quarter == null,
              onSelected: (s) {
                if (s) onQuarterChanged(null);
              },
            ),
            for (final q in ['Q1', 'Q2', 'Q3', 'Q4'])
              FilterChip(
                label: Text(q),
                selected: quarter == q,
                onSelected: (s) {
                  onQuarterChanged(s ? q : null);
                },
              ),
          ]),
        ),
      ]),
    ]);
  }

  Widget _eyebrow(BiTokens t, String s) => Text(s.toUpperCase(),
      style: TextStyle(fontSize: 10.5, letterSpacing: 0.5, fontWeight: FontWeight.w600, color: t.textMuted));
}
