import 'package:flutter/material.dart';

// Generic placeholder screen used until real screens are built
class PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  const PlaceholderScreen({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: const Color(0xFFE6F4F3), borderRadius: BorderRadius.circular(20)),
            child: Icon(icon, size: 40, color: const Color(0xFF0E6C68)),
          ),
          const SizedBox(height: 20),
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          const SizedBox(height: 8),
          const Text('This screen is under development', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
        ],
      ),
    );
  }
}