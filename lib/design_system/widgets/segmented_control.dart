import 'package:flutter/material.dart';
import '../tokens.dart';

/// iOS-style segmented control for tab-like selection
/// Commonly used for mode switching (e.g., Public/Private races)
class SegmentedControl<T> extends StatefulWidget {
  final List<SegmentOption<T>> options;
  final T selectedValue;
  final ValueChanged<T> onChanged;
  final Color? selectedColor;
  final Color? unselectedColor;
  final Color? backgroundColor;
  final double? height;
  final EdgeInsetsGeometry? padding;

  const SegmentedControl({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onChanged,
    this.selectedColor,
    this.unselectedColor,
    this.backgroundColor,
    this.height,
    this.padding,
  });

  @override
  State<SegmentedControl<T>> createState() => _SegmentedControlState<T>();
}

class _SegmentedControlState<T> extends State<SegmentedControl<T>>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  int _previousIndex = 0;

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.options.indexWhere(
      (option) => option.value == widget.selectedValue,
    );

    _controller = AnimationController(
      duration: DesignTokens.durationMedium,
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: _previousIndex.toDouble(),
      end: _previousIndex.toDouble(),
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: DesignTokens.curveEmphasized,
      ),
    );
  }

  @override
  void didUpdateWidget(SegmentedControl<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newIndex = widget.options.indexWhere(
      (option) => option.value == widget.selectedValue,
    );

    if (newIndex != _previousIndex && newIndex != -1) {
      _slideAnimation = Tween<double>(
        begin: _previousIndex.toDouble(),
        end: newIndex.toDouble(),
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: DesignTokens.curveEmphasized,
        ),
      );

      _previousIndex = newIndex;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height ?? 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? DesignTokens.surfaceElevated,
        borderRadius: DesignTokens.borderRadiusFull,
      ),
      child: Stack(
        children: [
          // Sliding indicator
          AnimatedBuilder(
            animation: _slideAnimation,
            builder: (context, child) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  final segmentWidth = constraints.maxWidth / widget.options.length;
                  final offset = segmentWidth * _slideAnimation.value;

                  return Transform.translate(
                    offset: Offset(offset, 0),
                    child: Container(
                      width: segmentWidth,
                      decoration: BoxDecoration(
                        color: widget.selectedColor ?? DesignTokens.primaryRed,
                        borderRadius: DesignTokens.borderRadiusFull,
                        boxShadow: DesignTokens.shadowLevel2,
                      ),
                    ),
                  );
                },
              );
            },
          ),

          // Options
          Row(
            children: widget.options.map((option) {
              final isSelected = option.value == widget.selectedValue;
              return Expanded(
                child: _SegmentButton<T>(
                  option: option,
                  isSelected: isSelected,
                  onTap: () => widget.onChanged(option.value),
                  selectedColor: widget.selectedColor,
                  unselectedColor: widget.unselectedColor,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Individual segment button
class _SegmentButton<T> extends StatelessWidget {
  final SegmentOption<T> option;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? selectedColor;
  final Color? unselectedColor;

  const _SegmentButton({
    required this.option,
    required this.isSelected,
    required this.onTap,
    this.selectedColor,
    this.unselectedColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (option.icon != null) ...[
              Icon(
                option.icon,
                size: 18,
                color: isSelected
                    ? DesignTokens.white
                    : (unselectedColor ?? DesignTokens.textSecondary),
              ),
              if (option.label != null) const SizedBox(width: 6),
            ],
            if (option.label != null)
              Text(
                option.label!,
                style: DesignTokens.bodyMedium.copyWith(
                  fontWeight: isSelected
                      ? DesignTokens.weightSemiBold
                      : DesignTokens.weightMedium,
                  color: isSelected
                      ? DesignTokens.white
                      : (unselectedColor ?? DesignTokens.textSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Option for segmented control
class SegmentOption<T> {
  final T value;
  final String? label;
  final IconData? icon;

  const SegmentOption({
    required this.value,
    this.label,
    this.icon,
  }) : assert(label != null || icon != null, 'Either label or icon must be provided');
}

/// Tab-style segmented control (alternative design)
class TabSegmentedControl<T> extends StatelessWidget {
  final List<SegmentOption<T>> options;
  final T selectedValue;
  final ValueChanged<T> onChanged;
  final Color? selectedColor;
  final Color? indicatorColor;

  const TabSegmentedControl({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onChanged,
    this.selectedColor,
    this.indicatorColor,
  });

  @override
  Widget build(BuildContext context) {
    final selectedIndex = options.indexWhere(
      (option) => option.value == selectedValue,
    );

    return Container(
      height: 48,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: DesignTokens.textTertiary.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: options.asMap().entries.map((entry) {
          final index = entry.key;
          final option = entry.value;
          final isSelected = index == selectedIndex;

          return Expanded(
            child: _TabButton<T>(
              option: option,
              isSelected: isSelected,
              onTap: () => onChanged(option.value),
              selectedColor: selectedColor,
              indicatorColor: indicatorColor,
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Individual tab button
class _TabButton<T> extends StatelessWidget {
  final SegmentOption<T> option;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? selectedColor;
  final Color? indicatorColor;

  const _TabButton({
    required this.option,
    required this.isSelected,
    required this.onTap,
    this.selectedColor,
    this.indicatorColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: isSelected
              ? Border(
                  bottom: BorderSide(
                    color: indicatorColor ?? DesignTokens.primaryRed,
                    width: 3,
                  ),
                )
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (option.icon != null) ...[
              Icon(
                option.icon,
                size: 20,
                color: isSelected
                    ? (selectedColor ?? DesignTokens.primaryRed)
                    : DesignTokens.textSecondary,
              ),
              if (option.label != null) const SizedBox(width: 8),
            ],
            if (option.label != null)
              Text(
                option.label!,
                style: DesignTokens.bodyMedium.copyWith(
                  fontWeight: isSelected
                      ? DesignTokens.weightSemiBold
                      : DesignTokens.weightMedium,
                  color: isSelected
                      ? (selectedColor ?? DesignTokens.primaryRed)
                      : DesignTokens.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Chip-style segmented control (alternative design)
class ChipSegmentedControl<T> extends StatelessWidget {
  final List<SegmentOption<T>> options;
  final T selectedValue;
  final ValueChanged<T> onChanged;
  final Color? selectedColor;
  final double spacing;

  const ChipSegmentedControl({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onChanged,
    this.selectedColor,
    this.spacing = DesignTokens.space8,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: options.map((option) {
        final isSelected = option.value == selectedValue;
        return _ChipButton<T>(
          option: option,
          isSelected: isSelected,
          onTap: () => onChanged(option.value),
          selectedColor: selectedColor,
        );
      }).toList(),
    );
  }
}

/// Individual chip button
class _ChipButton<T> extends StatelessWidget {
  final SegmentOption<T> option;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? selectedColor;

  const _ChipButton({
    required this.option,
    required this.isSelected,
    required this.onTap,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: DesignTokens.borderRadiusFull,
      child: AnimatedContainer(
        duration: DesignTokens.durationFast,
        curve: DesignTokens.curveDefault,
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.space16,
          vertical: DesignTokens.space8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? (selectedColor ?? DesignTokens.primaryRed)
              : DesignTokens.surfaceElevated,
          borderRadius: DesignTokens.borderRadiusFull,
          border: isSelected
              ? null
              : Border.all(
                  color: DesignTokens.textTertiary.withOpacity(0.3),
                ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (option.icon != null) ...[
              Icon(
                option.icon,
                size: 18,
                color: isSelected
                    ? DesignTokens.white
                    : DesignTokens.textSecondary,
              ),
              if (option.label != null) const SizedBox(width: 6),
            ],
            if (option.label != null)
              Text(
                option.label!,
                style: DesignTokens.bodySmall.copyWith(
                  fontWeight: isSelected
                      ? DesignTokens.weightSemiBold
                      : DesignTokens.weightMedium,
                  color: isSelected
                      ? DesignTokens.white
                      : DesignTokens.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
