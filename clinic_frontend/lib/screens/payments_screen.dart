import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../widgets/app_widgets.dart';

Color _modeColor(String? m) => switch (m) {
  'Cash' => AppColors.statusGreen,
  'Card' => AppColors.statusBlue,
  'UPI'  => AppColors.statusPurple,
  _      => AppColors.statusGray,
};

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});
  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  List<Map<String, dynamic>> _payments = [], _bills = [], _patients = [];
  bool _loading = true;
  String _filter = 'All', _search = '';

  int get _clinicId => context.read<AppProvider>().user?['clinic_id'] ?? 1;

  @override
  void initState() { super.initState(); _fetchAll(); }

  List<Map<String, dynamic>> _decodeList(String body) {
    final d = jsonDecode(body); return d is List ? List<Map<String, dynamic>>.from(d) : [];
  }

  Future<void> _fetchAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        http.get(Uri.parse('${ApiClient.baseUrl}/payment_read?clinic_id=$_clinicId')),
        http.get(Uri.parse('${ApiClient.baseUrl}/billsread?clinic_id=$_clinicId')),
        http.get(Uri.parse('${ApiClient.baseUrl}/patient_read?clinic_id=$_clinicId')),
      ]);
      setState(() {
        _payments = _decodeList(results[0].body);
        _bills    = _decodeList(results[1].body);
        _patients = _decodeList(results[2].body);
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _filter == 'All' ? _payments : _payments.where((p) => p['payment_mode'] == _filter).toList();
    final q = _search.trim().toLowerCase();
    if (q.isNotEmpty) list = list.where((p) => '${p['patient_name'] ?? ''} ${p['invoice_number'] ?? ''}'.toLowerCase().contains(q)).toList();
    return list;
  }

  double _sum(Iterable<Map<String, dynamic>> list) =>
      list.fold(0, (s, p) => s + ((p['amount_paid'] ?? p['amount'] ?? 0) as num).toDouble());

  void _openForm({Map<String, dynamic>? payment}) => showModalBottomSheet(
    context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => _PaymentForm(
      payment: payment, bills: _bills, patients: _patients,
      existingPayments: _payments, clinicId: _clinicId, onSaved: _fetchAll),
  );

  @override
  Widget build(BuildContext context) {
    final totalAmt   = _sum(_payments);
    final cashAmt    = _sum(_payments.where((p) => p['payment_mode'] == 'Cash'));
    final digitalAmt = _sum(_payments.where((p) => p['payment_mode'] != 'Cash'));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(children: [
        AppPageHeader(title: 'Payments', subtitle: 'Payment records & transactions', actionLabel: 'Record', actionIcon: Icons.add, onAction: () => _openForm()),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(children: [
            _summaryCard('Total',   '₹${totalAmt.toStringAsFixed(0)}',   '${_payments.length} txns', AppColors.statusGreen),
            const SizedBox(width: 8),
            _summaryCard('Cash',    '₹${cashAmt.toStringAsFixed(0)}',    '${_payments.where((p) => p['payment_mode'] == 'Cash').length}', AppColors.statusGreen),
            const SizedBox(width: 8),
            _summaryCard('Digital', '₹${digitalAmt.toStringAsFixed(0)}', '${_payments.where((p) => p['payment_mode'] != 'Cash').length}', AppColors.statusPurple),
          ]),
        ),

        AppSearchBar(hint: 'Search patient, invoice…', onChanged: (v) => setState(() => _search = v)),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: ['All', 'Cash', 'Card', 'UPI'].map((f) => GestureDetector(
              onTap: () => setState(() => _filter = f),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: _filter == f ? AppColors.teal : AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _filter == f ? AppColors.teal : AppColors.border),
                ),
                child: Text(f, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: _filter == f ? Colors.white : AppColors.textSecondary)),
              ),
            )).toList()),
          ),
        ),

        Expanded(
          child: _loading ? const AppLoadingView()
              : _filtered.isEmpty ? const AppEmptyView(message: 'No payments found')
              : RefreshIndicator(
                  onRefresh: _fetchAll, color: AppColors.teal,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final p = _filtered[i];
                      final amount = p['amount_paid'] ?? p['amount'] ?? 0;
                      return AppCard(
                        child: Row(children: [
                          Container(width: 44, height: 44,
                            decoration: BoxDecoration(color: _modeColor(p['payment_mode']).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                            child: Center(child: Text(p['payment_mode']?[0] ?? '?',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _modeColor(p['payment_mode']))))),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(p['patient_name'] ?? p['payment_id'] ?? '—', style: AppTextStyles.cardTitle),
                            Text(p['invoice_number'] ?? 'Bill #${p['bill_id'] ?? '—'}', style: AppTextStyles.bodySmall),
                            if (p['payment_date'] != null)
                              Text(p['payment_date'].toString().substring(0, 10), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          ])),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text('₹$amount', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: _modeColor(p['payment_mode']).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                              child: Text(p['payment_mode'] ?? '—',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _modeColor(p['payment_mode'])))),
                            const SizedBox(height: 4),
                            GestureDetector(onTap: () => _openForm(payment: p), child: const Icon(Icons.edit_outlined, size: 14, color: AppColors.textMuted)),
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

  Widget _summaryCard(String label, String amount, String sub, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        ]),
        const SizedBox(height: 4),
        Text(amount, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        Text(sub,    style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
      ]),
    ),
  );
}

class _PaymentForm extends StatefulWidget {
  final Map<String, dynamic>? payment;
  final List<Map<String, dynamic>> bills, patients, existingPayments;
  final int clinicId;
  final VoidCallback onSaved;
  const _PaymentForm({
    this.payment,
    required this.bills,
    required this.patients,
    required this.existingPayments,
    required this.clinicId,
    required this.onSaved,
  });
  @override
  State<_PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends State<_PaymentForm> {
  int? _billId;
  String _mode = 'Cash';
  final _amountCtrl = TextEditingController();
  final _refCtrl    = TextEditingController();
  final _dateCtrl   = TextEditingController();
  bool _saving = false;
  Map<String, String> _errors = {};

  bool get _isEditing => widget.payment != null;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (widget.payment != null) {
      final p = widget.payment!;
      _billId = p['bill_id'];
      _mode   = p['payment_mode'] ?? 'Cash';
      _amountCtrl.text = (p['amount_paid'] ?? p['amount'] ?? '').toString();
      _refCtrl.text    = p['transaction_reference'] ?? '';
      _dateCtrl.text   = p['payment_date']?.toString().substring(0, 10) ?? today;
    } else {
      _dateCtrl.text = today;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  /// Returns the bill object for the selected _billId
  Map<String, dynamic>? get _selectedBill {
    if (_billId == null) return null;
    try {
      return widget.bills.firstWhere((b) => b['id'] == _billId);
    } catch (_) { return null; }
  }

  /// Total amount of the selected bill
  double get _billTotal {
    final b = _selectedBill;
    if (b == null) return double.infinity;
    return ((b['total_amount'] ?? b['total'] ?? 0) as num).toDouble();
  }

  /// Sum of all prior payments on the same bill (excluding current record when editing)
  double _paidSoFar() {
    return widget.existingPayments
        .where((p) {
          if (_isEditing && p['id'] == widget.payment!['id']) return false;
          return p['bill_id']?.toString() == _billId?.toString();
        })
        .fold(0.0, (s, p) => s + ((p['amount_paid'] ?? p['amount'] ?? 0) as num).toDouble());
  }

  String _billLabel(Map<String, dynamic> b) {
    final patient = widget.patients.firstWhere(
        (p) => p['id']?.toString() == b['patient_id']?.toString(), orElse: () => {});
    final name = patient.isEmpty
        ? 'Patient #${b['patient_id']}'
        : '${patient['first_name']} ${patient['last_name'] ?? ''}'.trim();
    return '${b['invoice_number'] ?? 'INV'} — $name';
  }

  bool _validate() {
    final e = <String, String>{};

    // VALIDATION: bill_id required
    if (_billId == null) {
      e['bill'] = 'Required';
    }

    // VALIDATION: amount_paid > 0
    final amountText = _amountCtrl.text.trim();
    if (amountText.isEmpty) {
      e['amount'] = 'Required';
    } else {
      final amount = double.tryParse(amountText) ?? 0;
      if (amount <= 0) {
        e['amount'] = 'Must be greater than 0';
      } else if (_billId != null) {
        // VALIDATION: amount_paid cannot exceed remaining bill total
        final remaining = _billTotal - _paidSoFar();
        if (amount > remaining) {
          e['amount'] = 'Cannot exceed remaining balance (₹${remaining.toStringAsFixed(2)})';
        }
      }
    }

    // VALIDATION: payment_mode required (already enforced by default but check for empty)
    if (_mode.isEmpty) e['mode'] = 'Required';

    // VALIDATION: transaction_reference required for Card/UPI
    if ((_mode == 'Card' || _mode == 'UPI') && _refCtrl.text.trim().isEmpty) {
      e['ref'] = 'Required for $_mode payments';
    }

    // VALIDATION: payment_date cannot be in future
    if (_dateCtrl.text.isEmpty) {
      e['date'] = 'Required';
    } else {
      try {
        final payDate = DateTime.parse(_dateCtrl.text.substring(0, 10));
        final today   = DateTime.now();
        if (payDate.isAfter(DateTime(today.year, today.month, today.day))) {
          e['date'] = 'Payment date cannot be in the future';
        }
      } catch (_) {
        e['date'] = 'Invalid date format';
      }
    }

    // VALIDATION: duplicate payment check (same bill, same amount, same date, same mode — excluding self when editing)
    if (_billId != null && e.isEmpty) {
      final isDuplicate = widget.existingPayments.any((p) {
        if (_isEditing && p['id'] == widget.payment!['id']) return false;
        final sameMode   = (p['payment_mode'] ?? '') == _mode;
        final sameBill   = p['bill_id']?.toString() == _billId.toString();
        final sameDate   = (p['payment_date']?.toString().substring(0, 10) ?? '') == _dateCtrl.text;
        final sameAmount = ((p['amount_paid'] ?? p['amount'] ?? 0) as num).toDouble()
            == (double.tryParse(_amountCtrl.text) ?? -1);
        return sameMode && sameBill && sameDate && sameAmount;
      });
      if (isDuplicate) e['amount'] = 'A duplicate payment already exists for this bill';
    }

    setState(() => _errors = e);
    return e.isEmpty;
  }

  Future<void> _save() async {
    if (!_validate()) return;
    setState(() => _saving = true);
    try {
      final res = await http.post(
        Uri.parse('${ApiClient.baseUrl}/payment_create_update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': widget.payment?['id'], 'bill_id': _billId, 'payment_mode': _mode,
          'amount_paid': double.tryParse(_amountCtrl.text) ?? 0,
          'transaction_reference': _refCtrl.text.isEmpty ? null : _refCtrl.text,
          'payment_date': _dateCtrl.text.isEmpty ? DateTime.now().toIso8601String() : _dateCtrl.text,
           'created_by': 'admin',
        }),
      );
      if (res.statusCode == 200 || res.statusCode == 201) { Navigator.pop(context); widget.onSaved(); }
    } catch (_) {}
    setState(() => _saving = false);
  }

  Widget _errText(String t) => Padding(padding: const EdgeInsets.only(top: 4),
    child: Text(t, style: const TextStyle(fontSize: 11, color: AppColors.statusRed)));

  @override
  Widget build(BuildContext context) => Container(
    height: MediaQuery.of(context).size.height * 0.85,
    decoration: const BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    child: Column(children: [
      AppSheetHeader(title: _isEditing ? 'Edit Payment' : 'Record Payment'),
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // VALIDATION: bill_id required
          Text('Bill / Invoice *', style: AppTextStyles.label),
          const SizedBox(height: 6),
          DropdownButtonFormField<int>(
            value: _billId,
            onChanged: (v) => setState(() { _billId = v; _errors.remove('bill'); }),
            hint: Text('Select bill', style: AppTextStyles.hint),
            items: widget.bills.map((b) => DropdownMenuItem<int>(value: b['id'],
                child: Text(_billLabel(b), style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
            decoration: AppInput.deco(''),
          ),
          if (_errors['bill'] != null) _errText(_errors['bill']!),

          // Show remaining balance when a bill is selected
          if (_billId != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: AppColors.statusBlueBg, borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.info_outline, size: 13, color: AppColors.statusBlue),
                const SizedBox(width: 6),
                Text(
                  'Bill total: ₹${_billTotal.toStringAsFixed(2)}  ·  Paid: ₹${_paidSoFar().toStringAsFixed(2)}  ·  Remaining: ₹${(_billTotal - _paidSoFar()).toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.statusBlue),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 14),

          // VALIDATION: payment_mode required
          Text('Payment Mode *', style: AppTextStyles.label),
          const SizedBox(height: 6),
          Row(children: ['Cash', 'Card', 'UPI'].map((m) => GestureDetector(
            onTap: () => setState(() { _mode = m; _errors.remove('mode'); _errors.remove('ref'); }),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _mode == m ? AppColors.teal : AppColors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _mode == m ? AppColors.teal : AppColors.border),
              ),
              child: Text(m, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: _mode == m ? Colors.white : AppColors.textSecondary)),
            ),
          )).toList()),
          if (_errors['mode'] != null) _errText(_errors['mode']!),
          const SizedBox(height: 14),

          Row(children: [
            // VALIDATION: amount > 0 & cannot exceed bill total
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AppFormField(label: 'Amount (₹) *', controller: _amountCtrl,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() => _errors.remove('amount'))),
              if (_errors['amount'] != null) _errText(_errors['amount']!),
            ])),
            const SizedBox(width: 12),
            // VALIDATION: payment_date not in future
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Payment Date *', style: AppTextStyles.label),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () async {
                  final d = await showDatePicker(context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020), lastDate: DateTime.now(), // lastDate = today prevents future
                    builder: (c, child) => Theme(data: Theme.of(c).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.teal)), child: child!));
                  if (d != null) setState(() { _dateCtrl.text = d.toIso8601String().substring(0, 10); _errors.remove('date'); });
                },
                child: AbsorbPointer(child: TextField(controller: _dateCtrl,
                    decoration: AppInput.deco('YYYY-MM-DD', icon: Icons.calendar_today_outlined))),
              ),
              if (_errors['date'] != null) _errText(_errors['date']!),
            ])),
          ]),

          // VALIDATION: transaction_reference required for Card/UPI
          if (_mode != 'Cash') ...[
            const SizedBox(height: 14),
            AppFormField(
              label: 'Transaction Reference ${_mode != 'Cash' ? '*' : ''}',
              controller: _refCtrl,
              hint: '${_mode == 'UPI' ? 'UPI' : 'Card'} reference number…',
              onChanged: (_) => setState(() => _errors.remove('ref')),
            ),
            if (_errors['ref'] != null) _errText(_errors['ref']!),
          ],
        ]),
      )),
      AppFormButtons(saving: _saving, onCancel: () => Navigator.pop(context), onSave: _save,
          saveLabel: _isEditing ? 'Update Payment' : 'Save Payment'),
    ]),
  );
}