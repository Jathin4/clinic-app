import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../widgets/app_widgets.dart';

const _profileRoles = ['Admin', 'Doctor', 'Receptionist', 'Pharmacist', 'Diagnosist'];
const _profileBloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
const _minAgeDoctor = 24;
const _minAgeNonDoctor = 18;

Color _roleColor(String? r) => switch (r) {
      'Admin' => AppColors.statusPurple,
      'Doctor' => AppColors.teal,
      'Receptionist' => AppColors.statusOrange,
      'Pharmacist' => AppColors.statusBlue,
      'Diagnosist' => AppColors.statusRed,
      _ => AppColors.statusGray,
    };

Color _roleBg(String? r) => switch (r) {
      'Admin' => AppColors.statusPurpleBg,
      'Doctor' => AppColors.statusGreenBg,
      'Receptionist' => AppColors.statusOrangeBg,
      'Pharmacist' => AppColors.statusBlueBg,
      'Diagnosist' => AppColors.statusRedBg,
      _ => AppColors.statusGrayBg,
    };

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _openEdit(BuildContext context, Map<String, dynamic> user) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _ProfileEditForm(
          user: user,
          onSaved: (updated) => context.read<AppProvider>().setUser(updated),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppProvider>().user;
    if (user == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: AppEmptyView(message: 'Not logged in.'),
      );
    }

    final String name = (user['full_name'] ?? '—').toString();
    final String email = (user['email'] ?? '—').toString();
    final String phone = (user['phone'] ?? '—').toString();
    final String role = (user['role'] ?? '—').toString();
    final dob = (user['date_of_birth']?.toString() ?? '').length >= 10
        ? user['date_of_birth'].toString().substring(0, 10)
        : '—';
    final blood = user['blood_group'] ?? '—';
    final spec = user['specialization'] as String?;
    final isActive = user['is_active'] ?? true;

    final parts = name.split(' ');
    final raw =
        parts.where((w) => w.isNotEmpty).map((w) => w[0].toUpperCase()).join();
    final ini = raw.length > 2 ? raw.substring(0, 2) : raw;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(children: [
        AppPageHeader(
          title: 'My Profile',
          subtitle: 'View and edit your account',
          actionLabel: 'Edit Profile',
          actionIcon: Icons.edit_outlined,
          onAction: () => _openEdit(context, user),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              // ── Avatar + name card ─────────────────────────
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: _roleBg(role),
                    child: Text(ini,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: _roleColor(role))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(children: [
                        Expanded(
                            child: Text(name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: AppColors.textPrimary))),
                        if (!isActive)
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                  color: AppColors.statusRedBg,
                                  borderRadius: BorderRadius.circular(4)),
                              child: const Text('Inactive',
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: AppColors.statusRed,
                                      fontWeight: FontWeight.w600))),
                      ]),
                      const SizedBox(height: 2),
                      Text(email, style: AppTextStyles.bodySmall),
                      const SizedBox(height: 6),
                      Row(children: [
                        AppStatusBadge(
                            label: role,
                            color: _roleColor(role),
                            bg: _roleBg(role)),
                        if (spec != null && spec.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text('· $spec',
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ]),
                    ]),
                  ),
                ]),
              ),
              // ── Info tiles ────────────────────────────────
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  _InfoTile(Icons.phone_outlined, 'Phone', phone),
                  _divider(),
                  _InfoTile(Icons.cake_outlined, 'Date of Birth', dob),
                  _divider(),
                  _InfoTile(Icons.bloodtype_outlined, 'Blood Group', blood),
                  if (spec != null && spec.isNotEmpty) ...[
                    _divider(),
                    _InfoTile(Icons.medical_services_outlined,
                        'Specialization', spec),
                  ],
                  _divider(),
                  _InfoTile(
                    isActive
                        ? Icons.check_circle_outline
                        : Icons.cancel_outlined,
                    'Status',
                    isActive ? 'Active' : 'Inactive',
                    valueColor: isActive
                        ? const Color(0xFF16A34A)
                        : AppColors.statusRed,
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _divider() => const Divider(
      height: 1, indent: 16, endIndent: 16, color: AppColors.divider);
}

// ── Info tile ─────────────────────────────────────────────────
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color? valueColor;
  const _InfoTile(this.icon, this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? AppColors.textPrimary)),
        ]),
      );
}

// ── Qualification model ───────────────────────────────────────
class _Qualification {
  final qualCtrl = TextEditingController();
  final instCtrl = TextEditingController();
  _Qualification({String qual = '', String inst = ''}) {
    qualCtrl.text = qual;
    instCtrl.text = inst;
  }
  void dispose() {
    qualCtrl.dispose();
    instCtrl.dispose();
  }
}

// ── Profile edit form (bottom sheet) ─────────────────────────
class _ProfileEditForm extends StatefulWidget {
  final Map<String, dynamic> user;
  final void Function(Map<String, dynamic>) onSaved;
  const _ProfileEditForm({required this.user, required this.onSaved});

  @override
  State<_ProfileEditForm> createState() => _ProfileEditFormState();
}

class _ProfileEditFormState extends State<_ProfileEditForm> {
  String? _role, _bloodGroup;
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _specCtrl = TextEditingController();
  bool _saving = false;
  Map<String, String> _errors = {};
  final List<_Qualification> _quals = [];

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _nameCtrl.text = u['full_name'] ?? '';
    _emailCtrl.text = u['email'] ?? '';
    _phoneCtrl.text = u['phone'] ?? '';
    _dobCtrl.text = (u['date_of_birth']?.toString() ?? '').length >= 10
        ? u['date_of_birth'].toString().substring(0, 10)
        : '';
    _role = u['role'];
    _bloodGroup = u['blood_group'];
    _specCtrl.text = u['specialization'] ?? '';
    final quals = u['qualifications'];
    if (quals is List) {
      for (final q in quals) {
        _quals.add(_Qualification(
          qual: q['qualification'] ?? q['qualification_name'] ?? '',
          inst: q['institution'] ?? q['institute_name'] ?? '',
        ));
      }
    }
    if (_quals.isEmpty && _role == 'Doctor') _quals.add(_Qualification());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _dobCtrl.dispose();
    _specCtrl.dispose();
    for (final q in _quals) q.dispose();
    super.dispose();
  }

  int _computeAge(String dob) {
    try {
      final d = DateTime.parse(dob.substring(0, 10));
      final now = DateTime.now();
      int age = now.year - d.year;
      if (now.month < d.month || (now.month == d.month && now.day < d.day)) {
        age--;
      }
      return age;
    } catch (_) {
      return -1;
    }
  }

  bool _validate() {
    final e = <String, String>{};
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) e['name'] = 'Required';
    else if (name.length < 2) e['name'] = 'At least 2 characters';
    else if (!RegExp(r'^[A-Za-z .]+$').hasMatch(name)) e['name'] = 'Letters and spaces only';

    if (_emailCtrl.text.trim().isEmpty) e['email'] = 'Required';
    else if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_emailCtrl.text.trim()))
      e['email'] = 'Invalid email format';

    if (_phoneCtrl.text.trim().isEmpty) e['phone'] = 'Required';
    else if (!RegExp(r'^\d{10}$').hasMatch(_phoneCtrl.text.trim()))
      e['phone'] = 'Must be exactly 10 digits';

    if (_role == null) e['role'] = 'Required';
    if (_bloodGroup == null) e['blood'] = 'Required';

    if (_dobCtrl.text.isEmpty) {
      e['dob'] = 'Required';
    } else {
      final age = _computeAge(_dobCtrl.text);
      final dob = DateTime.tryParse(_dobCtrl.text);
      if (dob != null && dob.isAfter(DateTime.now())) {
        e['dob'] = 'Cannot be in the future';
      } else if (_role == 'Doctor' && age < _minAgeDoctor) {
        e['dob'] = 'Doctor must be at least $_minAgeDoctor years old';
      } else if (_role != null && _role != 'Doctor' && age < _minAgeNonDoctor) {
        e['dob'] = 'Must be at least $_minAgeNonDoctor years old';
      }
    }

    if (_role == 'Doctor' && _specCtrl.text.trim().isEmpty) {
      e['spec'] = 'Required for Doctor';
    }

    if (_role == 'Doctor') {
      if (_quals.isEmpty) {
        e['quals'] = 'At least one qualification required';
      } else {
        final names = <String>[];
        for (int i = 0; i < _quals.length; i++) {
          final q = _quals[i].qualCtrl.text.trim();
          final inst = _quals[i].instCtrl.text.trim();
          if (q.isEmpty) e['qual_$i'] = 'Required';
          else if (names.contains(q.toLowerCase())) e['qual_$i'] = 'Duplicate';
          else names.add(q.toLowerCase());
          if (inst.isEmpty) e['inst_$i'] = 'Required';
          else if (inst.length < 3) e['inst_$i'] = 'Min 3 characters';
        }
      }
    }

    setState(() => _errors = e);
    return e.isEmpty;
  }

  Future<void> _save() async {
    if (!_validate()) return;
    setState(() => _saving = true);
    try {
      final qualList = _role == 'Doctor'
          ? _quals
              .map((q) => {
                    'qualification': q.qualCtrl.text.trim(),
                    'institution': q.instCtrl.text.trim(),
                  })
              .toList()
          : [];
      final res = await http.post(
        Uri.parse('${ApiClient.baseUrl}/users_create_update/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': widget.user['id'],
          'clinic_id': widget.user['clinic_id'] ?? 1,
          'full_name': _nameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'date_of_birth': _dobCtrl.text,
          'role': _role,
          'blood_group': _bloodGroup,
          'specialization':
              (_role == 'Doctor' && _specCtrl.text.trim().isNotEmpty)
                  ? _specCtrl.text.trim()
                  : null,
          'qualifications': qualList,
          'is_active': widget.user['is_active'] ?? true,
          'user': _emailCtrl.text.trim(),
        }),
      );
      if ((res.statusCode == 200 || res.statusCode == 201) && mounted) {
        final updated = Map<String, dynamic>.from(widget.user)
          ..addAll({
            'full_name': _nameCtrl.text.trim(),
            'email': _emailCtrl.text.trim(),
            'phone': _phoneCtrl.text.trim(),
            'date_of_birth': _dobCtrl.text,
            'role': _role,
            'blood_group': _bloodGroup,
            'specialization':
                (_role == 'Doctor' && _specCtrl.text.trim().isNotEmpty)
                    ? _specCtrl.text.trim()
                    : null,
          });
        Navigator.pop(context);
        widget.onSaved(updated);
      }
    } catch (_) {}
    if (mounted) setState(() => _saving = false);
  }

  Widget _err(String t) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(t,
          style: const TextStyle(fontSize: 11, color: AppColors.statusRed)));

  @override
  Widget build(BuildContext context) => Container(
        height: MediaQuery.of(context).size.height * 0.92,
        decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(children: [
          const AppSheetHeader(title: 'Edit Profile'),
          Expanded(
              child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AppFormField(
                  label: 'Full Name *',
                  controller: _nameCtrl,
                  hint: 'Dr. John Smith',
                  onChanged: (_) => setState(() => _errors.remove('name'))),
              if (_errors['name'] != null) _err(_errors['name']!),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      AppFormField(
                          label: 'Email *',
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          hint: 'user@clinic.com',
                          onChanged: (_) =>
                              setState(() => _errors.remove('email'))),
                      if (_errors['email'] != null) _err(_errors['email']!),
                    ])),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      AppFormField(
                          label: 'Phone *',
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          hint: '10 digits',
                          onChanged: (_) =>
                              setState(() => _errors.remove('phone'))),
                      if (_errors['phone'] != null) _err(_errors['phone']!),
                    ])),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      AppDropdownField<String>(
                        label: 'Role *',
                        value: _role,
                        items: _profileRoles
                            .map((r) => DropdownMenuItem(
                                value: r,
                                child: Text(r,
                                    style: const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (v) => setState(() {
                          _role = v;
                          _errors.remove('role');
                        }),
                      ),
                      if (_errors['role'] != null) _err(_errors['role']!),
                    ])),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      AppDropdownField<String>(
                        label: 'Blood Group *',
                        value: _bloodGroup,
                        items: _profileBloodGroups
                            .map((b) => DropdownMenuItem(
                                value: b,
                                child: Text(b,
                                    style: const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (v) => setState(() {
                          _bloodGroup = v;
                          _errors.remove('blood');
                        }),
                      ),
                      if (_errors['blood'] != null) _err(_errors['blood']!),
                    ])),
              ]),
              const SizedBox(height: 14),
              Text('Date of Birth *', style: AppTextStyles.label),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () async {
                  final minAge =
                      _role == 'Doctor' ? _minAgeDoctor : _minAgeNonDoctor;
                  final maxDate = DateTime(DateTime.now().year - minAge,
                      DateTime.now().month, DateTime.now().day);
                  final d = await showDatePicker(
                      context: context,
                      initialDate: _dobCtrl.text.isNotEmpty
                          ? (DateTime.tryParse(_dobCtrl.text) ?? maxDate)
                          : DateTime(1990),
                      firstDate: DateTime(1940),
                      lastDate: maxDate,
                      builder: (c, child) => Theme(
                          data: Theme.of(c).copyWith(
                              colorScheme: const ColorScheme.light(
                                  primary: AppColors.teal)),
                          child: child!));
                  if (d != null) {
                    setState(() {
                      _dobCtrl.text = d.toIso8601String().substring(0, 10);
                      _errors.remove('dob');
                    });
                  }
                },
                child: AbsorbPointer(
                    child: TextField(
                        controller: _dobCtrl,
                        decoration: AppInput.deco('YYYY-MM-DD',
                            icon: Icons.cake_outlined))),
              ),
              if (_errors['dob'] != null) _err(_errors['dob']!),
              if (_dobCtrl.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Age: ${_computeAge(_dobCtrl.text)} years',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textMuted)),
                ),
              if (_role == 'Doctor') ...[
                const SizedBox(height: 14),
                AppFormField(
                    label: 'Specialization *',
                    controller: _specCtrl,
                    hint: 'e.g. Cardiology',
                    onChanged: (_) => setState(() => _errors.remove('spec'))),
                if (_errors['spec'] != null) _err(_errors['spec']!),
                // Qualifications
                const SizedBox(height: 14),
                Row(children: [
                  const Expanded(
                      child: Text('Qualifications *',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary))),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _quals.add(_Qualification())),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: AppColors.statusGreenBg,
                          borderRadius: BorderRadius.circular(8)),
                      child: const Row(mainAxisSize: MainAxisSize.min,
                          children: [
                        Icon(Icons.add, size: 14, color: AppColors.teal),
                        SizedBox(width: 4),
                        Text('Add',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.teal,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ]),
                if (_errors['quals'] != null) _err(_errors['quals']!),
                const SizedBox(height: 8),
                ..._quals.asMap().entries.map((entry) {
                  final i = entry.key;
                  final q = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(children: [
                        Text('Qualification ${i + 1}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary)),
                        const Spacer(),
                        if (_quals.length > 1)
                          GestureDetector(
                            onTap: () => setState(() {
                              _quals[i].dispose();
                              _quals.removeAt(i);
                            }),
                            child: const Icon(Icons.close,
                                size: 16, color: AppColors.statusRed),
                          ),
                      ]),
                      const SizedBox(height: 8),
                      AppFormField(
                          label: 'Qualification Name *',
                          controller: q.qualCtrl,
                          hint: 'e.g. MBBS, MD',
                          onChanged: (_) =>
                              setState(() => _errors.remove('qual_$i'))),
                      if (_errors['qual_$i'] != null)
                        _err(_errors['qual_$i']!),
                      const SizedBox(height: 8),
                      AppFormField(
                          label: 'Institution *',
                          controller: q.instCtrl,
                          hint: 'e.g. AIIMS Delhi',
                          onChanged: (_) =>
                              setState(() => _errors.remove('inst_$i'))),
                      if (_errors['inst_$i'] != null)
                        _err(_errors['inst_$i']!),
                    ]),
                  );
                }),
              ],
            ]),
          )),
          AppFormButtons(
              saving: _saving,
              onCancel: () => Navigator.pop(context),
              onSave: _save,
              saveLabel: 'Save Changes'),
        ]),
      );
}