import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fat_burner/theme/app_colors.dart';

class AppTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final TextEditingController? controller;
  final TextInputAction? textInputAction;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool isPremiumWhite;
  final int? maxLength;

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.textInputAction,
    this.obscureText = false,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.controller,
    this.prefixIcon,
    this.suffixIcon,
    this.isPremiumWhite = false,
    this.maxLength,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            color: _isFocused ? AppColors.accent : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: _isFocused ? FontWeight.w600 : FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: widget.isPremiumWhite 
                ? (isDark ? AppColors.surfaceElevatedDk.withOpacity(0.4) : Colors.white)
                : (isDark ? AppColors.surfaceElevatedDk.withOpacity(0.4) : AppColors.surfaceElevated),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isPremiumWhite
                  ? (_isFocused ? AppColors.accent : (isDark ? Colors.white54 : Colors.black))
                  : (_isFocused ? AppColors.accent : Colors.transparent),
              width: widget.isPremiumWhite ? (_isFocused ? 2.0 : 1.5) : 1.0,
            ),
            boxShadow: [
              if (_isFocused)
                BoxShadow(
                  color: AppColors.accent.withOpacity(0.15),
                  blurRadius: 15,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                )
              else
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                )
            ],
          ),
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            inputFormatters: widget.inputFormatters,
            validator: widget.validator,
            onChanged: widget.onChanged,
            maxLength: widget.maxLength,
            buildCounter: (context, {required currentLength, required isFocused, required maxLength}) => null,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
              filled: true,
              fillColor: Colors.transparent, // Fixes the beige override from global theme
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              prefixIcon: widget.prefixIcon != null
                  ? Icon(
                      widget.prefixIcon, 
                      color: _isFocused ? AppColors.accent : AppColors.textSecondary, 
                      size: 22
                    )
                  : null,
              suffixIcon: widget.suffixIcon,
            ),
          ),
        ),
      ],
    );
  }
}
