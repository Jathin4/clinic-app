import 'package:flutter/material.dart';

/// Loading overlay widget that covers the whole screen.
///
/// Uses built-in Flutter icons for loading states.
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final String message;
  final String type;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    this.message = 'Loading...',
    this.type = 'default',
  });

  static const Map<String, IconData> _iconMap = {
    'default': Icons.favorite,
    'patients': Icons.person_outline,
    'appointments': Icons.calendar_today,
    'encounters': Icons.medical_information_outlined,
    'prescriptions': Icons.medical_services_outlined,
    'reports': Icons.bar_chart_outlined,
    'users': Icons.person,
    'billing': Icons.receipt_long,
    'clinics': Icons.local_hospital_outlined,
    'payments': Icons.wallet,
    'inventory': Icons.inventory_2_outlined,
    'my-profile': Icons.account_circle_outlined,
  };

  @override
  Widget build(BuildContext context) {
    if (!isLoading) return const SizedBox.shrink();

    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            color: const Color.fromRGBO(0, 0, 0, 0.30),
          ),
        ),
        Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.15),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: Icon(
                      _iconMap[type] ?? _iconMap['default']!,
                      color: const Color(0xFF0E6C68),
                      size: 48,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF334155),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
