import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../widgets/app_widgets.dart';

// ─── Constants ────────────────────────────────────────────────────────────────

const _cats = [
  'Tablet', 'Capsule', 'Syrup', 'Injection', 'Tonic',
  'Ointment', 'Drops', 'Powder', 'Cream', 'Inhaler', 'Patch', 'Suppository',
];
const _wholeCats = {'Tablet', 'Capsule', 'Injection', 'Patch', 'Suppository'};
final _batchRx = RegExp(r'^[A-Za-z0-9\-]{3,20}$');

// ─── Tiny helpers ─────────────────────────────────────────────────────────────

bool _expired(String? d) {
  if (d == null || d.isEmpty) return false;
  try { return DateTime.parse(d.substring(0, 10)).isBefore(_today()); } catch (_) { return false; }
}

bool _expiringSoon(String? d) {
  if (d == null || d.isEmpty) return false;
  try {
    final dt = DateTime.parse(d.substring(0, 10));
    final now = DateTime.now();
    return dt.isAfter(now) && dt.isBefore(now.add(const Duration(days: 90)));
  } catch (_) { return false; }
}

DateTime _today() => DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0);

// Returns (fgColor, bgColor, label) for a stock quantity
({Color fg, Color bg, String label}) _stockLevel(double n) => n == 0
    ? (fg: AppColors.statusRed,    bg: AppColors.statusRedBg,    label: 'Out of Stock')
    : n < 20
        ? (fg: AppColors.statusRed,    bg: AppColors.statusRedBg,    label: 'Low')
        : n <= 50
            ? (fg: AppColors.statusOrange, bg: AppColors.statusOrangeBg, label: 'Medium')
            : (fg: AppColors.teal,         bg: AppColors.statusGreenBg,  label: 'Good');

/// Net stock = totalIN − totalOUT (non-deleted, non-expired records only)
Map<String, dynamic> _netStock(
  List<Map<String, dynamic>> inv,
  String name,
  String dosage, {
  double pending = 0,
  String? excludeId,
}) {
  final nm = name.toLowerCase();
  final nd = dosage.trim().toLowerCase();
  final active = inv.where((i) => i['is_deleted'] != true && i['deleted'] != true).toList();

  final ins = active.where((i) {
    final n2 = (i['medicine_name'] ?? i['category_name'] ?? '').toLowerCase();
    final d2 = (i['dosage'] ?? '').trim().toLowerCase();
    return i['transaction_type'] == 'IN'
        && n2 == nm
        && (nd.isEmpty || d2 == nd)
        && !_expired(i['expiry_date']?.toString())
        && i['transaction_id']?.toString() != excludeId;
  }).toList();

  if (ins.isEmpty) return {'rec': null, 'qty': 0.0};

  final totalIn   = ins.fold<double>(0, (s, i) => s + (double.tryParse(i['quantity']?.toString() ?? '0') ?? 0));
  final batches   = ins.map((i) => i['batch_no']).where((b) => b != null).toSet();
  final totalSold = active.where((i) {
    final n2 = (i['medicine_name'] ?? i['category_name'] ?? '').toLowerCase();
    final d2 = (i['dosage'] ?? '').trim().toLowerCase();
    return i['transaction_type'] == 'OUT'
        && n2 == nm
        && (nd.isEmpty || d2 == nd)
        && (batches.isEmpty || batches.contains(i['batch_no']));
  }).fold<double>(0, (s, i) => s + (double.tryParse(i['quantity']?.toString() ?? '0') ?? 0));

  return {'rec': ins.last, 'qty': (totalIn - totalSold - pending).clamp(0.0, double.infinity)};
}

// ─── Sale line item ───────────────────────────────────────────────────────────

class _Sale {
  final int id;
  final String medicine, dosage, batchNo, expiryDate;
  final double qty, salePrice, purchasePrice;
  _Sale({
    required this.id, required this.medicine, required this.dosage,
    required this.qty, required this.salePrice, required this.purchasePrice,
    required this.batchNo, required this.expiryDate,
  });
  double get total => qty * salePrice;
}

// ─── Inventory Screen ─────────────────────────────────────────────────────────

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String _search = '', _tab = 'IN';

  int get _clinicId => context.read<AppProvider>().user?['clinic_id'] ?? 1;

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(Uri.parse('${ApiClient.baseUrl}/inventory_transactions_read?clinic_id=$_clinicId'));
      final data = jsonDecode(res.body);
      if (data is List) setState(() => _items = List<Map<String, dynamic>>.from(data));
    } catch (_) {}
    setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _search.trim().toLowerCase();
    var list = _items
        .where((i) => i['is_deleted'] != true && i['deleted'] != true && (i['transaction_type'] ?? 'IN') == _tab)
        .toList();
    if (q.isNotEmpty) {
      list = list.where((i) =>
          '${i['medicine_name']} ${i['batch_no']} ${i['category_name']}'.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  // ── Stats ──
  int get _totalMeds => _items
      .where((i) => i['is_deleted'] != true && i['transaction_type'] == 'IN')
      .map((i) => i['medicine_name']).toSet().length;

  int get _lowStock {
    final seen = <String>{};
    int c = 0;
    for (final i in _items.where((i) => i['is_deleted'] != true && i['transaction_type'] == 'IN')) {
      final n = (i['medicine_name'] ?? '').toString();
      if (!seen.add(n)) continue;
      if ((_netStock(_items, n, i['dosage']?.toString() ?? '')['qty'] as double) <= 5) c++;
    }
    return c;
  }

  int get _soonExpiring => _items.where((i) => _expiringSoon(i['expiry_date']?.toString())).length;

  // ── Actions ──
  void _openForm({Map<String, dynamic>? item}) => _sheet(_InventoryForm(
        item: item, clinicId: _clinicId, existing: _items, onSaved: _fetch));

  void _openSales() => _sheet(_SalesSheet(inv: _items, clinicId: _clinicId, onSaved: _fetch));

  void _sheet(Widget w) => showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => w);

  Future<void> _delete(Map<String, dynamic> item) async {
    if (!await confirmDelete(context, title: 'Delete Item', message: 'Delete ${item['medicine_name']}?')) return;
    try {
      await http.delete(Uri.parse('${ApiClient.baseUrl}/inventory_transactions_soft_delete/'),
          headers: {'Content-Type': 'application/json'}, body: jsonEncode({'id': item['id']}));
      _fetch();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: Column(children: [
      // Header
      Container(
        color: AppColors.surfaceCard,
        padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 14, 20, 14),
        child: Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Inventory', style: AppTextStyles.pageTitle),
            SizedBox(height: 3),
            Text('Medicine stock management', style: AppTextStyles.pageSubtitle),
          ])),
          // Sales button
          GestureDetector(
            onTap: _openSales,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.teal.withOpacity(0.5), width: 1.5),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.shopping_cart_outlined, size: 14, color: AppColors.teal),
                SizedBox(width: 5),
                Text('Sales', style: TextStyle(color: AppColors.teal, fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          // Add button
          GestureDetector(
            onTap: () => _openForm(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.teal, AppColors.teal2],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add, size: 15, color: Colors.white),
                SizedBox(width: 6),
                Text('Add', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
      ),

      AppStatsRow(stats: [
        AppStatData('Medicines',  _totalMeds,    AppColors.statusBlue,   AppColors.statusBlueBg,   Icons.grid_view_rounded),
        AppStatData('Low Stock',  _lowStock,     AppColors.statusOrange, AppColors.statusOrangeBg, Icons.warning_amber_outlined),
        AppStatData('Expiring',   _soonExpiring, AppColors.statusRed,    AppColors.statusRedBg,    Icons.schedule_outlined),
      ]),

      // Search + tab toggle
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(children: [
          Expanded(child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: AppInput.deco('Search medicine, batch…', icon: Icons.search))),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(color: AppColors.white,
                borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
            child: Row(mainAxisSize: MainAxisSize.min, children: ['IN', 'OUT'].map((t) => GestureDetector(
              onTap: () => setState(() => _tab = t),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                    color: _tab == t ? AppColors.teal : Colors.transparent,
                    borderRadius: BorderRadius.circular(9)),
                child: Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: _tab == t ? Colors.white : AppColors.textSecondary)),
              ),
            )).toList()),
          ),
        ]),
      ),

      Expanded(
        child: _loading
            ? const AppLoadingView()
            : _filtered.isEmpty
                ? const AppEmptyView(message: 'No items found')
                : RefreshIndicator(
                    onRefresh: _fetch, color: AppColors.teal,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final item = _filtered[i];
                        final exp = _expired(item['expiry_date']?.toString());
                        final name   = item['medicine_name'] ?? '';
                        final dosage = item['dosage'] ?? '';
                        final net    = item['transaction_type'] == 'IN'
                            ? _netStock(_items, name, dosage)['qty'] as double
                            : (double.tryParse(item['quantity']?.toString() ?? '0') ?? 0);
                        final sl     = _stockLevel(net);

                        return AppCard(
                          child: Row(children: [
                            Container(width: 44, height: 44,
                              decoration: BoxDecoration(color: AppColors.statusGreenBg, borderRadius: BorderRadius.circular(10)),
                              child: const Center(child: Icon(Icons.medication_outlined, color: AppColors.teal, size: 22))),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(name, style: AppTextStyles.cardTitle),
                              Text('$dosage · Batch: ${item['batch_no'] ?? '—'}', style: AppTextStyles.bodySmall),
                              const SizedBox(height: 4),
                              Row(children: [
                                // Stock badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: sl.bg, borderRadius: BorderRadius.circular(6)),
                                  child: Text(
                                    '${net.toStringAsFixed(net.truncateToDouble() == net ? 0 : 1)} — ${sl.label}',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: sl.fg),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text('₹${item['sale_price'] ?? 0}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                              ]),
                            ])),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              if (item['expiry_date'] != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: exp ? AppColors.statusRedBg : AppColors.statusGreenBg,
                                      borderRadius: BorderRadius.circular(6)),
                                  child: Text(item['expiry_date'].toString().substring(0, 10),
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                                          color: exp ? AppColors.statusRed : AppColors.teal)),
                                ),
                              const SizedBox(height: 8),
                              Row(children: [
                                GestureDetector(onTap: () => _openForm(item: item),
                                    child: const Icon(Icons.edit_outlined, size: 16, color: AppColors.textMuted)),
                                const SizedBox(width: 10),
                                GestureDetector(onTap: () => _delete(item),
                                    child: const Icon(Icons.delete_outline, size: 16, color: AppColors.statusRed)),
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

// ─── Sales Sheet ──────────────────────────────────────────────────────────────

class _SalesSheet extends StatefulWidget {
  final List<Map<String, dynamic>> inv;
  final int clinicId;
  final VoidCallback onSaved;
  const _SalesSheet({required this.inv, required this.clinicId, required this.onSaved});
  @override
  State<_SalesSheet> createState() => _SalesSheetState();
}

class _SalesSheetState extends State<_SalesSheet> {
  final _medCtrl    = TextEditingController();
  final _dosageCtrl = TextEditingController();
  final _qtyCtrl    = TextEditingController();
  List<_Sale> _list = [];
  bool _saving = false;
  String? _selMed;

  @override
  void dispose() { _medCtrl.dispose(); _dosageCtrl.dispose(); _qtyCtrl.dispose(); super.dispose(); }

  // ── Derived state ──

  List<String> get _medOptions {
    final seen = <String>{};
    final result = <String>[];
    for (final i in widget.inv) {
      if (i['is_deleted'] == true || i['deleted'] == true) continue;
      if (i['transaction_type'] != 'IN') continue;
      if (_expired(i['expiry_date']?.toString())) continue;
      final nm = (i['medicine_name'] ?? i['category_name'] ?? '').toString();
      if (nm.isEmpty || !seen.add(nm)) continue;
      final pending = _list.where((s) => s.medicine.toLowerCase() == nm.toLowerCase()).fold<double>(0, (s, x) => s + x.qty);
      if ((_netStock(widget.inv, nm, '', pending: pending)['qty'] as double) > 0) result.add(nm);
    }
    return result;
  }

  List<String> get _dosages {
    if (_selMed == null) return [];
    return widget.inv.where((i) =>
        i['is_deleted'] != true && i['deleted'] != true &&
        i['transaction_type'] == 'IN' &&
        !_expired(i['expiry_date']?.toString()) &&
        (i['medicine_name'] ?? i['category_name'] ?? '').toString().toLowerCase() == _selMed!.toLowerCase() &&
        (i['dosage'] ?? '').toString().isNotEmpty)
        .map((i) => i['dosage'].toString()).toSet().toList();
  }

  Map<String, dynamic> get _stock {
    if (_selMed == null) return {'rec': null, 'qty': 0.0};
    final pending = _list.where((s) => s.medicine.toLowerCase() == _selMed!.toLowerCase())
        .fold<double>(0, (s, x) => s + x.qty);
    return _netStock(widget.inv, _selMed!, _dosageCtrl.text.trim(), pending: pending);
  }

  double get _avail => (_stock['qty'] as double?) ?? 0;
  Map<String, dynamic>? get _rec => _stock['rec'] as Map<String, dynamic>?;
  double get _grandTotal => _list.fold(0, (s, x) => s + x.total);

  double? get _lineTotal {
    final qty   = double.tryParse(_qtyCtrl.text);
    final price = double.tryParse(_rec?['sale_price']?.toString() ?? '');
    return qty != null && price != null ? qty * price : null;
  }

  // ── Actions ──

  void _selectMed(String nm) => setState(() {
    _selMed = nm; _medCtrl.text = nm; _dosageCtrl.clear(); _qtyCtrl.clear();
  });

  void _addItem() {
    if (_selMed == null || _selMed!.isEmpty) return showSnack(context, 'Select a medicine', isError: true);
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (qty <= 0) return showSnack(context, 'Enter a valid quantity', isError: true);

    final cat = widget.inv.firstWhere(
        (i) => (i['medicine_name'] ?? i['category_name'] ?? '').toString() == _selMed,
        orElse: () => {})['category_name']?.toString();
    if (cat != null && _wholeCats.contains(cat) && qty != qty.floorToDouble())
      return showSnack(context, '$cat quantity must be a whole number', isError: true);

    if (_rec == null)     return showSnack(context, 'Medicine not found in stock', isError: true);
    if (_expired(_rec!['expiry_date']?.toString()))
                          return showSnack(context, 'This medicine has expired', isError: true);
    if (qty > _avail)     return showSnack(context, 'Only ${_avail.toStringAsFixed(0)} units available', isError: true);

    final isDup = _list.any((s) =>
        s.medicine.toLowerCase() == _selMed!.toLowerCase() &&
        s.dosage.toLowerCase() == _dosageCtrl.text.trim().toLowerCase());

    if (isDup) {
      showDialog(context: context, builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Duplicate Medicine'),
        content: Text('"$_selMed" is already in the list. Add another line?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () { Navigator.pop(context); _doAdd(qty); }, child: const Text('Add')),
        ],
      ));
      return;
    }
    _doAdd(qty);
  }

  void _doAdd(double qty) {
    final r = _rec!;
    setState(() {
      _list.add(_Sale(
        id: DateTime.now().millisecondsSinceEpoch, medicine: _selMed!,
        dosage: _dosageCtrl.text.trim(), qty: qty,
        salePrice:     double.tryParse(r['sale_price']?.toString()     ?? '0') ?? 0,
        purchasePrice: double.tryParse(r['purchase_price']?.toString() ?? '0') ?? 0,
        batchNo:    r['batch_no']?.toString()    ?? '',
        expiryDate: r['expiry_date']?.toString() ?? '',
      ));
      _selMed = null; _medCtrl.clear(); _dosageCtrl.clear(); _qtyCtrl.clear();
    });
  }

  Future<void> _submit() async {
    if (_list.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      for (final s in _list) {
        final res = await http.post(
          Uri.parse('${ApiClient.baseUrl}/inventory_create_update'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'transaction_id': 0, 'clinic_id': widget.clinicId, 'created_by': 'admin',
            'category_name': s.medicine, 'medicine_name': s.medicine,
            'dosage': s.dosage, 'transaction_type': 'OUT',
            'batch_no': s.batchNo,
            'expiry_date': s.expiryDate.isNotEmpty ? s.expiryDate.substring(0, 10) : '',
            'quantity': s.qty, 'purchase_price': s.purchasePrice,
            'sale_price': s.salePrice, 'remarks': 'Sale', 'transaction_date': today,
          }),
        );
        if (res.statusCode != 200 && res.statusCode != 201) {
          final d = jsonDecode(res.body);
          throw Exception(d['error'] ?? 'Sale failed');
        }
      }
      if (mounted) {
        showSnack(context, '${_list.length} sale(s) recorded');
        widget.onSaved();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    }
    if (mounted) setState(() => _saving = false);
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final sl     = _stockLevel(_avail);
    final dosages = _dosages;
    final lt     = _lineTotal;

    return _SheetScaffold(
      title: 'Add Sale',
      // gradient stock-status banner
      banner: _selMed != null ? Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFFECFDF5), Color(0xFFE0F2FE)],
              begin: Alignment.centerLeft, end: Alignment.centerRight),
          border: Border(bottom: BorderSide(color: Color(0xFFD1FAE5), width: 1)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: sl.fg, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            _avail == 0
                ? 'Out of stock'
                : '${_avail.toStringAsFixed(0)} units — ${sl.label} Stock',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sl.fg),
          ),
        ]),
      ) : null,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Medicine search
        Text('MEDICINE NAME *', style: AppTextStyles.label),
        const SizedBox(height: 6),
        _MedSearch(controller: _medCtrl, options: _medOptions, onSelected: _selectMed),
        const SizedBox(height: 14),

        // Dosage
        AppFormField(label: 'Dosage', controller: _dosageCtrl, hint: 'e.g. 500mg',
            onChanged: (_) => setState(() {})),
        if (dosages.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, children: dosages.map((d) {
            final sel = _dosageCtrl.text.trim() == d;
            return GestureDetector(
              onTap: () => setState(() { _dosageCtrl.text = d; _qtyCtrl.clear(); }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: sel ? AppColors.teal : AppColors.statusGreenBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? AppColors.teal : AppColors.teal.withOpacity(0.3)),
                ),
                child: Text(d, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : AppColors.teal)),
              ),
            );
          }).toList()),
        ],
        const SizedBox(height: 14),

        // Expiry (read-only)
        Text('EXPIRY DATE', style: AppTextStyles.label),
        const SizedBox(height: 6),
        _ReadonlyField(
          isError: _rec != null && _expired(_rec!['expiry_date']?.toString()),
          icon: Icons.calendar_today_outlined,
          child: Row(children: [
            Text(
              _rec?['expiry_date'] != null ? _rec!['expiry_date'].toString().substring(0, 10) : '—',
              style: TextStyle(
                fontSize: 13,
                color: (_rec != null && _expired(_rec!['expiry_date']?.toString()))
                    ? AppColors.statusRed : AppColors.textSecondary,
                fontWeight: (_rec != null && _expired(_rec!['expiry_date']?.toString()))
                    ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (_rec != null && _expired(_rec!['expiry_date']?.toString())) ...[
              const SizedBox(width: 6),
              const Text('— Expired, cannot sell',
                  style: TextStyle(fontSize: 12, color: AppColors.statusRed, fontWeight: FontWeight.w600)),
            ],
          ]),
        ),
        const SizedBox(height: 14),

        // Quantity
        AppFormField(label: 'Quantity to Sell *', controller: _qtyCtrl,
            keyboardType: TextInputType.number, hint: '0', onChanged: (_) => setState(() {})),
        const SizedBox(height: 14),

        // Line total
        if (lt != null) _TotalBadge(label: 'Total Price', amount: lt),
        const SizedBox(height: 14),

        SizedBox(
          width: double.infinity, height: 46,
          child: ElevatedButton.icon(
            onPressed: _addItem, style: AppButtonStyle.primary(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Sale', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ),
        ),
        const SizedBox(height: 20),

        // Sale list
        if (_list.isNotEmpty) ...[
          Text('SALE ITEMS', style: AppTextStyles.label),
          const SizedBox(height: 10),
          ..._list.map((s) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border.withOpacity(0.5))),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.medicine, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.teal)),
                const SizedBox(height: 2),
                Text('${s.dosage.isNotEmpty ? s.dosage : '—'} · ${s.qty.toStringAsFixed(s.qty.truncateToDouble() == s.qty ? 0 : 1)} units',
                    style: AppTextStyles.bodySmall),
                const SizedBox(height: 2),
                Text(fmtCurrency(s.total),
                    style: const TextStyle(fontSize: 12, color: AppColors.statusGreen, fontWeight: FontWeight.w600)),
              ])),
              GestureDetector(
                onTap: () => setState(() => _list.removeWhere((x) => x.id == s.id)),
                child: Container(width: 28, height: 28,
                  decoration: BoxDecoration(color: AppColors.statusRedBg, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.delete_outline, size: 14, color: AppColors.statusRed)),
              ),
            ]),
          )),
          // Grand total
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: AppColors.teal.withOpacity(0.06), borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Grand Total (${_list.length} item${_list.length == 1 ? '' : 's'})',
                  style: const TextStyle(fontSize: 13, color: AppColors.teal, fontWeight: FontWeight.w700)),
              Text(fmtCurrency(_grandTotal),
                  style: const TextStyle(fontSize: 16, color: AppColors.teal, fontWeight: FontWeight.w700)),
            ]),
          ),
        ],
      ]),
      footer: Row(children: [
        Expanded(child: OutlinedButton.icon(
          onPressed: _list.isEmpty ? null : _showReceipt,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: _list.isEmpty ? AppColors.border : AppColors.teal.withOpacity(0.6)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: const Icon(Icons.receipt_outlined, size: 16, color: AppColors.teal),
          label: const Text('Print Receipt',
              style: TextStyle(color: AppColors.teal, fontSize: 13, fontWeight: FontWeight.w600)),
        )),
        const SizedBox(width: 10),
        Expanded(child: ElevatedButton(
          onPressed: (_list.isEmpty || _saving) ? null : _submit,
          style: AppButtonStyle.primary(),
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 14),
            child: _saving
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('Confirm Sale (${_list.length})',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        )),
      ]),
    );
  }

  void _showReceipt() => showDialog(
    context: context,
    builder: (_) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(color: AppColors.statusGreenBg, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.receipt_outlined, size: 18, color: AppColors.teal)),
          const SizedBox(width: 10),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Sale Receipt', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
            Text('Review before confirming', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ])),
          GestureDetector(onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close, size: 18, color: AppColors.textMuted)),
        ]),
        const SizedBox(height: 16),
        const Divider(color: AppColors.divider),
        const SizedBox(height: 8),
        ..._list.map((s) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.medicine, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
              if (s.dosage.isNotEmpty) Text(s.dosage, style: AppTextStyles.bodySmall),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${s.qty.toStringAsFixed(s.qty.truncateToDouble() == s.qty ? 0 : 1)} × ${fmtCurrency(s.salePrice)}',
                  style: AppTextStyles.bodySmall),
              Text(fmtCurrency(s.total),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.teal)),
            ]),
          ]),
        )),
        const SizedBox(height: 8),
        const Divider(color: AppColors.divider),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Grand Total', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
          Text(fmtCurrency(_grandTotal),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.teal)),
        ]),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity,
          child: ElevatedButton(
            onPressed: () { Navigator.pop(context); _submit(); },
            style: AppButtonStyle.primary(),
            child: const Padding(padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Confirm & Record Sale',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
          )),
      ])),
    ),
  );
}

// ─── Inventory Form ───────────────────────────────────────────────────────────

class _InventoryForm extends StatefulWidget {
  final Map<String, dynamic>? item;
  final int clinicId;
  final List<Map<String, dynamic>> existing;
  final VoidCallback onSaved;
  const _InventoryForm({this.item, required this.clinicId, required this.existing, required this.onSaved});
  @override
  State<_InventoryForm> createState() => _InventoryFormState();
}

class _InventoryFormState extends State<_InventoryForm> {
  String _txType = 'IN';
  String? _cat;
  final _name     = TextEditingController();
  final _dosage   = TextEditingController();
  final _batch    = TextEditingController();
  final _qty      = TextEditingController();
  final _purchase = TextEditingController();
  final _sale     = TextEditingController();
  final _expiry   = TextEditingController();
  final _remarks  = TextEditingController();
  final _txDate   = TextEditingController();
  bool _saving = false;
  Map<String, String> _err = {};
  List<String> _warn = [];

  static const _maxQty = 100000, _maxRemarks = 500;
  bool get _editing => widget.item != null;

  @override
  void initState() {
    super.initState();
    _txDate.text = DateTime.now().toIso8601String().substring(0, 10);
    if (widget.item != null) {
      final it = widget.item!;
      _txType = it['transaction_type'] ?? 'IN';
      _cat        = it['category_name'];
      _name.text  = it['medicine_name'] ?? '';
      _dosage.text = it['dosage'] ?? '';
      _batch.text = it['batch_no'] ?? '';
      _qty.text   = it['quantity']?.toString() ?? '';
      _purchase.text = it['purchase_price']?.toString() ?? '';
      _sale.text  = it['sale_price']?.toString() ?? '';
      _expiry.text = it['expiry_date']?.toString().substring(0, 10) ?? '';
      _remarks.text = it['remarks'] ?? '';
      _txDate.text  = it['transaction_date']?.toString().substring(0, 10) ?? _txDate.text;
    }
    for (final c in [_purchase, _sale, _qty]) c.addListener(_recomputeWarnings);
  }

  @override
  void dispose() {
    for (final c in [_name, _dosage, _batch, _qty, _purchase, _sale, _expiry, _remarks, _txDate]) c.dispose();
    super.dispose();
  }

  void _recomputeWarnings() {
    final w = <String>[];
    final p = double.tryParse(_purchase.text) ?? 0;
    final s = double.tryParse(_sale.text) ?? 0;
    final q = int.tryParse(_qty.text) ?? 0;
    if (_sale.text.trim().isNotEmpty && s == 0) w.add('Sale price is ₹0 — confirm this is intentional.');
    if (p > 0 && s > 0 && s < p) w.add('Sale price (₹$s) is less than purchase price (₹$p).');
    if (q > 0 && q < 10) w.add('Quantity is very low ($q units).');
    setState(() => _warn = w);
  }

  bool _validate() {
    final e = <String, String>{};
    if (_cat == null) e['cat'] = 'Required';
    if (_name.text.trim().isEmpty) e['name'] = 'Required';
    if (_cat == 'Tablet' && _dosage.text.trim().isEmpty) e['dosage'] = 'Required for Tablets';

    final b = _batch.text.trim();
    if (b.isEmpty) {
      e['batch'] = 'Required';
    } else if (!_batchRx.hasMatch(b)) {
      e['batch'] = 'Use 3–20 alphanumeric chars (hyphens allowed)';
    } else {
      final dup = widget.existing.any((x) {
        if (_editing && x['id']?.toString() == widget.item!['id']?.toString()) return false;
        return (x['batch_no'] ?? '').toLowerCase() == b.toLowerCase()
            && (x['medicine_name'] ?? '').toLowerCase() == _name.text.trim().toLowerCase();
      });
      if (dup) e['batch'] = 'Batch no. already exists for this medicine';
    }

    final qText = _qty.text.trim();
    if (qText.isEmpty) {
      e['qty'] = 'Required';
    } else {
      final qd = double.tryParse(qText);
      if (qd == null || qd <= 0) {
        e['qty'] = 'Must be greater than 0';
      } else if (_cat != null && _wholeCats.contains(_cat) && qd != qd.floorToDouble()) {
        e['qty'] = '$_cat quantity must be a whole number';
      } else if (qd > _maxQty) {
        e['qty'] = 'Cannot exceed $_maxQty units';
      }
    }

    final p = double.tryParse(_purchase.text.trim()) ?? 0;
    if (_purchase.text.trim().isNotEmpty && p <= 0) e['purchase'] = 'Must be greater than 0';
    final s = double.tryParse(_sale.text.trim()) ?? 0;
    if (_sale.text.trim().isNotEmpty && s < 0) e['sale'] = 'Cannot be negative';

    if (_expiry.text.isEmpty) {
      e['expiry'] = 'Required';
    } else {
      try {
        final ed = DateTime.parse(_expiry.text.substring(0, 10));
        if (!_editing && ed.isBefore(DateTime.now())) e['expiry'] = 'Expiry date cannot be in the past for new entries';
      } catch (_) { e['expiry'] = 'Invalid date format'; }
    }

    if (_txDate.text.isEmpty) {
      e['txDate'] = 'Required';
    } else {
      try {
        if (DateTime.parse(_txDate.text.substring(0, 10)).isAfter(DateTime.now()))
          e['txDate'] = 'Transaction date cannot be in the future';
      } catch (_) { e['txDate'] = 'Invalid date format'; }
    }

    if (_remarks.text.length > _maxRemarks) e['remarks'] = 'Max $_maxRemarks characters allowed';
    setState(() => _err = e);
    return e.isEmpty;
  }

  Future<void> _save() async {
    if (!_validate()) return;
    setState(() => _saving = true);
    try {
      final res = await http.post(
        Uri.parse('${ApiClient.baseUrl}/inventory_create_update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': widget.item?['id'], 'clinic_id': widget.clinicId,
          'transaction_type': _txType, 'category_name': _cat,
          'medicine_name': _name.text.trim(), 'dosage': _dosage.text.trim(),
          'batch_no': _batch.text.trim(), 'quantity': double.tryParse(_qty.text) ?? 0,
          'purchase_price': double.tryParse(_purchase.text),
          'sale_price': double.tryParse(_sale.text),
          'expiry_date': _expiry.text.isEmpty ? null : _expiry.text,
          'transaction_date': _txDate.text,
          'remarks': _remarks.text.trim().isEmpty ? null : _remarks.text.trim(),
        }),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        Navigator.pop(context); widget.onSaved();
      }
    } catch (_) {}
    setState(() => _saving = false);
  }

  // ── Small builder helpers ──

  Widget _err2(String k) => _err[k] != null
      ? Padding(padding: const EdgeInsets.only(top: 4),
          child: Text(_err[k]!, style: const TextStyle(fontSize: 11, color: AppColors.statusRed)))
      : const SizedBox.shrink();

  /// Labelled field + optional inline error (replaces the 10× repeated Column pattern)
  Widget _f(String errKey, String label, TextEditingController c, {TextInputType? kb, String? hint}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AppFormField(label: label, controller: c, keyboardType: kb, hint: hint,
            onChanged: (_) => setState(() => _err.remove(errKey))),
        _err2(errKey),
      ]);

  Widget _datePicker(String errKey, String label, TextEditingController c,
      {DateTime? first, DateTime? last}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: AppTextStyles.label),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: c.text.isNotEmpty
                  ? DateTime.tryParse(c.text) ?? DateTime.now()
                  : DateTime.now(),
              firstDate: first ?? DateTime(2000),
              lastDate: last ?? DateTime(2040),
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.teal)),
                child: child!,
              ),
            );
            if (d != null) setState(() { c.text = d.toIso8601String().substring(0, 10); _err.remove(errKey); });
          },
          child: AbsorbPointer(child: TextField(controller: c, decoration: AppInput.deco('YYYY-MM-DD', icon: Icons.calendar_today_outlined))),
        ),
        _err2(errKey),
      ]);

  @override
  Widget build(BuildContext context) => _SheetScaffold(
    title: _editing ? 'Edit Medicine' : 'Add Medicine',
    body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Warnings
      if (_warn.isNotEmpty) Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.statusOrangeBg, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.statusOrange.withOpacity(0.4))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: _warn.map((w) =>
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.warning_amber_outlined, size: 14, color: AppColors.statusOrange),
              const SizedBox(width: 6),
              Expanded(child: Text(w, style: const TextStyle(fontSize: 11, color: AppColors.statusOrange))),
            ])).toList()),
      ),

      // TX type toggle
      Text('Transaction Type', style: AppTextStyles.label),
      const SizedBox(height: 6),
      Row(children: ['IN', 'OUT'].map((t) => GestureDetector(
        onTap: () => setState(() => _txType = t),
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: _txType == t ? (t == 'IN' ? AppColors.statusGreen : AppColors.statusRed) : AppColors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _txType == t ? Colors.transparent : AppColors.border),
          ),
          child: Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
              color: _txType == t ? Colors.white : AppColors.textSecondary)),
        ),
      )).toList()),
      const SizedBox(height: 14),

      // Category
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AppDropdownField<String>(
          label: 'Category *', value: _cat,
          items: _cats.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: (v) => setState(() { _cat = v; _err.remove('cat'); }),
        ),
        _err2('cat'),
      ]),
      const SizedBox(height: 14),

      Row(children: [
        Expanded(child: _f('name', 'Medicine Name *', _name, hint: 'e.g. Paracetamol')),
        const SizedBox(width: 12),
        Expanded(child: _f('dosage', _cat == 'Tablet' ? 'Dosage *' : 'Dosage', _dosage, hint: 'e.g. 500mg')),
      ]),
      const SizedBox(height: 14),

      Row(children: [
        Expanded(child: _f('batch', 'Batch No. *', _batch, hint: 'e.g. BATCH-001')),
        const SizedBox(width: 12),
        Expanded(child: _f('qty', 'Quantity *', _qty,
          kb: (_cat != null && _wholeCats.contains(_cat))
              ? TextInputType.number
              : const TextInputType.numberWithOptions(decimal: true),
          hint: (_cat != null && _wholeCats.contains(_cat)) ? 'Whole number' : '0',
        )),
      ]),
      const SizedBox(height: 14),

      Row(children: [
        Expanded(child: _f('purchase', 'Purchase Price (₹)', _purchase, kb: TextInputType.number, hint: '0.00')),
        const SizedBox(width: 12),
        Expanded(child: _f('sale', 'Sale Price (₹)', _sale, kb: TextInputType.number, hint: '0.00')),
      ]),
      const SizedBox(height: 14),

      _datePicker('expiry', 'Expiry Date *', _expiry,
          first: _editing ? DateTime(2000) : DateTime.now()),
      const SizedBox(height: 14),

      _datePicker('txDate', 'Transaction Date *', _txDate,
          first: DateTime(2000), last: DateTime.now()),
      const SizedBox(height: 14),

      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Remarks', style: AppTextStyles.label)),
          Text('${_remarks.text.length}/$_maxRemarks',
              style: TextStyle(fontSize: 10,
                  color: _remarks.text.length > _maxRemarks ? AppColors.statusRed : AppColors.textMuted)),
        ]),
        const SizedBox(height: 6),
        TextField(controller: _remarks, maxLines: 3, onChanged: (_) => setState(() {}),
            decoration: AppInput.deco('Optional notes…')),
        _err2('remarks'),
      ]),
    ]),
    footer: AppFormButtons(saving: _saving, onCancel: () => Navigator.pop(context), onSave: _save, saveLabel: 'Save'),
  );
}

// ─── Shared sheet scaffold (replaces Container+Column boilerplate in both sheets) ──

class _SheetScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget footer;
  final Widget? banner;

  const _SheetScaffold({required this.title, required this.body, required this.footer, this.banner});

  @override
  Widget build(BuildContext context) => Container(
    height: MediaQuery.of(context).size.height * 0.94,
    decoration: const BoxDecoration(color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    child: Column(children: [
      AppSheetHeader(title: title),
      if (banner != null) banner!,
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: body)),
      Container(
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 16),
        decoration: const BoxDecoration(color: AppColors.surfaceCard,
            border: Border(top: BorderSide(color: AppColors.divider, width: 1))),
        child: footer,
      ),
    ]),
  );
}

// ─── Read-only field wrapper ──────────────────────────────────────────────────

class _ReadonlyField extends StatelessWidget {
  final bool isError;
  final IconData icon;
  final Widget child;
  const _ReadonlyField({required this.isError, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: isError ? AppColors.statusRedBg : AppColors.surfaceLow,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border.withOpacity(0.4)),
    ),
    child: Row(children: [
      Icon(icon, size: 16, color: isError ? AppColors.statusRed : AppColors.textMuted),
      const SizedBox(width: 8),
      child,
    ]),
  );
}

// ─── Total badge ──────────────────────────────────────────────────────────────

class _TotalBadge extends StatelessWidget {
  final String label;
  final double amount;
  const _TotalBadge({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(color: AppColors.statusGreenBg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.statusGreen.withOpacity(0.4))),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontSize: 13, color: AppColors.teal, fontWeight: FontWeight.w600)),
      Text(fmtCurrency(amount), style: const TextStyle(fontSize: 16, color: AppColors.teal, fontWeight: FontWeight.w700)),
    ]),
  );
}

// ─── Medicine autocomplete field ──────────────────────────────────────────────

class _MedSearch extends StatefulWidget {
  final TextEditingController controller;
  final List<String> options;
  final ValueChanged<String> onSelected;
  const _MedSearch({required this.controller, required this.options, required this.onSelected});
  @override
  State<_MedSearch> createState() => _MedSearchState();
}

class _MedSearchState extends State<_MedSearch> {
  final _link = LayerLink();
  OverlayEntry? _ov;

  List<String> get _filtered {
    final q = widget.controller.text.trim().toLowerCase();
    return q.isEmpty ? widget.options : widget.options.where((n) => n.toLowerCase().contains(q)).toList();
  }

  void _show() {
    _hide();
    final opts = _filtered;
    if (opts.isEmpty) return;
    _ov = OverlayEntry(builder: (_) => Positioned(
      width: 300,
      child: CompositedTransformFollower(
        link: _link, showWhenUnlinked: false, offset: const Offset(0, 48),
        child: Material(
          elevation: 8, borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(color: AppColors.surfaceCard, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border.withOpacity(0.4))),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: ListView.builder(
                padding: EdgeInsets.zero, shrinkWrap: true, itemCount: opts.length,
                itemBuilder: (_, i) => InkWell(
                  onTap: () { widget.onSelected(opts[i]); _hide(); },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(opts[i], style: const TextStyle(fontSize: 13, color: AppColors.onSurface)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ));
    Overlay.of(context).insert(_ov!);
  }

  void _hide() { _ov?.remove(); _ov = null; }

  @override
  void dispose() { _hide(); super.dispose(); }

  @override
  Widget build(BuildContext context) => CompositedTransformTarget(
    link: _link,
    child: TextField(
      controller: widget.controller,
      onChanged: (_) { setState(() {}); _show(); },
      onTap: _show,
      decoration: AppInput.deco('Search medicine…', icon: Icons.medication_outlined),
    ),
  );
}