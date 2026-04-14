import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../widgets/app_widgets.dart';

const _userRoles = ['Admin', 'Doctor', 'Receptionist', 'Pharmacist', 'Diagnosist'];
const _userBloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

Color _uRoleColor(String? r) => switch (r) {
      'Admin' => AppColors.statusPurple,
      'Doctor' => AppColors.teal,
      'Receptionist' => AppColors.statusOrange,
      'Pharmacist' => AppColors.statusBlue,
      'Diagnosist' => AppColors.statusRed,
      _ => AppColors.statusGray,
    };

Color _uRoleBg(String? r) => switch (r) {
      'Admin' => AppColors.statusPurpleBg,
      'Doctor' => AppColors.statusGreenBg,
      'Receptionist' => AppColors.statusOrangeBg,
      'Pharmacist' => AppColors.statusBlueBg,
      'Diagnosist' => AppColors.statusRedBg,
      _ => AppColors.statusGrayBg,
    };

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<Map<String, dynamic>> _users = [];
  String _search = '';
  bool _isLoading = true;
  int _currentPage = 1;
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    final provider = context.read<AppProvider>();
    setState(() => _isLoading = true);
    provider.showLoading('Loading users...');
    try {
      final clinicId = provider.user?['clinic_id'];
      final res = await http.get(Uri.parse(
          '${ApiClient.baseUrl}/users_read_by_clinic/?clinic_id=$clinicId'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _users = List<Map<String, dynamic>>.from(data['users'] ?? []);
        });
      }
    } catch (_) {
      if (mounted) showSnack(context, 'Failed to load users', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        provider.hideLoading();
      }
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _users;
    return _users.where((u) => [
          u['full_name'],
          u['email'],
          u['phone'],
          u['role'],
          u['is_active'] == true ? 'active' : 'inactive',
        ].any((v) => v?.toString().toLowerCase().contains(q) == true)).toList();
  }

  void _openAdd() => _openForm(null);

  void _openEdit(Map<String, dynamic> user) => _openForm(user);

  void _openForm(Map<String, dynamic>? user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserForm(
        user: user,
        allUsers: _users,
        clinicId: context.read<AppProvider>().user?['clinic_id'] ?? 1,
        onSaved: () {
          _fetchUsers();
          showSnack(context,
              user != null ? 'User updated successfully' : 'User added successfully');
        },
      ),
    );
  }

  Future<void> _deleteUser(int userId) async {
    final confirmed = await confirmDelete(context,
        title: 'Deactivate User',
        message: 'Are you sure you want to deactivate this user?');
    if (!confirmed || !mounted) return;
    try {
      final provider = context.read<AppProvider>();
      final res = await http.post(
        Uri.parse('${ApiClient.baseUrl}/users_soft_delete_by_clinic/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'clinic_id': provider.user?['clinic_id'],
          'user': 'admin',
        }),
      );
      if (res.statusCode == 200 && mounted) {
        showSnack(context, 'User set to Inactive');
        _fetchUsers();
      }
    } catch (_) {
      if (mounted) showSnack(context, 'Failed to deactivate user', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final totalPages = (filtered.length / _pageSize).ceil().clamp(1, 9999);
    final start = (_currentPage - 1) * _pageSize;
    final end = (start + _pageSize).clamp(0, filtered.length);
    final pageItems = filtered.sublist(start, end);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(children: [
        AppPageHeader(
          title: 'Users & Staff',
          subtitle: 'Manage clinic roles and access',
          actionLabel: 'Add User',
          actionIcon: Icons.add,
          onAction: _openAdd,
        ),
        AppSearchBar(
          hint: 'Search by name, email, role…',
          onChanged: (v) => setState(() {
            _search = v.trimLeft();
            _currentPage = 1;
          }),
        ),
        Expanded(
          child: _isLoading
              ? const AppLoadingView()
              : filtered.isEmpty
                  ? const AppEmptyView(message: 'No users found')
                  : Column(children: [
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: pageItems.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) => _UserCard(
                            user: pageItems[i],
                            onEdit: () => _openEdit(pageItems[i]),
                            onDelete: () => _deleteUser(pageItems[i]['id']),
                          ),
                        ),
                      ),
                      if (totalPages > 1)
                        _PaginationBar(
                          currentPage: _currentPage,
                          totalPages: totalPages,
                          total: filtered.length,
                          onPage: (p) => setState(() => _currentPage = p),
                        ),
                    ]),
        ),
      ]),
    );
  }
}

// ── User Card ─────────────────────────────────────────────────
class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _UserCard(
      {required this.user, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final name = (user['full_name'] ?? '—').toString();
    final email = (user['email'] ?? '—').toString();
    final phone = (user['phone'] ?? '—').toString();
    final role = (user['role'] ?? '—').toString();
    final isActive = user['is_active'] ?? true;
    final parts = name.split(' ').where((w) => w.isNotEmpty).toList();
    final ini = parts.isEmpty
        ? 'U'
        : parts.length == 1
            ? parts[0][0].toUpperCase()
            : '${parts[0][0]}${parts[1][0]}'.toUpperCase();

    return AppCard(
      margin: EdgeInsets.zero,
      child: Row(children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: _uRoleBg(role),
          child: Text(ini,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: _uRoleColor(role))),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
          Row(children: [
            Expanded(
                child: Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textPrimary))),
            AppStatusBadge(
              label: isActive ? 'Active' : 'Inactive',
              color: isActive
                  ? const Color(0xFF16A34A)
                  : AppColors.statusRed,
              bg: isActive
                  ? AppColors.statusGreenBg
                  : AppColors.statusRedBg,
            ),
          ]),
          const SizedBox(height: 2),
          Text(email, style: AppTextStyles.bodySmall),
          const SizedBox(height: 4),
          Row(children: [
            AppStatusBadge(
                label: role,
                color: _uRoleColor(role),
                bg: _uRoleBg(role)),
            const SizedBox(width: 8),
            Text(phone,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textMuted)),
          ]),
        ])),
        const SizedBox(width: 8),
        Column(children: [
          _ActionBtn(
            icon: Icons.edit_outlined,
            color: AppColors.statusBlue,
            bg: AppColors.statusBlueBg,
            onTap: onEdit,
          ),
          const SizedBox(height: 6),
          _ActionBtn(
            icon: Icons.person_off_outlined,
            color: AppColors.statusRed,
            bg: AppColors.statusRedBg,
            onTap: onDelete,
          ),
        ]),
      ]),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color, bg;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon,
      required this.color,
      required this.bg,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration:
              BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 16, color: color),
        ),
      );
}

// ── Pagination bar ────────────────────────────────────────────
class _PaginationBar extends StatelessWidget {
  final int currentPage, totalPages, total;
  final void Function(int) onPage;
  const _PaginationBar(
      {required this.currentPage,
      required this.totalPages,
      required this.total,
      required this.onPage});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(children: [
          Text('$total result${total == 1 ? '' : 's'}',
              style: AppTextStyles.bodySmall),
          const Spacer(),
          _PageBtn(
            icon: Icons.chevron_left,
            enabled: currentPage > 1,
            onTap: () => onPage(currentPage - 1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text('$currentPage / $totalPages',
                style: AppTextStyles.label),
          ),
          _PageBtn(
            icon: Icons.chevron_right,
            enabled: currentPage < totalPages,
            onTap: () => onPage(currentPage + 1),
          ),
        ]),
      );
}

class _PageBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _PageBtn(
      {required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: enabled ? AppColors.surfaceCard : AppColors.surfaceLow,
              borderRadius: BorderRadius.circular(8),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4)
                    ]
                  : null),
          child: Icon(icon,
              size: 18,
              color: enabled ? AppColors.textPrimary : AppColors.textMuted),
        ),
      );
}

// ── User form (add / edit) ────────────────────────────────────
class _Qual {
  final qualCtrl = TextEditingController();
  final instCtrl = TextEditingController();
  _Qual({String qual = '', String inst = ''}) {
    qualCtrl.text = qual;
    instCtrl.text = inst;
  }
  void dispose() {
    qualCtrl.dispose();
    instCtrl.dispose();
  }
}

class _UserForm extends StatefulWidget {
  final Map<String, dynamic>? user;
  final List<Map<String, dynamic>> allUsers;
  final int clinicId;
  final VoidCallback onSaved;
  const _UserForm(
      {this.user,
      required this.allUsers,
      required this.clinicId,
      required this.onSaved});

  @override
  State<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<_UserForm> {
  int _step = 0;
  bool _saving = false;
  Map<String, String> _errors = {};

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _specCtrl = TextEditingController();
  String? _role, _blood;
  final List<_Qual> _quals = [];

  bool get _isEditing => widget.user != null;
  bool get _isDoctor => _role == 'Doctor';
  int get _totalSteps => _isDoctor ? 3 : 2;
  bool get _isLastStep => _step == _totalSteps - 1;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final u = widget.user!;
      _nameCtrl.text = u['full_name'] ?? '';
      _emailCtrl.text = u['email'] ?? '';
      _phoneCtrl.text = u['phone'] ?? '';
      _dobCtrl.text = (u['date_of_birth']?.toString() ?? '').length >= 10
          ? u['date_of_birth'].toString().substring(0, 10)
          : '';
      _role = u['role'];
      _blood = u['blood_group'];
      _specCtrl.text = u['specialization'] ?? '';
      final quals = u['qualifications'];
      if (quals is List) {
        for (final q in quals) {
          _quals.add(_Qual(
            qual: q['qualification_name'] ?? q['qualification'] ?? '',
            inst: q['institute_name'] ?? q['institution'] ?? '',
          ));
        }
      }
    }
    if (_quals.isEmpty && _isDoctor) _quals.add(_Qual());
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

  bool _isDuplicate(String field, String value) => widget.allUsers.any((u) =>
      u[field]?.toString().toLowerCase() == value.toLowerCase() &&
      u['id'] != widget.user?['id']);

  int _age(String dob) {
    try {
      final d = DateTime.parse(dob.substring(0, 10));
      final now = DateTime.now();
      int age = now.year - d.year;
      if (now.month < d.month ||
          (now.month == d.month && now.day < d.day)) age--;
      return age;
    } catch (_) {
      return -1;
    }
  }

  bool _validateStep0() {
    final e = <String, String>{};
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) e['name'] = 'Required';
    else if (name.length < 2) e['name'] = 'At least 2 characters';
    else if (!RegExp(r'^[A-Za-z .]+$').hasMatch(name))
      e['name'] = 'Letters and spaces only';

    final email = _emailCtrl.text.trim();
    if (email.isEmpty) e['email'] = 'Required';
    else if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email))
      e['email'] = 'Invalid email format';
    else if (_isDuplicate('email', email)) e['email'] = 'Already registered';

    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) e['phone'] = 'Required';
    else if (!RegExp(r'^\d{10}$').hasMatch(phone))
      e['phone'] = '10 digits required';
    else if (_isDuplicate('phone', phone)) e['phone'] = 'Already registered';

    setState(() => _errors = e);
    return e.isEmpty;
  }

  bool _validateStep1() {
    final e = <String, String>{};
    if (_role == null) e['role'] = 'Required';
    if (_blood == null) e['blood'] = 'Required';
    if (_dobCtrl.text.isEmpty) {
      e['dob'] = 'Required';
    } else {
      final dob = DateTime.tryParse(_dobCtrl.text);
      final age = _age(_dobCtrl.text);
      if (dob != null && dob.isAfter(DateTime.now())) {
        e['dob'] = 'Cannot be in the future';
      } else if (_role == 'Doctor' && age <= 24) {
        e['dob'] = 'Doctor must be older than 24 years';
      } else if (_role != null && _role != 'Doctor' && age < 18) {
        e['dob'] = 'Must be at least 18 years old';
      }
    }
    if (_isDoctor && _specCtrl.text.trim().isEmpty) {
      e['spec'] = 'Required for Doctor';
    }
    setState(() => _errors = e);
    return e.isEmpty;
  }

  bool _validateStep2() {
    final e = <String, String>{};
    if (_quals.isEmpty) {
      e['quals'] = 'At least one qualification required';
    } else {
      final names = <String>[];
      for (int i = 0; i < _quals.length; i++) {
        final q = _quals[i].qualCtrl.text.trim();
        final inst = _quals[i].instCtrl.text.trim();
        if (q.isEmpty) {
          e['qual_$i'] = 'Required';
        } else if (names.contains(q.toLowerCase())) {
          e['qual_$i'] = 'Duplicate qualification';
        } else {
          names.add(q.toLowerCase());
        }
        if (inst.isEmpty) e['inst_$i'] = 'Required';
        else if (inst.length < 3) e['inst_$i'] = 'Min 3 characters';
      }
    }
    setState(() => _errors = e);
    return e.isEmpty;
  }

  void _handleNext() {
    if (_step == 0 && !_validateStep0()) return;
    if (_step == 1 && !_validateStep1()) return;
    if (_isLastStep) {
      _save();
    } else {
      setState(() { _step++; _errors = {}; });
    }
  }

  Future<void> _save() async {
    if (_step == 2 && !_validateStep2()) return;
    setState(() => _saving = true);
    try {
      final qualList = _isDoctor
          ? _quals
              .map((q) => {
                    'qualification_name': q.qualCtrl.text.trim(),
                    'institute_name': q.instCtrl.text.trim(),
                  })
              .toList()
          : <Map<String, String>>[];
      final res = await http.post(
        Uri.parse('${ApiClient.baseUrl}/users_create_update/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': widget.user?['id'],
          'clinic_id': widget.clinicId,
          'full_name': _nameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'date_of_birth': _dobCtrl.text,
          'role': _role,
          'blood_group': _blood,
          'specialization': _isDoctor ? _specCtrl.text.trim() : null,
          'qualifications': qualList,
          'is_active': widget.user?['is_active'] ?? true,
          'user': _emailCtrl.text.trim(),
          'password_hash': '',
        }),
      );
      if ((res.statusCode == 200 || res.statusCode == 201) && mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (_) {
      if (mounted) showSnack(context, 'Something went wrong', isError: true);
    }
    if (mounted) setState(() => _saving = false);
  }

  Widget _err(String t) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(t,
          style: const TextStyle(fontSize: 11, color: AppColors.statusRed)));

  String _stepLabel() {
    if (_step == 0) return 'Personal contact information';
    if (_step == 1) return _isDoctor ? 'Professional details' : 'Review and submit';
    return 'Qualifications & certifications';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(children: [
        AppSheetHeader(title: _isEditing ? 'Edit User' : 'Add New User'),
        // Progress bar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            children: List.generate(
              _totalSteps,
              (i) => Expanded(
                child: Container(
                  height: 4,
                  margin:
                      EdgeInsets.only(right: i < _totalSteps - 1 ? 6 : 0),
                  decoration: BoxDecoration(
                      color: i <= _step
                          ? AppColors.teal
                          : AppColors.surfaceLow,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Step ${_step + 1}: ${_stepLabel()}',
                  style: AppTextStyles.bodySmall)),
        ),
        Expanded(
            child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: KeyedSubtree(
              key: ValueKey(_step),
              child: _step == 0
                  ? _buildStep0()
                  : _step == 1
                      ? _buildStep1()
                      : _buildStep2(),
            ),
          ),
        )),
        AppFormButtons(
          saving: _saving,
          onCancel: _step == 0
              ? () => Navigator.pop(context)
              : () => setState(() { _step--; _errors = {}; }),
          onSave: _handleNext,
          saveLabel: _isLastStep
              ? (_isEditing ? 'Update User' : 'Add User')
              : 'Next →',
        ),
      ]),
    );
  }

  // ── Step 0: Personal info ──────────────────────────────────
  Widget _buildStep0() => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        AppFormField(
            label: 'Full Name *',
            controller: _nameCtrl,
            hint: 'e.g. John Doe',
            onChanged: (_) => setState(() => _errors.remove('name'))),
        if (_errors['name'] != null) _err(_errors['name']!),
        const SizedBox(height: 14),
        AppFormField(
            label: 'Email *',
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            hint: 'user@clinic.com',
            onChanged: (_) => setState(() => _errors.remove('email'))),
        if (_errors['email'] != null) _err(_errors['email']!),
        const SizedBox(height: 14),
        AppFormField(
            label: 'Phone *',
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            hint: '10 digits',
            onChanged: (_) => setState(() => _errors.remove('phone'))),
        if (_errors['phone'] != null) _err(_errors['phone']!),
      ]);

  // ── Step 1: Professional details ──────────────────────────
  Widget _buildStep1() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Date of Birth *', style: AppTextStyles.label),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () async {
            final d = await showDatePicker(
                context: context,
                initialDate: _dobCtrl.text.isNotEmpty
                    ? (DateTime.tryParse(_dobCtrl.text) ?? DateTime(1990))
                    : DateTime(1990),
                firstDate: DateTime(1940),
                lastDate: DateTime.now(),
                builder: (c, child) => Theme(
                    data: Theme.of(c).copyWith(
                        colorScheme:
                            const ColorScheme.light(primary: AppColors.teal)),
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
                  decoration:
                      AppInput.deco('YYYY-MM-DD', icon: Icons.cake_outlined))),
        ),
        if (_errors['dob'] != null) _err(_errors['dob']!),
        if (_dobCtrl.text.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Age: ${_age(_dobCtrl.text)} years',
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textMuted))),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            AppDropdownField<String>(
              label: 'Role *',
              value: _role,
              items: _userRoles
                  .map((r) => DropdownMenuItem(
                      value: r,
                      child: Text(r, style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: (v) => setState(() {
                _role = v;
                _errors.remove('role');
                if (v == 'Doctor' && _quals.isEmpty) _quals.add(_Qual());
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
              value: _blood,
              items: _userBloodGroups
                  .map((b) => DropdownMenuItem(
                      value: b,
                      child: Text(b, style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: (v) =>
                  setState(() { _blood = v; _errors.remove('blood'); }),
            ),
            if (_errors['blood'] != null) _err(_errors['blood']!),
          ])),
        ]),
        if (_isDoctor) ...[
          const SizedBox(height: 14),
          AppFormField(
              label: 'Specialization *',
              controller: _specCtrl,
              hint: 'e.g. Cardiology',
              onChanged: (_) => setState(() => _errors.remove('spec'))),
          if (_errors['spec'] != null) _err(_errors['spec']!),
        ],
      ]);

  // ── Step 2: Qualifications ─────────────────────────────────
  Widget _buildStep2() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(
              child: Text('Qualifications *',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary))),
          GestureDetector(
            onTap: () => setState(() => _quals.add(_Qual())),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: AppColors.statusGreenBg,
                  borderRadius: BorderRadius.circular(8)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
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
              if (_errors['qual_$i'] != null) _err(_errors['qual_$i']!),
              const SizedBox(height: 8),
              AppFormField(
                  label: 'Institution *',
                  controller: q.instCtrl,
                  hint: 'e.g. AIIMS Delhi',
                  onChanged: (_) =>
                      setState(() => _errors.remove('inst_$i'))),
              if (_errors['inst_$i'] != null) _err(_errors['inst_$i']!),
            ]),
          );
        }),
      ]);
}