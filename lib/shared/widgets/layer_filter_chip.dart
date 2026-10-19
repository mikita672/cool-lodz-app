import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Map layer toggle (Cień, Zieleń, Woda…): off / on, always with an icon.
class LayerFilterChip extends StatelessWidget {
  const LayerFilterChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.onPrimary : AppColors.onSurface;
    return FilterChip(
      label: Text(label),
      labelStyle: AppTextStyles.label.copyWith(color: foreground),
      avatar: Icon(
        icon,
        size: 18,
        color: selected ? AppColors.onPrimary : AppColors.primary,
      ),
      selected: selected,
      showCheckmark: false,
      onSelected: onSelected,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}
