import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'sidebar.dart';

class TopNav extends StatelessWidget {
  const TopNav({super.key});

  @override
  Widget build(BuildContext context) {
    final provider  = context.watch<AppProvider>();
    final role      = provider.user?['role'] ?? Roles.admin;
    final sections  = getVisibleSections(role);
    final allItems  = sections.expand((s) => s.items).toList();
    final current   = allItems.where((i) => i.id == provider.page).firstOrNull;
    final pageTitle = current?.label ?? 'Dashboard';

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      // Subtle background, no hard border
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E6C68).withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          // Mobile hamburger
          if (MediaQuery.of(context).size.width < 1024)
            GestureDetector(
              onTap: () => provider.setMobileSidebar(true),
              child: Container(
                width: 36,
                height: 36,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F4F4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.menu,
                    color: Color(0xFF0E6C68), size: 18),
              ),
            ),

          Text(pageTitle,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF191C1D))),
          const Spacer(),

          // Clinic badge
          if (provider.user?['clinic_name'] != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(9999),
              ),
              child: Text(provider.user!['clinic_name'],
                  style: const TextStyle(
                      color: Color(0xFF0E6C68),
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ),

          const SizedBox(width: 10),

          // Profile menu
          PopupMenuButton<String>(
            offset: const Offset(0, 46),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F4F4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person_outline,
                  color: Color(0xFF64748B), size: 18),
            ),
            onSelected: (val) {
              if (val == 'logout') provider.handleLogout();
              if (val == 'profile') provider.setPage('my-profile');
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: 'profile',
                  child: Row(children: [
                    const Icon(Icons.person_outline, size: 16),
                    const SizedBox(width: 10),
                    Text(provider.user?['full_name'] ?? 'Profile')
                  ])),
              const PopupMenuItem(
                  value: 'logout',
                  child: Row(children: [
                    Icon(Icons.logout, size: 16, color: Colors.red),
                    SizedBox(width: 10),
                    Text('Logout',
                        style: TextStyle(color: Colors.red))
                  ])),
            ],
          ),
        ],
      ),
    );
  }
}
