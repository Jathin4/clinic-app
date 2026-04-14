import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/app_widgets.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/sidebar.dart';
import '../widgets/top_nav.dart';
import 'appointments_screen.dart';
import 'bills_screen.dart';
import 'clinics_screen.dart';
import 'dashboard_screen.dart';
import 'encounters_screen.dart';
import 'inventory_screen.dart';
import 'patients_screen.dart';
import 'payments_screen.dart';
import 'placeholder_screen.dart';
import 'users_screen.dart';
import 'home_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  static const Color _navColor = Color(0xFF0D6B58);

  // Bottom nav tabs: 0=Home, 1=Profile, 2=Help
  int _selectedBottomIndex = 0;

  // null means "show HomeScreen grid", non-null means a sidebar item was tapped
  // We track this separately so Home tab always returns to grid
  String? _activeSidebarPage; // <-- NEW

  static const List<Map<String, dynamic>> _navItems = [
    {'iconName': 'Home', 'label': 'Home'},
    {'iconName': 'Profile', 'label': 'Profile'},
    {'iconName': 'Help', 'label': 'Help'},
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: _navColor,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  /// Maps page string → actual screen widget
  Widget _screenForPage(String page) {
    switch (page) {
      case 'dashboard':
        return const DashboardScreen();
      case 'clinics':
        return const ClinicsScreen();
      case 'users':
        return const UsersScreen();
      case 'patients':
        return const PatientsScreen();
      case 'appointments':
        return const AppointmentsScreen();
      case 'encounters':
        return const EncountersScreen();
      case 'bills':
        return const BillsScreen();
      case 'payments':
        return const PaymentsScreen();
      case 'inventory':
        return const InventoryScreen();
      case 'reports':
        return const PlaceholderScreen(
            title: 'Reports', icon: Icons.bar_chart_outlined);
      case 'settings':
        return const PlaceholderScreen(
            title: 'Settings', icon: Icons.settings_outlined);
      case 'my-profile':
        return const PlaceholderScreen(
            title: 'My Profile', icon: Icons.person_outline);
      default:
        return const PlaceholderScreen(
            title: 'Not Found', icon: Icons.error_outline);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final isMobile = !isDesktop;

    // ── Mobile body logic ──────────────────────────────────────
    // If a sidebar item was tapped → show that screen with a back button
    // Otherwise → show the bottom-tab content
    Widget mainContent;
    if (_selectedBottomIndex == 0) {
      if (_activeSidebarPage != null) {
        // Show the sidebar-selected screen with a back arrow
        mainContent = _ScreenWithBack(
          title: _pageTitleFor(_activeSidebarPage!),
          child: _screenForPage(_activeSidebarPage!),
          onBack: () {
            setState(() => _activeSidebarPage = null);
            // Also clear the active highlight in the sidebar
            provider.setPage(''); // blank = nothing highlighted
          },
        );
      } else {
        mainContent = HomeScreen(
          onTabChange: (i) => setState(() => _selectedBottomIndex = i),
          onNavigate: (pageId) {
            setState(() => _activeSidebarPage = pageId);
            context.read<AppProvider>().setPage(pageId);
          },
        );
      }
    } else if (_selectedBottomIndex == 1) {
      mainContent = const PlaceholderScreen(
          title: 'My Profile', icon: Icons.person_outline);
    } else {
      mainContent = const PlaceholderScreen(
          title: 'Help', icon: Icons.headset_mic_outlined);
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: _navColor,
        statusBarIconBrightness: Brightness.light,
      ),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          // If a sidebar screen is open, go back instead of exiting
          if (_activeSidebarPage != null) {
            setState(() => _activeSidebarPage = null);
            provider.setPage('');
            return;
          }
          showCupertinoDialog(
            context: context,
            builder: (ctx) => CupertinoAlertDialog(
              title: const Text('Exit App'),
              content: const Text('Do you really want to exit?'),
              actions: [
                CupertinoDialogAction(
                  child: const Text('No'),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
                CupertinoDialogAction(
                  isDestructiveAction: true,
                  child: const Text('Yes'),
                  onPressed: () => SystemNavigator.pop(),
                ),
              ],
            ),
          );
        },
        child: Stack(
          children: [
            Scaffold(
              backgroundColor: Colors.white,
              body: SafeArea(
                // <-- FIX 1: wraps entire body so status bar is respected
                child: isMobile
                    ? Stack(
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: KeyedSubtree(
                              key: ValueKey(
                                _activeSidebarPage ??
                                    'tab$_selectedBottomIndex',
                              ),
                              child: mainContent,
                            ),
                          ),
                          LoadingOverlay(
                            isLoading: provider.isLoading,
                            message: provider.loadingMessage,
                            type: provider.page,
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          const Sidebar(),
                          Expanded(
                            child: Column(
                              children: [
                                const TopNav(),
                                Expanded(
                                  child: Stack(
                                    children: [
                                      AnimatedSwitcher(
                                        duration:
                                            const Duration(milliseconds: 220),
                                        child: KeyedSubtree(
                                          key: ValueKey(provider.page),
                                          child: _screenForPage(provider.page),
                                        ),
                                      ),
                                      LoadingOverlay(
                                        isLoading: provider.isLoading,
                                        message: provider.loadingMessage,
                                        type: provider.page,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
              bottomNavigationBar: isMobile && _activeSidebarPage == null
                  ? SafeArea(
                      bottom: true,
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 16),
                        decoration: BoxDecoration(
                          color: _navColor,
                          borderRadius: BorderRadius.circular(40),
                          boxShadow: const [
                            BoxShadow(
                              color: Color.fromRGBO(0, 0, 0, 0.2),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: List.generate(
                            _navItems.length,
                            (i) => _buildNavItem(
                              _navItems[i]['iconName'] as String,
                              _navItems[i]['label'] as String,
                              i,
                            ),
                          ),
                        ),
                      ),
                    )
                  : null,
            ),

            // ── Mobile sidebar overlay ─────────────────────────
            if (isMobile && provider.mobileSidebar) ...[
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => provider.setMobileSidebar(false),
                  child: Container(color: Colors.black54),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                bottom: 0,
                width: 280,
                child: Material(
                  elevation: 16,
                  child: Sidebar(
                    onItemTapped: (String pageId) {
                      // FIX 3 & 4: actually navigate + switch to Home tab
                      provider.setMobileSidebar(false);
                      provider.setPage(pageId);
                      setState(() {
                        _selectedBottomIndex = 0;
                        _activeSidebarPage = pageId; // <-- drives the screen
                      });
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Human-readable title for a page id
  String _pageTitleFor(String page) {
    const titles = {
      'dashboard': 'Dashboard',
      'clinics': 'Clinics',
      'users': 'Users',
      'patients': 'Patients',
      'appointments': 'Appointments',
      'encounters': 'Encounters',
      'bills': 'Bills',
      'payments': 'Payments',
      'inventory': 'Inventory',
      'reports': 'Reports',
      'settings': 'Settings',
      'my-profile': 'My Profile',
    };
    return titles[page] ?? 'Screen';
  }

  Widget _buildNavItem(String iconName, String label, int index) {
    final isSelected = _selectedBottomIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _selectedBottomIndex = index;
            // Tapping Home tab clears any open sidebar screen
            if (index == 0) {
              _activeSidebarPage = null;
              provider_setPageBlank(context);
            }
          });
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _navIcon(iconName),
              color: isSelected ? Colors.white : Colors.white70,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void provider_setPageBlank(BuildContext context) {
    context.read<AppProvider>().setPage('');
  }

  IconData _navIcon(String iconName) {
    switch (iconName) {
      case 'Home':
        return Icons.home;
      case 'Profile':
        return Icons.person_outline;
      case 'Help':
        return Icons.headset_mic_outlined;
      default:
        return Icons.circle;
    }
  }
}

// ── Back-button wrapper ────────────────────────────────────────
class _ScreenWithBack extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback onBack;
  const _ScreenWithBack(
      {required this.title, required this.child, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top bar with back arrow
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: Color(0xFF0E6C68)),
                onPressed: onBack,
              ),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF191C1D),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
