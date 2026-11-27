import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_theme.dart';

enum MmInputSize { medium, large }

/// Standardized Medixmart Plus text input field matching Figma node `7:70`.
///
/// Supports Medium & Large padding, Default / Focused / Error / Disabled states
/// with brand and danger focus rings, optional leading/trailing slots, and
/// helper or validation error messages.
class MmInputField extends StatefulWidget {
  final Key? fieldKey;
  final String label;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final Widget? leadingIcon;
  final Widget? trailingIcon;
  final MmInputSize size;
  final bool enabled;
  final bool readOnly;
  final bool obscureText;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;

  const MmInputField({
    super.key,
    this.fieldKey,
    required this.label,
    this.hintText,
    this.helperText,
    this.errorText,
    this.controller,
    this.focusNode,
    this.leadingIcon,
    this.trailingIcon,
    this.size = MmInputSize.medium,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.maxLines = 1,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
  });

  @override
  State<MmInputField> createState() => _MmInputFieldState();
}

class _MmInputFieldState extends State<MmInputField> {
  FocusNode? _internalFocusNode;
  TextEditingController? _internalController;
  bool _isFocused = false;

  FocusNode get _effectiveFocusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  TextEditingController get _effectiveController =>
      widget.controller ?? (_internalController ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _effectiveFocusNode.addListener(_handleFocusChange);
    _isFocused = _effectiveFocusNode.hasFocus;
  }

  @override
  void didUpdateWidget(covariant MmInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _internalFocusNode)
          ?.removeListener(_handleFocusChange);
      _effectiveFocusNode.addListener(_handleFocusChange);
      _isFocused = _effectiveFocusNode.hasFocus;
    }
  }

  @override
  void dispose() {
    _effectiveFocusNode.removeListener(_handleFocusChange);
    _internalFocusNode?.dispose();
    _internalController?.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!mounted) return;
    setState(() {
      _isFocused = _effectiveFocusNode.hasFocus;
    });
  }

  EdgeInsetsGeometry get _padding {
    switch (widget.size) {
      case MmInputSize.medium:
        return const EdgeInsets.symmetric(
          horizontal: MmSpacing.md,
          vertical: MmSpacing.sm,
        );
      case MmInputSize.large:
        return const EdgeInsets.all(MmSpacing.md);
    }
  }

  static const List<BoxShadow> _brandFocusRing = [
    BoxShadow(
      color: Color(0x3849944F),
      offset: Offset.zero,
      blurRadius: 0,
      spreadRadius: 3,
    ),
    BoxShadow(
      color: Color(0x0F0F1729),
      offset: Offset(0, 2),
      blurRadius: 4,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> _dangerFocusRing = [
    BoxShadow(
      color: Color(0x38EE4655),
      offset: Offset.zero,
      blurRadius: 0,
      spreadRadius: 3,
    ),
    BoxShadow(
      color: Color(0x0F0F1729),
      offset: Offset(0, 2),
      blurRadius: 4,
      spreadRadius: 0,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      initialValue: _effectiveController.text,
      enabled: widget.enabled,
      validator: (value) {
        final currentText = _effectiveController.text;
        return widget.validator?.call(currentText);
      },
      builder: (fieldState) {
        final activeError = (widget.errorText != null &&
                widget.errorText!.trim().isNotEmpty)
            ? widget.errorText!.trim()
            : fieldState.errorText;
        final hasError = widget.enabled && activeError != null;

        final backgroundColor =
            widget.enabled ? MmColors.bgSurface : MmColors.bgSubtle;
        final borderColor = !widget.enabled
            ? MmColors.borderDefault
            : hasError
                ? MmColors.borderDanger
                : _isFocused
                    ? MmColors.borderBrand
                    : MmColors.borderDefault;
        final borderWidth =
            widget.enabled && (hasError || _isFocused) ? 1.5 : 1.0;
        final shadows = !widget.enabled
            ? const <BoxShadow>[]
            : hasError
                ? _dangerFocusRing
                : _isFocused
                    ? _brandFocusRing
                    : const <BoxShadow>[];

        final labelColor =
            widget.enabled ? MmColors.textPrimary : MmColors.textMuted;
        final textColor =
            widget.enabled ? MmColors.textPrimary : MmColors.textMuted;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.label,
              style: MmTypography.labelMedium.copyWith(color: labelColor),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              key: const Key('mm_input_box'),
              duration: const Duration(milliseconds: 120),
              padding: _padding,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(MmRadius.md),
                border: Border.all(
                  color: borderColor,
                  width: borderWidth,
                ),
                boxShadow: shadows,
              ),
              child: Row(
                crossAxisAlignment: widget.maxLines > 1
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
                children: [
                  if (widget.leadingIcon != null) ...[
                    widget.leadingIcon!,
                    const SizedBox(width: MmSpacing.sm),
                  ],
                  Expanded(
                    child: TextField(
                      key: widget.fieldKey,
                      controller: _effectiveController,
                      focusNode: _effectiveFocusNode,
                      enabled: widget.enabled,
                      readOnly: widget.readOnly,
                      obscureText: widget.obscureText,
                      maxLines: widget.obscureText ? 1 : widget.maxLines,
                      keyboardType: widget.keyboardType,
                      textInputAction: widget.textInputAction,
                      inputFormatters: widget.inputFormatters,
                      cursorColor: MmColors.bgBrand,
                      style: MmTypography.bodyMedium.copyWith(color: textColor),
                      onChanged: (value) {
                        fieldState.didChange(value);
                        widget.onChanged?.call(value);
                      },
                      onSubmitted: widget.onFieldSubmitted,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        hintText: widget.hintText,
                        hintStyle: MmTypography.bodyMedium.copyWith(
                          color: MmColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                  if (widget.trailingIcon != null) ...[
                    const SizedBox(width: MmSpacing.sm),
                    widget.trailingIcon!,
                  ],
                ],
              ),
            ),
            if (hasError) ...[
              const SizedBox(height: 6),
              Text(
                activeError,
                style: MmTypography.bodySmall.copyWith(
                  color: MmColors.textDanger,
                ),
              ),
            ] else if (widget.helperText != null &&
                widget.helperText!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                widget.helperText!,
                style: MmTypography.bodySmall.copyWith(
                  color: MmColors.textSecondary,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
