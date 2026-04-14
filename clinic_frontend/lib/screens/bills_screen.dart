import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../widgets/app_widgets.dart';

Color _statusColor(String? s) => switch (s) {
  'Paid'    => AppColors.statusGreen,
  'Unpaid'  => AppColors.statusRed,
  'Partial' => AppColors.statusOrange,
  _         => AppColors.statusGray,
};
Color _statusBg(String? s) => switch (s) {
  'Paid'    => AppColors.statusGreenBg,
  'Unpaid'  => AppColors.statusRedBg,
  'Partial' => AppColors.statusOrangeBg,
  _         => AppColors.statusGrayBg,
};

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});
  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  List<Map<String, dynamic>> _bills = [], _patients = [], _encounters = [];
  bool _loading = true;
  String _search = '';

  int get _clinicId => context.read<AppProvider>().user?['clinic_id'] ?? 1;

  @override
  void initState() { super.initState(); _fetchAll(); }

  List<Map<String, dynamic>> _decodeList(String body) {
    final d = jsonDecode(body);
    return d is List ? List<Map<String, dynamic>>.from(d) : [];
  }

  Future<void> _fetchAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        http.get(Uri.parse('${ApiClient.baseUrl}/billsread?clinic_id=$_clinicId')),
        http.get(Uri.parse('${ApiClient.baseUrl}/patient_read?clinic_id=$_clinicId')),
        http.get(Uri.parse('${ApiClient.baseUrl}/encountersread?clinic_id=$_clinicId')),
      ]);
      setState(() {
        _bills     = _decodeList(results[0].body);
        _patients  = _decodeList(results[1].body);
        _encounters = _decodeList(results[2].body);
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _bills;
    return _bills.where((b) =>
      '${b['invoice_number'] ?? ''} ${b['patient_name'] ?? ''}'.toLowerCase().contains(q)).toList();
  }

  void _openForm({Map<String, dynamic>? bill}) => showModalBottomSheet(
    context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => _BillForm(bill: bill, patients: _patients, encounters: _encounters, clinicId: _clinicId, onSaved: _fetchAll),
  );

  Future<void> _delete(Map<String, dynamic> bill) async {
    if (!await confirmDelete(context, title: 'Delete Bill', message: 'Delete invoice ${bill['invoice_number']}?')) return;
    try {
      await http.delete(Uri.parse('${ApiClient.baseUrl}/bills_delete/'),
          headers: {'Content-Type': 'application/json'}, body: jsonEncode({'id': bill['id']}));
      _fetchAll();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: Column(children: [
      AppPageHeader(title: 'Bills & Invoices', subtitle: 'Manage billing and invoices', actionLabel: 'New Invoice', actionIcon: Icons.add, onAction: () => _openForm()),
      AppSearchBar(hint: 'Search invoice #, patient…', onChanged: (v) => setState(() => _search = v)),
      Expanded(
        child: _loading ? const AppLoadingView()
            : _filtered.isEmpty ? const AppEmptyView(message: 'No bills found')
            : RefreshIndicator(
                onRefresh: _fetchAll, color: AppColors.teal,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final b = _filtered[i];
                    return AppCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Container(padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: AppColors.statusBlueBg, borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.receipt_long_outlined, size: 16, color: AppColors.statusBlue)),
                          const SizedBox(width: 10),
                          Expanded(child: Text(b['invoice_number'] ?? '—',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary))),
                          AppStatusBadge(label: b['status'] ?? '—', color: _statusColor(b['status']), bg: _statusBg(b['status'])),
                        ]),
                        const SizedBox(height: 8),
                        Text(b['patient_name'] ?? '—', style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                        if (b['chief_complaint'] != null)
                          Text(b['chief_complaint'], style: AppTextStyles.bodyMuted),
                        const SizedBox(height: 10),
                        Row(children: [
                          _billStat('Subtotal', '₹${b['subtotal'] ?? 0}'),
                          _billStat('GST',      '₹${b['gst_amount'] ?? 0}'),
                          _billStat('Discount', '₹${b['discount'] ?? 0}'),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            const Text('Total', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                            Text('₹${b['total_amount'] ?? b['total'] ?? 0}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          ])),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          Text(b['created_at']?.toString().substring(0, 10) ?? b['bill_date']?.toString().substring(0, 10) ?? '—',
                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          const Spacer(),
                          GestureDetector(onTap: () => _openForm(bill: b), child: const Icon(Icons.edit_outlined, size: 16, color: AppColors.textMuted)),
                          const SizedBox(width: 12),
                          GestureDetector(onTap: () => _delete(b), child: const Icon(Icons.delete_outline, size: 16, color: AppColors.statusRed)),
                        ]),
                      ]),
                    );
                  },
                ),
              ),
      ),
    ]),
  );

  Widget _billStat(String label, String value) => Expanded(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
      Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
    ]),
  );
}

class _BillForm extends StatefulWidget {
  final Map<String, dynamic>? bill;
  final List<Map<String, dynamic>> patients, encounters;
  final int clinicId;
  final VoidCallback onSaved;
  const _BillForm({this.bill, required this.patients, required this.encounters, required this.clinicId, required this.onSaved});
  @override
  State<_BillForm> createState() => _BillFormState();
}

class _BillFormState extends State<_BillForm> {
  int? _patientId, _encounterId;
  String _status = 'Unpaid';
  final _invoiceCtrl  = TextEditingController();
  final _subtotalCtrl = TextEditingController();
  final _gstCtrl      = TextEditingController();
  final _discountCtrl = TextEditingController();
  bool _saving = false;
  Map<String, String> _errors = {};

  double get _total {
    final s = double.tryParse(_subtotalCtrl.text) ?? 0;
    final g = double.tryParse(_gstCtrl.text) ?? 0;
    final d = double.tryParse(_discountCtrl.text) ?? 0;
    return (s + g - d).clamp(0, double.infinity);
  }

  @override
  void initState() {
    super.initState();
    if (widget.bill != null) {
      final b = widget.bill!;
      _patientId  = b['patient_id'];
      _encounterId = b['encounter_id'];
      _status     = b['status'] ?? 'Unpaid';
      _invoiceCtrl.text  = b['invoice_number'] ?? '';
      _subtotalCtrl.text = b['subtotal']?.toString() ?? '';
      _gstCtrl.text      = b['gst_amount']?.toString() ?? '';
      _discountCtrl.text = b['discount']?.toString() ?? '';
    } else {
      _fetchNextInvoice();
    }
    for (final c in [_subtotalCtrl, _gstCtrl, _discountCtrl]) {
      c.addListener(() {
        setState(() {});
      });
    }
  }

  Future<void> _fetchNextInvoice() async {
    try {
      final res = await http.get(Uri.parse('${ApiClient.baseUrl}/bills_next_invoice?clinic_id=${widget.clinicId}'));
      final data = jsonDecode(res.body);
      if (mounted) setState(() => _invoiceCtrl.text = data['invoice_number'] ?? '');
    } catch (_) {}
  }

  bool _validate() {
    final e = <String, String>{};
    if (_patientId == null) e['patient'] = 'Required';
    if (_subtotalCtrl.text.trim().isEmpty) e['subtotal'] = 'Required';
    setState(() => _errors = e);
    return e.isEmpty;
  }

  Future<void> _save() async {
    if (!_validate()) return;
    setState(() => _saving = true);
    try {
      final payload = {
        'clinic_id': widget.clinicId,
        'patient_id': _patientId,
        'encounter_id': _encounterId,
        'invoice_number': _invoiceCtrl.text,
        'status': _status,
        'subtotal': double.tryParse(_subtotalCtrl.text) ?? 0,
        'gst_amount': double.tryParse(_gstCtrl.text) ?? 0,
        'discount': double.tryParse(_discountCtrl.text) ?? 0,
        'total_amount': _total,
        'created_by': 'admin',
      };
      if (widget.bill != null && widget.bill!['id'] != null) {
        payload['id'] = widget.bill!['id'];
      }
      final res = await http.post(
        Uri.parse('${ApiClient.baseUrl}/bills_create_update/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 201) {
        showSnack(context, widget.bill != null ? 'Invoice updated' : 'Invoice created');
        Navigator.pop(context);
        widget.onSaved();
      } else {
        showSnack(context, 'Failed to save invoice (${res.statusCode})', isError: true);
      }
    } catch (e) {
      if (mounted) {
        showSnack(context, 'Failed to save invoice: ${e.toString()}', isError: true);
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  List<Map<String, dynamic>> get _patientEncounters =>
      widget.encounters.where((e) => e['patient_id']?.toString() == _patientId?.toString()).toList();

  Widget _errText(String t) => Padding(padding: const EdgeInsets.only(top: 4),
    child: Text(t, style: const TextStyle(fontSize: 11, color: AppColors.statusRed)));

  @override
  Widget build(BuildContext context) => Container(
    height: MediaQuery.of(context).size.height * 0.9,
    decoration: const BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    child: Column(children: [
      AppSheetHeader(title: widget.bill != null ? 'Edit Invoice' : 'New Invoice'),
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Patient *', style: AppTextStyles.label),
          const SizedBox(height: 6),
          DropdownButtonFormField<int>(
            value: _patientId,
            onChanged: (v) => setState(() { _patientId = v; _encounterId = null; _errors.remove('patient'); }),
            hint: const Text('Select patient', style: AppTextStyles.hint),
            items: widget.patients.map((p) => DropdownMenuItem<int>(value: p['id'],
                child: Text('${p['first_name']} ${p['last_name'] ?? ''}'.trim(), style: const TextStyle(fontSize: 13)))).toList(),
            decoration: AppInput.deco(''),
          ),
          if (_errors['patient'] != null) _errText(_errors['patient']!),
          const SizedBox(height: 14),

          if (_patientId != null && _patientEncounters.isNotEmpty) ...[
            AppDropdownField<int>(
              label: 'Encounter (optional)', value: _encounterId,
              items: _patientEncounters.map((e) => DropdownMenuItem<int>(value: e['id'],
                  child: Text('${e['chief_complaint'] ?? 'Encounter #${e['id']}'}', style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) => setState(() => _encounterId = v),
            ),
            const SizedBox(height: 14),
          ],

          Row(children: [
            Expanded(child: AppFormField(label: 'Invoice Number', controller: _invoiceCtrl, hint: 'INV-0001')),
            const SizedBox(width: 12),
            Expanded(child: AppDropdownField<String>(
              label: 'Status', value: _status,
              items: ['Unpaid', 'Paid', 'Partial'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) => setState(() => _status = v!),
            )),
          ]),
          const SizedBox(height: 14),

          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AppFormField(label: 'Subtotal (₹) *', controller: _subtotalCtrl, keyboardType: TextInputType.number),
              if (_errors['subtotal'] != null) _errText(_errors['subtotal']!),
            ])),
            const SizedBox(width: 12),
            Expanded(child: AppFormField(label: 'GST (₹)', controller: _gstCtrl, keyboardType: TextInputType.number)),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: AppFormField(label: 'Discount (₹)', controller: _discountCtrl, keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.statusGreenBg, borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Total Amount', style: TextStyle(fontSize: 11, color: AppColors.teal)),
                const SizedBox(height: 4),
                Text('₹${_total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.teal)),
              ]),
            )),
          ]),
        ]),
      )),
      AppFormButtons(saving: _saving, onCancel: () => Navigator.pop(context), onSave: _save,
          saveLabel: widget.bill != null ? 'Update Invoice' : 'Create Invoice'),
    ]),
  );
}
