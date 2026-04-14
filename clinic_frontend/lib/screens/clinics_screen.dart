import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_client.dart';
import '../widgets/app_widgets.dart';

// GST number: 15-character alphanumeric (Indian format)
final _gstRegex = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$');

class ClinicsScreen extends StatefulWidget {
  const ClinicsScreen({super.key});
  @override
  State<ClinicsScreen> createState() => _ClinicsScreenState();
}

class _ClinicsScreenState extends State<ClinicsScreen> {
  List<Map<String, dynamic>> _clinics = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(Uri.parse('${ApiClient.baseUrl}/clinicsread'));
      final data = jsonDecode(res.body);
      if (data is List) setState(() => _clinics = List<Map<String, dynamic>>.from(data));
    } catch (_) {}
    setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _clinics;
    return _clinics.where((c) =>
      '${c['name']} ${c['city']} ${c['state']} ${c['phone']}'.toLowerCase().contains(q)).toList();
  }

  void _openForm({Map<String, dynamic>? clinic}) => showModalBottomSheet(
    context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => _ClinicForm(clinic: clinic, existingClinics: _clinics, onSaved: _fetch),
  );

  Future<void> _delete(Map<String, dynamic> clinic) async {
    if (!await confirmDelete(context, title: 'Delete Clinic', message: 'Delete "${clinic['name']}"?')) return;
    try {
      await http.delete(Uri.parse('${ApiClient.baseUrl}/clinic_delete/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'id': clinic['id'], 'modified_by': 'admin'}));
      _fetch();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: Column(children: [
      AppPageHeader(title: 'Clinics', subtitle: 'Manage clinic locations', actionLabel: 'Add Clinic', actionIcon: Icons.add, onAction: () => _openForm()),
      AppSearchBar(hint: 'Search by name, city, state…', onChanged: (v) => setState(() => _search = v)),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Align(alignment: Alignment.centerLeft,
          child: Text('${_filtered.length} clinic${_filtered.length != 1 ? 's' : ''}', style: AppTextStyles.bodySmall)),
      ),
      Expanded(
        child: _loading ? const AppLoadingView()
            : _filtered.isEmpty ? const AppEmptyView(message: 'No clinics found')
            : RefreshIndicator(
                onRefresh: _fetch, color: AppColors.teal,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final c = _filtered[i];
                    final initials = (c['name'] ?? 'C').substring(0, (c['name'] ?? 'C').length > 1 ? 2 : 1).toUpperCase();
                    return AppCard(
                      child: Row(children: [
                        Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(12)),
                          child: Center(child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)))),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(c['name'] ?? '—', style: AppTextStyles.cardTitle),
                          if (c['city'] != null || c['state'] != null)
                            Text('${c['city'] ?? ''}${c['city'] != null && c['state'] != null ? ', ' : ''}${c['state'] ?? ''}', style: AppTextStyles.bodySmall),
                          if (c['phone'] != null)
                            Text(c['phone'], style: AppTextStyles.bodyMuted),
                          if (c['subscription_plan'] != null && c['subscription_plan'] != 'Select')
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: AppColors.statusGreenBg, borderRadius: BorderRadius.circular(6)),
                              child: Text(c['subscription_plan'], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.teal))),
                        ])),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          if (c['gst_number'] != null)
                            Text('GST: ${c['gst_number']}', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                          const SizedBox(height: 8),
                          Row(children: [
                            GestureDetector(onTap: () => _openForm(clinic: c), child: const Icon(Icons.edit_outlined, size: 16, color: AppColors.textMuted)),
                            const SizedBox(width: 10),
                            GestureDetector(onTap: () => _delete(c), child: const Icon(Icons.delete_outline, size: 16, color: AppColors.statusRed)),
                          ]),
                        ]),
                      ]),
                    );
                  },
                ),
              ),
      ),
    ]),
  );
}

class _ClinicForm extends StatefulWidget {
  final Map<String, dynamic>? clinic;
  final List<Map<String, dynamic>> existingClinics;
  final VoidCallback onSaved;
  const _ClinicForm({this.clinic, required this.existingClinics, required this.onSaved});
  @override
  State<_ClinicForm> createState() => _ClinicFormState();
}

class _ClinicFormState extends State<_ClinicForm> {
  int _step = 0;
  final _nameCtrl    = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _gstCtrl     = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _cityCtrl    = TextEditingController();
  final _stateCtrl   = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  String _plan = 'Basic';
  bool _saving = false;
  Map<String, String> _errors = {};

  bool get _isEditing => widget.clinic != null;

  @override
  void initState() {
    super.initState();
    if (widget.clinic != null) {
      final c = widget.clinic!;
      _nameCtrl.text    = c['name']              ?? '';
      _addressCtrl.text = c['Address'] ?? c['address'] ?? '';
      _gstCtrl.text     = c['gst_number']        ?? '';
      _emailCtrl.text   = c['email']             ?? '';
      _phoneCtrl.text   = c['phone']             ?? '';
      _cityCtrl.text    = c['city']              ?? '';
      _stateCtrl.text   = c['state']             ?? '';
      _pincodeCtrl.text = c['pincode']           ?? '';
      _plan             = c['subscription_plan'] ?? 'Basic';
    }
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _addressCtrl, _gstCtrl, _emailCtrl,
                     _phoneCtrl, _cityCtrl, _stateCtrl, _pincodeCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _validateStep0() {
    final e = <String, String>{};

    // VALIDATION: name required
    if (_nameCtrl.text.trim().isEmpty) {
      e['name'] = 'Required';
    } else {
      // VALIDATION: name duplicate check (case-insensitive, skip own record when editing)
      final isDuplicate = widget.existingClinics.any((c) {
        if (_isEditing && c['id']?.toString() == widget.clinic!['id']?.toString()) return false;
        return (c['name'] ?? '').toLowerCase().trim() == _nameCtrl.text.trim().toLowerCase();
      });
      if (isDuplicate) e['name'] = 'A clinic with this name already exists';
    }

    // VALIDATION: address required
    if (_addressCtrl.text.trim().isEmpty) e['address'] = 'Required';

    // VALIDATION: GST number format (15 chars, standard Indian GST format)
    final gst = _gstCtrl.text.trim();
    if (gst.isNotEmpty) {
      if (gst.length != 15) {
        e['gst'] = 'GST number must be exactly 15 characters';
      } else if (!_gstRegex.hasMatch(gst)) {
        e['gst'] = 'Invalid GST format (e.g. 22AAAAA0000A1Z5)';
      }
    }

    // VALIDATION: subscription_plan required (must not be default placeholder)
    if (_plan.isEmpty || _plan == 'Select') {
      e['plan'] = 'Please select a subscription plan';
    }

    setState(() => _errors = e);
    return e.isEmpty;
  }

  bool _validateStep1() {
    final e = <String, String>{};

    // VALIDATION: email required + format
    if (_emailCtrl.text.trim().isEmpty) {
      e['email'] = 'Required';
    } else if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_emailCtrl.text.trim())) {
      e['email'] = 'Invalid email format';
    } else {
      // VALIDATION: email duplicate check
      final isDuplicate = widget.existingClinics.any((c) {
        if (_isEditing && c['id']?.toString() == widget.clinic!['id']?.toString()) return false;
        return (c['email'] ?? '').toLowerCase() == _emailCtrl.text.trim().toLowerCase();
      });
      if (isDuplicate) e['email'] = 'This email is already registered to another clinic';
    }

    // VALIDATION: phone required + 10 digits
    if (_phoneCtrl.text.trim().isEmpty) {
      e['phone'] = 'Required';
    } else if (!RegExp(r'^\d{10}$').hasMatch(_phoneCtrl.text.trim())) {
      e['phone'] = 'Must be exactly 10 digits';
    } else {
      // VALIDATION: phone duplicate check
      final isDuplicate = widget.existingClinics.any((c) {
        if (_isEditing && c['id']?.toString() == widget.clinic!['id']?.toString()) return false;
        return (c['phone'] ?? '') == _phoneCtrl.text.trim();
      });
      if (isDuplicate) e['phone'] = 'This phone number is already registered to another clinic';
    }

    // VALIDATION: city required
    if (_cityCtrl.text.trim().isEmpty) e['city'] = 'Required';

    // VALIDATION: state required
    if (_stateCtrl.text.trim().isEmpty) e['state'] = 'Required';

    // VALIDATION: pincode required + 6 digits
    if (_pincodeCtrl.text.trim().isEmpty) {
      e['pincode'] = 'Required';
    } else if (!RegExp(r'^\d{6}$').hasMatch(_pincodeCtrl.text.trim())) {
      e['pincode'] = 'Must be exactly 6 digits';
    }

    setState(() => _errors = e);
    return e.isEmpty;
  }

  Future<void> _save() async {
    if (!_validateStep1()) return;
    setState(() => _saving = true);
    try {
      final res = await http.post(
        Uri.parse('${ApiClient.baseUrl}/clinic_create_update/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': widget.clinic?['id'],
          'name': _nameCtrl.text.trim(), 'Address': _addressCtrl.text.trim(),
          'gst_number': _gstCtrl.text.trim().isEmpty ? null : _gstCtrl.text.trim().toUpperCase(),
          'email': _emailCtrl.text.trim(), 'phone': _phoneCtrl.text.trim(),
          'city': _cityCtrl.text.trim(), 'state': _stateCtrl.text.trim(),
          'pincode': _pincodeCtrl.text.trim(), 'subscription_plan': _plan,
          'created_by': 'admin',
        }),
      );
      if (res.statusCode == 200 || res.statusCode == 201) { Navigator.pop(context); widget.onSaved(); }
    } catch (_) {}
    setState(() => _saving = false);
  }

  Widget _errText(String t) => Padding(padding: const EdgeInsets.only(top: 4),
    child: Text(t, style: const TextStyle(fontSize: 11, color: AppColors.statusRed)));

  Widget _buildStep0() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    // VALIDATION: name required + duplicate
    AppFormField(label: 'Clinic Name *', controller: _nameCtrl, hint: 'e.g. HealthCare Plus'),
    if (_errors['name'] != null) _errText(_errors['name']!),
    const SizedBox(height: 14),

    // VALIDATION: address required
    AppFormField(label: 'Address *', controller: _addressCtrl, hint: 'Street address…', maxLines: 2),
    if (_errors['address'] != null) _errText(_errors['address']!),
    const SizedBox(height: 14),

    // VALIDATION: GST format (15-char, Indian standard)
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AppFormField(
        label: 'GST Number',
        controller: _gstCtrl,
        hint: 'e.g. 22AAAAA0000A1Z5 (optional)',
        onChanged: (_) => setState(() => _errors.remove('gst')),
      ),
      if (_errors['gst'] != null) _errText(_errors['gst']!),
      if (_gstCtrl.text.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('${_gstCtrl.text.trim().length}/15 characters',
              style: TextStyle(fontSize: 10,
                  color: _gstCtrl.text.trim().length == 15 ? AppColors.teal : AppColors.textMuted)),
        ),
    ]),
    const SizedBox(height: 14),

    // VALIDATION: subscription_plan required
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AppDropdownField<String>(
        label: 'Subscription Plan *', value: _plan,
        items: ['Basic', 'Standard', 'Premium', 'Enterprise']
            .map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 13)))).toList(),
        onChanged: (v) => setState(() { _plan = v!; _errors.remove('plan'); }),
      ),
      if (_errors['plan'] != null) _errText(_errors['plan']!),
    ]),
  ]);

  Widget _buildStep1() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    // VALIDATION: email required + format + duplicate
    AppFormField(label: 'Email *', controller: _emailCtrl,
      keyboardType: TextInputType.emailAddress, hint: 'clinic@example.com',
      onChanged: (_) => setState(() => _errors.remove('email'))),
    if (_errors['email'] != null) _errText(_errors['email']!),
    const SizedBox(height: 14),

    // VALIDATION: phone required + 10 digits + duplicate
    AppFormField(label: 'Phone *', controller: _phoneCtrl,
      keyboardType: TextInputType.phone, hint: '10-digit number',
      onChanged: (_) => setState(() => _errors.remove('phone'))),
    if (_errors['phone'] != null) _errText(_errors['phone']!),
    const SizedBox(height: 14),

    Row(children: [
      // VALIDATION: city required
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AppFormField(label: 'City *', controller: _cityCtrl),
        if (_errors['city'] != null) _errText(_errors['city']!),
      ])),
      const SizedBox(width: 12),
      // VALIDATION: state required
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AppFormField(label: 'State *', controller: _stateCtrl),
        if (_errors['state'] != null) _errText(_errors['state']!),
      ])),
    ]),
    const SizedBox(height: 14),

    // VALIDATION: pincode required + 6 digits
    AppFormField(label: 'Pincode *', controller: _pincodeCtrl,
      keyboardType: TextInputType.number, hint: '6-digit pincode',
      onChanged: (_) => setState(() => _errors.remove('pincode'))),
    if (_errors['pincode'] != null) _errText(_errors['pincode']!),
  ]);

  @override
  Widget build(BuildContext context) => Container(
    height: MediaQuery.of(context).size.height * 0.88,
    decoration: const BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    child: Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
        child: Column(children: [
          Row(children: [
            const AppGradientIcon(icon: Icons.local_hospital_outlined, size: 36),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_isEditing ? 'Edit Clinic' : 'Add Clinic', style: AppTextStyles.sectionTitle),
              Text('Step ${_step + 1} of 2', style: AppTextStyles.bodyMuted),
            ]),
            const Spacer(),
            GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: AppColors.textMuted)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Container(height: 3, decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(width: 6),
            Expanded(child: Container(height: 3, decoration: BoxDecoration(color: _step >= 1 ? AppColors.teal : AppColors.border, borderRadius: BorderRadius.circular(2)))),
          ]),
          const SizedBox(height: 4),
        ]),
      ),

      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: _step == 0 ? _buildStep0() : _buildStep1(),
      )),

      Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 16),
        child: Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: _step > 0 ? () => setState(() { _step = 0; _errors = {}; }) : () => Navigator.pop(context),
            style: AppButtonStyle.outlined(),
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(_step > 0 ? 'Back' : 'Cancel', style: const TextStyle(color: AppColors.textSecondary))),
          )),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton(
            onPressed: _saving ? null : (_step == 0 ? () { if (_validateStep0()) setState(() => _step = 1); } : _save),
            style: AppButtonStyle.primary(),
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 14),
              child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(_step == 0 ? 'Next' : (_isEditing ? 'Update' : 'Add Clinic'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
          )),
        ]),
      ),
    ]),
  );
}