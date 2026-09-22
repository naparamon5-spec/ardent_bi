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
