import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

// ── Role constants ─────────────────────────────────────────────
class Roles {
  static const admin = 'Admin';
  static const doctor = 'Doctor';
  static const receptionist = 'Receptionist';
  static const pharmacist = 'Pharmacist';
  static const diagnosist = 'Diagnosist';
  static const all = [admin, doctor, receptionist, pharmacist, diagnosist];
}

class NavItem {
  final String id;
  final String label;
  final IconData icon;
  final List<String> roles;
  const NavItem(
      {required this.id,
      required this.label,
      required this.icon,
      required this.roles});
}

class NavSection {
  final String? section;
  final List<String>? roles;
  final List<NavItem> items;
  const NavSection({this.section, this.roles, required this.items});
}

final List<NavSection> sidebarSections = [
  NavSection(section: null, items: [
    NavItem(
        id: 'dashboard',
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        roles: Roles.all),
  ]),
  NavSection(section: 'Clinic Management', roles: [
    Roles.admin
  ], items: [
    NavItem(
        id: 'clinics',
        label: 'Clinics',
        icon: Icons.local_hospital_outlined,
        roles: [Roles.admin]),
    NavItem(
        id: 'users',
        label: 'Users',
        icon: Icons.people_outline,
        roles: [Roles.admin]),
  ]),
  NavSection(section: 'Patient Management', roles: Roles.all, items: [
    NavItem(
        id: 'patients',
        label: 'Patients',
        icon: Icons.person_outline,
        roles: Roles.all),
    NavItem(
        id: 'appointments',
        label: 'Appointments',
        icon: Icons.calendar_month_outlined,
        roles: Roles.all),
    NavItem(
        id: 'encounters',
        label: 'Encounters',
        icon: Icons.medical_services_outlined,
        roles: Roles.all),
  ]),
  NavSection(section: 'Billing', roles: [
    Roles.admin,
    Roles.pharmacist,
    Roles.diagnosist
  ], items: [
    NavItem(
        id: 'bills',
        label: 'Bills',
        icon: Icons.receipt_long_outlined,
        roles: [Roles.admin, Roles.pharmacist, Roles.diagnosist]),
    NavItem(
        id: 'payments',
        label: 'Payments',
        icon: Icons.payment_outlined,
        roles: [Roles.admin, Roles.pharmacist, Roles.diagnosist]),
  ]),
  NavSection(section: 'Inventory', roles: [
    Roles.admin,
    Roles.pharmacist
  ], items: [
    NavItem(
        id: 'inventory',
        label: 'Inventory',
        icon: Icons.inventory_2_outlined,
        roles: [Roles.admin, Roles.pharmacist]),
  ]),
  NavSection(section: 'Reports', roles: [
    Roles.admin,
    Roles.diagnosist
  ], items: [
    NavItem(
        id: 'reports',
        label: 'Reports',
        icon: Icons.bar_chart_outlined,
        roles: [Roles.admin, Roles.diagnosist]),
  ]),
  NavSection(section: 'Settings', roles: [
    Roles.admin
  ], items: [
    NavItem(
        id: 'settings',
        label: 'Settings',
        icon: Icons.settings_outlined,
        roles: [Roles.admin]),
  ]),
];

List<NavSection> getVisibleSections(String role) {
  return sidebarSections
      .where((s) => s.roles == null || s.roles!.contains(role))
      .map((s) => NavSection(
            section: s.section,
            roles: s.roles,
            items: s.items.where((i) => i.roles.contains(role)).toList(),
          ))
      .where((s) => s.items.isNotEmpty)
      .toList();
}

// ── Design tokens ──────────────────────────────────────────────
const _sidebarBg = Color(0xFF0A5955); // tealDark
const _sidebarWidth = 256.0;
const _collapsedWidth = 68.0;

class Sidebar extends StatelessWidget {
  final VoidCallback? onItemTapped;
  const Sidebar({super.key, this.onItemTapped});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final collapsed = provider.collapsed;
    final role = provider.user?['role'] ?? Roles.admin;
    final sections = getVisibleSections(role);
    final fullName = provider.user?['full_name'] ?? 'User';
    final initials = _initials(fullName);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: collapsed ? _collapsedWidth : _sidebarWidth,
      decoration: const BoxDecoration(
        color: _sidebarBg,
      ),
      child: Column(
        children: [
          _SidebarHeader(collapsed: collapsed),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              children: sections
                  .map((g) => _SectionGroup(
                        group: g,
                        collapsed: collapsed,
                        onItemTapped: onItemTapped,
                      ))
                  .toList(),
            ),
          ),
          _UserCard(
              collapsed: collapsed,
              fullName: fullName,
              initials: initials,
              role: role),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.split(' ').where((w) => w.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

class _SidebarHeader extends StatelessWidget {
  final bool collapsed;
  const _SidebarHeader({required this.collapsed});

  // In _SidebarHeader build(), REPLACE with:
  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final isMobile = MediaQuery.of(context).size.width < 1024;

    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.favorite_border,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          const Text('ClinicOS',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const Spacer(),
          // Only show collapse arrow on desktop
          if (!isMobile)
            GestureDetector(
              onTap: () => provider.setCollapsed(!collapsed),
              child: const Icon(Icons.chevron_left,
                  color: Colors.white38, size: 20),
            )
          else
            GestureDetector(
              onTap: () => provider.setMobileSidebar(false),
              child: const Icon(Icons.close, color: Colors.white38, size: 20),
            ),
        ],
      ),
    );
  }
}

class _SectionGroup extends StatelessWidget {
  final VoidCallback? onItemTapped; // ADD
  final NavSection group;
  final bool collapsed;
  const _SectionGroup(
      {required this.group, required this.collapsed, this.onItemTapped});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (group.section != null && !collapsed)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
            child: Text(
              group.section!.toUpperCase(),
              style: const TextStyle(
                  color: Colors.white30,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2),
            ),
          ),
        ...group.items.map((item) => _NavButton(
              item: item,
              collapsed: collapsed,
              onItemTapped: onItemTapped,
            )),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  final VoidCallback? onItemTapped;
  final NavItem item;
  final bool collapsed;
  const _NavButton(
      {required this.item, required this.collapsed, this.onItemTapped});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final active = provider.page == item.id;

    return Tooltip(
      message: collapsed ? item.label : '',
      preferBelow: false,
      child: GestureDetector(
        onTap: () {
          provider.setPage(item.id);
          provider.setMobileSidebar(false);
          onItemTapped?.call();
          // notify MainLayout to switch to Home tab
          // find the Sidebar's onItemTapped via context or pass it down
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 0 : 12, vertical: 10),
          decoration: BoxDecoration(
            // Glassmorphic overlay for active state
            color: active ? Colors.white.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment:
                collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(item.icon,
                  color: active ? Colors.white : Colors.white60, size: 20),
              if (!collapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                    child: Text(item.label,
                        style: TextStyle(
                            color: active ? Colors.white : Colors.white70,
                            fontSize: 14,
                            fontWeight:
                                active ? FontWeight.w600 : FontWeight.w400))),
                if (active)
                  Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final bool collapsed;
  final String fullName;
  final String initials;
  final String role;
  const _UserCard(
      {required this.collapsed,
      required this.fullName,
      required this.initials,
      required this.role});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.15)),
      child: collapsed
          ? Center(
              child: GestureDetector(
                onTap: () => provider.setPage('my-profile'),
                child: CircleAvatar(
                    backgroundColor: Colors.white24,
                    radius: 18,
                    child: Text(initials,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold))),
              ),
            )
          : GestureDetector(
              onTap: () => provider.setPage('my-profile'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    CircleAvatar(
                        backgroundColor: Colors.white24,
                        radius: 16,
                        child: Text(initials,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fullName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis),
                          Text(role,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        color: Colors.white30, size: 16),
                  ],
                ),
              ),
            ),
    );
  }
}
