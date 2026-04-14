import 'package:clinic_frontend/screens/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';
import 'patients_screen.dart';
import 'appointments_screen.dart';
import 'encounters_screen.dart';
import 'bills_screen.dart';
import 'payments_screen.dart';
import 'inventory_screen.dart';
import 'clinics_screen.dart';
import 'placeholder_screen.dart';

class HomeScreen extends StatelessWidget {
  final void Function(int) onTabChange;
  final void Function(String pageId)? onNavigate; // ADD THIS
  const HomeScreen({super.key, required this.onTabChange, this.onNavigate});

  static const List<Map<String, dynamic>> _items = [
    {
      'title': 'Patients',
      'iconName': 'Patient',
      'color': Color(0xFF0E6C68),
      'bg': Color(0xFFECFDF5)
    },
    {
      'title': 'Appointments',
      'iconName': 'Calendar',
      'color': Color(0xFF3B82F6),
      'bg': Color(0xFFEFF6FF)
    },
    {
      'title': 'Encounters',
      'iconName': 'Encounter',
      'color': Color(0xFFF59E0B),
      'bg': Color(0xFFFFFBEB)
    },
    {
      'title': 'Bills',
      'iconName': 'Bill',
      'color': Color(0xFF8B5CF6),
      'bg': Color(0xFFF5F3FF)
    },
    {
      'title': 'Payments',
      'iconName': 'Payment',
      'color': Color(0xFF10B981),
      'bg': Color(0xFFECFDF5)
    },
    {
      'title': 'Inventory',
      'iconName': 'Inventory',
      'color': Color(0xFF3B82F6),
      'bg': Color(0xFFEFF6FF)
    },
    {
      'title': 'Clinics',
      'iconName': 'Clinic',
      'color': Color(0xFFEF4444),
      'bg': Color(0xFFFEF2F2)
    },
    {
      'title': 'Dashboard',
      'iconName': 'Dashboard',
      'color': Color(0xFF0E6C68),
      'bg': Color(0xFFECFDF5)
    },
  ];

  Widget _screenFor(String title) {
    switch (title) {
      case 'Patients':
        return const PatientsScreen();
      case 'Appointments':
        return const AppointmentsScreen();
      case 'Encounters':
        return const EncountersScreen();
      case 'Bills':
        return const BillsScreen();
      case 'Payments':
        return const PaymentsScreen();
      case 'Inventory':
        return const InventoryScreen();
      case 'Clinics':
        return const ClinicsScreen();
      case 'Dashboard':
        return const DashboardScreen();
      default:
        return PlaceholderScreen(title: title, icon: Icons.hourglass_empty);
    }
  }

  String _pageIdFor(String title) {
  switch (title) {
    case 'Patients':      return 'patients';
    case 'Appointments':  return 'appointments';
    case 'Encounters':    return 'encounters';
    case 'Bills':         return 'bills';
    case 'Payments':      return 'payments';
    case 'Inventory':     return 'inventory';
    case 'Clinics':       return 'clinics';
    case 'Dashboard':     return 'dashboard';
    default:              return title.toLowerCase();
  }
}

  void _push(BuildContext context, String title) {
  if (onNavigate != null) {
    onNavigate!(_pageIdFor(title));
  } else {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => _screenFor(title)));
  }
}

  Future<void> _showLogoutDialog(BuildContext context) async {
    final provider = context.read<AppProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Do you want to logout now?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Logout')),
        ],
      ),
    );
    if (confirmed == true) {
      provider.handleLogout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppProvider>().user;
    final name = user?['full_name'] ?? user?['name'] ?? 'back';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(children: [
        // ── Header with gradient ──────────────────────────────
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.tealDark, AppColors.teal],
              
            ),
          ),
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 18,
            left: 20,
            right: 20,
            bottom: 24,
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              // Hamburger menu
              GestureDetector(
                onTap: () => context.read<AppProvider>().setMobileSidebar(true),
                child: Container(
                  width: 36,
                  height: 36,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.menu, color: Colors.white, size: 20),
                ),
              ),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('ClinicOS',
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.0)),
                    const SizedBox(height: 4),
                    Text('Welcome, $name',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3)),
                  ])),
              GestureDetector(
                onTap: () => _showLogoutDialog(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.logout, size: 15, color: Colors.white),
                    SizedBox(width: 6),
                    Text('Logout',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ]),
          ]),
        ),

        // ── Grid ─────────────────────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              itemCount: _items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.95,
              ),
              itemBuilder: (context, index) {
                final item = _items[index];
                final title = item['title'] as String;
                return _HomeCard(
                  title: title,
                  iconName: item['iconName'] as String,
                  bgColor: item['bg'] as Color,
                  iconColor: item['color'] as Color,
                  onTap: () => _push(context, title),
                );
              },
            ),
          ),
        ),
      ]),
    );
  }
}

class _HomeCard extends StatelessWidget {
  final String title;
  final String iconName;
  final Color bgColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _HomeCard({
    required this.title,
    required this.iconName,
    required this.bgColor,
    required this.iconColor,
    required this.onTap,
  });

  IconData _iconFor(String iconName) {
    switch (iconName) {
      case 'Patient':
        return Icons.person_outline;
      case 'Calendar':
        return Icons.calendar_today;
      case 'Encounter':
        return Icons.medical_information_outlined;
      case 'Bill':
        return Icons.receipt_long;
      case 'Payment':
        return Icons.payment;
      case 'Inventory':
        return Icons.inventory_2_outlined;
      case 'Clinic':
        return Icons.local_hospital_outlined;
      case 'Dashboard':
        return Icons.dashboard;

      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 31, 38, 0.05),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Icon(
                _iconFor(iconName),
                color: iconColor,
                size: 26,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
      ),
    );
  }
}
