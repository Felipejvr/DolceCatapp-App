import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:table_calendar/table_calendar.dart';
import 'orders_screen.dart'; 
import 'dart:async';
import '../widgets/custom_header.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // NUEVO

// ==========================================
// MODELO DE DATOS PARA GASTOS
// ==========================================
class ExpenseData {
  String id;
  String description;
  int amount;
  DateTime date;
  String category;
  DateTime? createdAt;

  ExpenseData({
    required this.id,
    required this.description,
    required this.amount,
    required this.date,
    this.category = "Otros",
    this.createdAt,
  });

  // Convertir de Firestore a Objeto
  factory ExpenseData.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return ExpenseData(
      id: doc.id,
      description: data['description'] ?? '',
      amount: data['amount'] ?? 0,
      date: (data['date'] as Timestamp).toDate(),
      category: data['category'] ?? 'Otros',
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : null, 
    );
  }

  // Convertir de Objeto a Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'description': description,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'category': category,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
    };
  }
}

List<ExpenseData> globalExpenses = [
  ExpenseData(id: '1', description: 'Saco de Harina 25kg', amount: 18000, date: DateTime(2026, 5, 10), category: 'Insumos'),
  ExpenseData(id: '2', description: 'Pack 50 Cajas Torta', amount: 25000, date: DateTime(2026, 5, 12), category: 'Empaque'),
  ExpenseData(id: '3', description: 'Cilindro de Gas', amount: 22000, date: DateTime(2026, 5, 15), category: 'Gastos Fijos'),
];

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  final Color mainColor = const Color(0xFFD98A7A);
  final Color pastelPink = const Color(0xFFFDE9E0);
  
  late int _selectedMonth;
  late int _selectedYear;
  
  DateTime _focusedDay = DateTime.now();
  late TabController _tabController;

  StreamSubscription? _expensesSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _escucharGastos();
    _selectedMonth = DateTime.now().month;
    _selectedYear = DateTime.now().year;
  }

  void _escucharGastos() {
    _expensesSub = FirebaseFirestore.instance.collection('gastos').snapshots().listen((snapshot) {
      // Reemplazamos la lista global con los datos de Firebase
      globalExpenses = snapshot.docs.map((doc) => ExpenseData.fromFirestore(doc)).toList();
      if (mounted) appDataNotifier.value++; // Esto actualiza el resumen automáticamente
    });
  }

  @override
  void dispose() {
    _expensesSub?.cancel();
    super.dispose();
  }

  // --- LÓGICA DE FILTRADO Y CÁLCULO ---

  bool _isSameMonthYear(String dateStr) {
    try {
      List<String> parts = dateStr.split('/');
      int m = int.parse(parts[1]);
      int y = int.parse(parts[2]);
      return m == _selectedMonth && y == _selectedYear;
    } catch (e) { return false; }
  }

  int get _totalSales {
    int total = 0;
    for (var o in globalOrders) {
      if (_isSameMonthYear(o.date)) {
        if (o.paymentStatus == "Pagado") {
          total += o.price;
        } else if (o.paymentStatus == "Monto abonado") {
          total += o.amountPaid;
        }
      }
    }
    return total;
  }

  int get _totalExpenses {
    return globalExpenses
        .where((e) => e.date.month == _selectedMonth && e.date.year == _selectedYear)
        .fold(0, (sum, item) => sum + item.amount);
  }

  int get _netProfit => _totalSales - _totalExpenses;

  String _formatCLP(int value) => value.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');

  String _getMonthName(int month) {
    const months = ['', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    return months[month];
  }

  // --- ELIMINAR GASTO ---
  void _confirmarEliminacionGasto(ExpenseData expense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8), Text("Eliminar gasto")]),
        content: Text("¿Estás seguro de eliminar '${expense.description}'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              FirebaseFirestore.instance.collection('gastos').doc(expense.id).delete();
              Navigator.pop(context);
            },
            child: const Text("Eliminar", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  void _showCalendarPopup() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TableCalendar(
                  firstDay: DateTime.utc(2024, 1, 1), lastDay: DateTime.utc(2030, 12, 31), focusedDay: _focusedDay,
                  headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
                  calendarStyle: CalendarStyle(todayDecoration: BoxDecoration(color: mainColor.withOpacity(0.3), shape: BoxShape.circle), selectedDecoration: BoxDecoration(color: mainColor, shape: BoxShape.circle)),
                  onDaySelected: (selectedDay, focusedDay) {
                    Navigator.pop(context);
                    globalSearchNotifier.value = "${selectedDay.day.toString().padLeft(2, '0')}/${selectedDay.month.toString().padLeft(2, '0')}/${selectedDay.year}"; 
                    appTabIndex.value = 1; 
                  },
                ),
                TextButton(onPressed: () => Navigator.pop(context), child: Text("Cerrar", style: TextStyle(color: mainColor))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ValueListenableBuilder<int>(
        valueListenable: appDataNotifier,
        builder: (context, value, child) {
          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 15, left: 15, right: 15, bottom: 20),
                decoration: const BoxDecoration(color: Color(0xFFFFE4E1), borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30))),
                child: CustomHeader(title: "DolceCatapp", onCalendarTap: _showCalendarPopup),
              ),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: TabBar(
                  controller: _tabController,
                  labelColor: mainColor,
                  unselectedLabelColor: Colors.grey,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(color: pastelPink, borderRadius: const BorderRadius.vertical(top: Radius.circular(15))),
                  tabs: const [Tab(text: "Resumen"), Tab(text: "Gastos")],
                ),
              ),
              Expanded(
                child: Container(
                  color: pastelPink,
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildSummaryTab(), _buildExpenseListTab()],
                  ),
                ),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildSummaryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedMonth,
                      icon: Icon(Icons.keyboard_arrow_down, color: mainColor),
                      onChanged: (int? newValue) { setState(() { _selectedMonth = newValue!; }); },
                      items: List.generate(12, (index) => index + 1).map((int value) {
                        return DropdownMenuItem<int>(value: value, child: Text(_getMonthName(value), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)));
                      }).toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedYear,
                      icon: Icon(Icons.date_range, color: mainColor, size: 18),
                      onChanged: (int? newValue) { setState(() { _selectedYear = newValue!; }); },
                      items: List.generate(7, (index) => 2024 + index).map((int value) {
                        return DropdownMenuItem<int>(value: value, child: Text(value.toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)));
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          _reportCard("Total ingresos", _totalSales, Colors.green, Icons.account_balance_wallet_outlined),
          const SizedBox(height: 10),
          _reportCard("Total gastos", _totalExpenses, Colors.redAccent, Icons.shopping_bag_outlined),
          const SizedBox(height: 10),
          _reportCard("Balance", _netProfit, mainColor, Icons.bar_chart_rounded),
          const SizedBox(height: 35),
          const Text("Distribución de Dinero", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 15),
          Container(
            height: 45, width: double.infinity,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.white, border: Border.all(color: Colors.white, width: 2)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _totalSales == 0 
                ? const Center(child: Text("Sin ingresos este mes", style: TextStyle(fontSize: 10, color: Colors.grey)))
                : Row(
                    children: [
                      if (_totalExpenses > 0) Expanded(flex: _totalExpenses, child: Container(color: Colors.redAccent.withOpacity(0.4))),
                      if (_netProfit > 0) Expanded(flex: _netProfit, child: Container(color: mainColor.withOpacity(0.4))),
                    ],
                  ),
            ),
          ),
          const SizedBox(height: 10),
          if (_totalSales > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Gastos: ${((_totalExpenses / _totalSales) * 100).toStringAsFixed(1)}%", style: const TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                Text("Utilidad: ${((_netProfit / _totalSales) * 100).toStringAsFixed(1)}%", style: const TextStyle(fontSize: 11, color: Color(0xFFD98A7A), fontWeight: FontWeight.bold)),
              ],
            )
        ],
      ),
    );
  }

  Widget _buildExpenseListTab() {
    final filteredExpenses = globalExpenses
        .where((e) => e.date.month == _selectedMonth && e.date.year == _selectedYear)
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(15.0),
          child: ElevatedButton.icon(
            onPressed: () => _abrirFormularioGasto(),
            icon: const Icon(Icons.add),
            label: const Text("Registrar Gasto de Insumo", style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: mainColor, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 45), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
          ),
        ),
        Expanded(
          child: filteredExpenses.isEmpty
            ? const Center(child: Text("No hay gastos registrados.", style: TextStyle(color: Colors.grey, fontSize: 13)))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                itemCount: filteredExpenses.length,
                itemBuilder: (context, index) {
                  final exp = filteredExpenses[index];
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: const CircleAvatar(backgroundColor: Color(0xFFFDE9E0), child: Icon(Icons.receipt_long, color: Color(0xFFD98A7A), size: 18)),
                      title: Text(exp.description, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text("${exp.date.day} ${_getMonthName(exp.date.month)} · ${exp.category}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("-\$${_formatCLP(exp.amount)}", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                          PopupMenuButton<String>(
                            onSelected: (val) => val == 'edit' ? _abrirFormularioGasto(expenseToEdit: exp) : _confirmarEliminacionGasto(exp),
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text("Editar")])),
                              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 18), SizedBox(width: 8), Text("Eliminar", style: TextStyle(color: Colors.red))])),
                            ],
                          )
                        ],
                      ),
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }

  Widget _reportCard(String title, int amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
              Text(amount < 0 ? "-\$${_formatCLP(amount.abs())}" : "\$${_formatCLP(amount)}", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: title == "Balance" && amount < 0 ? Colors.red : Colors.black87)),
            ],
          )
        ],
      ),
    );
  }

  void _abrirFormularioGasto({ExpenseData? expenseToEdit}) {
    final descCtrl = TextEditingController(text: expenseToEdit?.description ?? "");
    final amtCtrl = TextEditingController(text: expenseToEdit?.amount.toString() ?? "");
    String selectedCat = expenseToEdit?.category ?? "Insumos";
    DateTime tempDate = expenseToEdit?.date ?? DateTime.now();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(expenseToEdit == null ? "Registrar Compra" : "Editar Gasto", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: "Descripción")),
              TextField(controller: amtCtrl, decoration: const InputDecoration(labelText: "Monto", prefixText: "\$"), keyboardType: TextInputType.number),
              DropdownButtonFormField<String>(
                value: selectedCat,
                items: ["Insumos", "Empaque", "Gastos Fijos", "Otros"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (val) => setModalState(() => selectedCat = val!),
                decoration: const InputDecoration(labelText: "Categoría"),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today, size: 18),
                title: Text("Fecha: ${tempDate.day}/${tempDate.month}/${tempDate.year}"),
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: tempDate, firstDate: DateTime(2024), lastDate: DateTime(2030));
                  if (picked != null) setModalState(() => tempDate = picked);
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async { // Hazlo async
                  if(descCtrl.text.isEmpty || amtCtrl.text.isEmpty) return;
                  
                  final expenseRef = FirebaseFirestore.instance.collection('gastos');
                  
                  if (expenseToEdit == null) {
                    // GUARDAR NUEVO
                    await expenseRef.add({
                      'description': descCtrl.text,
                      'amount': int.parse(amtCtrl.text),
                      'date': Timestamp.fromDate(tempDate),
                      'category': selectedCat,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                  } else {
                    // ACTUALIZAR EXISTENTE
                    await expenseRef.doc(expenseToEdit.id).update({
                      'description': descCtrl.text,
                      'amount': int.parse(amtCtrl.text),
                      'date': Timestamp.fromDate(tempDate),
                      'category': selectedCat,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                  }
                  
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: mainColor, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                child: Text(expenseToEdit == null ? "Guardar Gasto" : "Actualizar Gasto", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}