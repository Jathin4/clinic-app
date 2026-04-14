/// ═══════════════════════════════════════════════════════════════
///  app_widgets.dart  –  Aura Health Design System
///  "The Digital Sanctuary" – no borders, tonal depth, rounded everything
/// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

// ─── 1. THEME CONSTANTS ──────────────────────────────────────────────────────

class AppColors {
  // Brand (unchanged – same teal palette)
  static const teal = Color(0xFF0E6C68);
  static const teal2 = Color(0xFF14A3A0);
  static const tealDark = Color(0xFF0A5955);

  // Surfaces – tonal layers (no borders needed)
  static const background = Color(0xFFF8FAFA); // page bg
  static const surfaceLow = Color(0xFFF2F4F4); // section bg
  static const surfaceCard = Color(0xFFFFFFFF); // card / input
  static const surfaceHigh = Color(0xFFE6E8E9); // recessed info

  // Kept for legacy compat
  static const white = Colors.white;
  static const border = Color(0xFFE2E8F0);
  static const cardBorder = Color(0xFFF1F5F9);
  static const divider = Color(0xFFF1F5F9);

  // Text
  static const onSurface = Color(0xFF191C1D); // replaces pure black
  static const textPrimary = Color(0xFF1E293B);
  static const textSecondary = Color(0xFF64748B);
  static const textMuted = Color(0xFF94A3B8);
  static const textLabel = Color(0xFF334155);
  static const hintColor = Color(0xFFCBD5E1);

  // Status – foreground
  static const statusBlue = Color(0xFF3B82F6);
  static const statusGreen = Color(0xFF10B981);
  static const statusPurple = Color(0xFF8B5CF6);
  static const statusOrange = Color(0xFFF59E0B);
  static const statusRed = Color(0xFFEF4444);
  static const statusGray = Color(0xFF64748B);

  // Status – background
  static const statusBlueBg = Color(0xFFEFF6FF);
  static const statusGreenBg = Color(0xFFECFDF5);
  static const statusPurpleBg = Color(0xFFF5F3FF);
  static const statusOrangeBg = Color(0xFFFFFBEB);
  static const statusRedBg = Color(0xFFFEF2F2);
  static const statusGrayBg = Color(0xFFF1F5F9);

  // Error
  static const errorText = Color(0xFFDC2626);
  static const errorBg = Color(0xFFFFF1F2);
  static const errorBorder = Color(0xFFFECACA);
}

class AppTextStyles {
  static const pageTitle = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: AppColors.onSurface,
      letterSpacing: -0.3);
  static const pageSubtitle =
      TextStyle(fontSize: 13, color: AppColors.textMuted);
  static const sectionTitle = TextStyle(
      fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.onSurface);
  static const label = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppColors.textLabel,
      letterSpacing: 0.05);
  static const bodySmall =
      TextStyle(fontSize: 12, color: AppColors.textSecondary);
  static const bodyMuted = TextStyle(fontSize: 13, color: AppColors.textMuted);
  static const cardTitle = TextStyle(
      fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onSurface);
  static const hint = TextStyle(fontSize: 13, color: AppColors.hintColor);
}

// ─── 2. INPUT DECORATION ─────────────────────────────────────────────────────

class AppInput {
  static InputDecoration deco(
    String hint, {
    IconData? icon,
    Widget? suffixIcon,
    EdgeInsets? contentPadding,
  }) =>
      InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.hint,
        prefixIcon: icon != null
            ? Icon(icon, color: AppColors.textMuted, size: 18)
            : null,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.surfaceLow,
        contentPadding: contentPadding ??
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        // Ghost border – barely visible
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.border.withOpacity(0.4))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.border.withOpacity(0.4))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.teal, width: 1.5)),
      );
}

// ─── 3. BUTTON STYLES ────────────────────────────────────────────────────────

class AppButtonStyle {
  static ButtonStyle primary({double radius = 14}) => ElevatedButton.styleFrom(
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.textMuted,
        elevation: 0,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      );

  static ButtonStyle danger({double radius = 14}) => ElevatedButton.styleFrom(
        backgroundColor: AppColors.statusRed,
        foregroundColor: Colors.white,
        elevation: 0,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      );

  static ButtonStyle outlined({double radius = 14}) => OutlinedButton.styleFrom(
        side: BorderSide(color: AppColors.border.withOpacity(0.6)),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      );
}

// ─── 4. REUSABLE WIDGETS ─────────────────────────────────────────────────────

class AppPrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  final double height;
  final double radius;

  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.height = 52,
    this.radius = 14,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: height,
        child: ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: AppButtonStyle.primary(radius: radius),
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15)),
        ),
      );
}

class AppFormButtons extends StatelessWidget {
  final bool saving;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final String saveLabel;

  const AppFormButtons({
    super.key,
    required this.saving,
    required this.onCancel,
    required this.onSave,
    this.saveLabel = 'Save',
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 12, 20, MediaQuery.of(context).padding.bottom + 16),
        child: Row(children: [
          Expanded(
              child: OutlinedButton(
                  onPressed: onCancel,
                  style: AppButtonStyle.outlined(),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('Cancel',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ))),
          const SizedBox(width: 12),
          Expanded(
              child: ElevatedButton(
                  onPressed: saving ? null : onSave,
                  style: AppButtonStyle.primary(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(saveLabel,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                  ))),
        ]),
      );
}

/// Page header – no background border, uses surface tonal layering
class AppPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.surfaceCard,
        padding: EdgeInsets.fromLTRB(
            20, MediaQuery.of(context).padding.top + 14, 20, 14),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title, style: AppTextStyles.pageTitle),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!, style: AppTextStyles.pageSubtitle),
                ],
              ])),
          if (actionLabel != null && onAction != null)
            _GradientButton(
              label: actionLabel!,
              icon: actionIcon ?? Icons.add,
              onPressed: onAction!,
            ),
        ]),
      );
}

class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const _GradientButton(
      {required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [AppColors.teal, AppColors.teal2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

class AppSearchBar extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;

  const AppSearchBar({
    super.key,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: TextField(
          onChanged: onChanged,
          decoration: AppInput.deco(hint, icon: Icons.search),
        ),
      );
}

/// Stat card – no border, uses surfaceLow background
class AppStatCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final Color bg;
  final IconData icon;

  const AppStatCard({
    super.key,
    required this.label,
    required this.count,
    required this.color,
    required this.bg,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Expanded(
          child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF0E6C68).withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 4))
            ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: bg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 16, color: color)),
          const SizedBox(height: 10),
          Text(count.toString(),
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w700, color: color)),
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ]),
      ));
}

class AppStatsRow extends StatelessWidget {
  final List<AppStatData> stats;
  const AppStatsRow({super.key, required this.stats});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Row(
          children: [
            for (int i = 0; i < stats.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              AppStatCard(
                label: stats[i].label,
                count: stats[i].count,
                color: stats[i].color,
                bg: stats[i].bg,
                icon: stats[i].icon,
              ),
            ]
          ],
        ),
      );
}

class AppStatData {
  final String label;
  final int count;
  final Color color;
  final Color bg;
  final IconData icon;
  const AppStatData(this.label, this.count, this.color, this.bg, this.icon);
}

class AppLoadingView extends StatelessWidget {
  const AppLoadingView({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(color: AppColors.teal));
}

class AppEmptyView extends StatelessWidget {
  final String message;
  const AppEmptyView({super.key, this.message = 'No records found'});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
                color: AppColors.surfaceLow,
                borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.inbox_outlined,
                color: AppColors.textMuted, size: 28),
          ),
          const SizedBox(height: 12),
          Text(message, style: AppTextStyles.bodyMuted),
        ]),
      );
}

/// Error banner – soft red, no harsh border
class AppErrorBanner extends StatelessWidget {
  final String message;
  const AppErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppColors.errorBg, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.errorText, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: const TextStyle(
                      color: AppColors.errorText, fontSize: 13))),
        ]),
      );
}

/// Status badge – full roundness pill
class AppStatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;

  const AppStatusBadge({
    super.key,
    required this.label,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9999)),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      );
}

/// Sheet header – no harsh divider, uses spacing
class AppSheetHeader extends StatelessWidget {
  final String title;
  const AppSheetHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
        child: Row(children: [
          // Drag handle
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                      color: AppColors.surfaceLow,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text(title, style: AppTextStyles.sectionTitle),
            ]),
          ),
          GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                    color: AppColors.surfaceLow,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.close,
                    color: AppColors.textMuted, size: 16),
              )),
        ]),
      );
}

/// Labelled form field
class AppFormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final int maxLines;
  final void Function(String)? onChanged;

  const AppFormField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: AppTextStyles.label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLines: maxLines,
          onChanged: onChanged,
          decoration: AppInput.deco(hint ?? label, suffixIcon: suffixIcon),
        ),
      ]);
}

class AppDropdownField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const AppDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: AppTextStyles.label),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          isExpanded: true, // ← add this
          value: value,
          onChanged: onChanged,
          items: items,
          hint: Text('Select $label', style: AppTextStyles.hint),
          decoration: AppInput.deco(''),
        ),
      ]);
}

/// Card – no border, ambient shadow for lift
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF001F26).withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 6))
            ]),
        child: child,
      );
}

/// Gradient teal icon container
class AppGradientIcon extends StatelessWidget {
  final IconData icon;
  final double size;

  const AppGradientIcon({super.key, required this.icon, this.size = 40});

  @override
  Widget build(BuildContext context) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [AppColors.teal, AppColors.teal2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: Colors.white, size: size * 0.5));
}

// ─── 5. UTILITY FUNCTIONS ────────────────────────────────────────────────────

String fmtTime(String? v) {
  if (v == null || v.isEmpty) return '—';
  final parts = v.substring(0, 5).split(':');
  int h = int.parse(parts[0]);
  final m = parts[1];
  final ampm = h >= 12 ? 'PM' : 'AM';
  h = h % 12 == 0 ? 12 : h % 12;
  return '$h:$m $ampm';
}

String fmtDate(String? v) {
  if (v == null || v.isEmpty) return '—';
  final d = v.substring(0, 10).split('-');
  if (d.length != 3) return v;
  return '${d[2]}-${d[1]}-${d[0]}';
}

String fmtCurrency(dynamic val) {
  if (val == null) return '—';
  final num = double.tryParse(val.toString()) ?? 0;
  if (num >= 100000) return '₹${(num / 100000).toStringAsFixed(1)}L';
  return '₹${num.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
}

void showSnack(BuildContext context, String msg, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: isError ? AppColors.statusRed : AppColors.teal,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ));
}

Future<bool> confirmDelete(BuildContext context,
    {String title = 'Delete',
    String message = 'Are you sure you want to delete this record?'}) async {
  return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                title: Text(title),
                content: Text(message),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete',
                          style: TextStyle(color: AppColors.statusRed))),
                ],
              )) ??
      false;
}
