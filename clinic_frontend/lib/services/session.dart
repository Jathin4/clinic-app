import 'package:shared_preferences/shared_preferences.dart';

class Session {
  static int? clinicId;
  static int? userId;
  static String? role;

  // Called after login — saves to memory AND disk
  static Future<void> setFromLoginResponse(Map<String, dynamic> data) async {
    clinicId = data['clinic_id'];
    userId   = data['user_id'];
    role     = data['role'];

    final prefs = await SharedPreferences.getInstance();
    if (clinicId != null) await prefs.setInt('clinic_id', clinicId!);
    if (userId != null)   await prefs.setInt('user_id', userId!);
    if (role != null)     await prefs.setString('role', role!);
  }

  // Called on app launch — restores session from disk
  static Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    clinicId = prefs.getInt('clinic_id');
    userId   = prefs.getInt('user_id');
    role     = prefs.getString('role');
  }

  static bool isValid() =>
      clinicId != null && userId != null && role != null;

  // Called on logout — clears memory AND disk
  static Future<void> clear() async {
    clinicId = null;
    userId   = null;
    role     = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('clinic_id');
    await prefs.remove('user_id');
    await prefs.remove('role');
  }
}