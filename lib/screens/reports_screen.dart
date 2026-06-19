import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show Clipboard, ClipboardData, FilteringTextInputFormatter, TextInputFormatter, TextEditingValue, TextSelection;
import 'package:table_calendar/table_calendar.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import 'orders_screen.dart';
import 'dart:async';
import '../widgets/custom_header.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ==========================================
// MODELO DE DATOS PARA GASTOS
// ==========================================
class _ThousandSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final numbers = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (numbers.isEmpty) return newValue.copyWith(text: '');
    final formatted = numbers.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}

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
      globalExpenses = snapshot.docs.map((doc) => ExpenseData.fromFirestore(doc)).toList();
      if (mounted) appDataNotifier.value++;
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

  // --- DATOS ÚLTIMOS 6 MESES ---

  List<Map<String, dynamic>> _getLast6MonthsData() {
    final now = DateTime.now();
    return List.generate(6, (i) {
      int rawMonth = now.month - 5 + i;
      int year = now.year;
      if (rawMonth <= 0) { rawMonth += 12; year--; }
      final month = rawMonth;

      int income = 0;
      for (var o in globalOrders) {
        try {
          final parts = o.date.split('/');
          if (int.parse(parts[1]) == month && int.parse(parts[2]) == year) {
            if (o.paymentStatus == "Pagado") income += o.price;
            else if (o.paymentStatus == "Monto abonado") income += o.amountPaid;
          }
        } catch (_) {}
      }

      final expenses = globalExpenses
          .where((e) => e.date.month == month && e.date.year == year)
          .fold(0, (acc, e) => acc + e.amount);

      return {'month': month, 'year': year, 'income': income, 'expenses': expenses};
    });
  }

  String _formatCLPR(int v) => v.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');

  Widget _buildGastosExpandible() {
    final gastosMes = globalExpenses
        .where((e) => e.date.month == _selectedMonth && e.date.year == _selectedYear)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    if (gastosMes.isEmpty) return const SizedBox.shrink();

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Text(
            "Gastos del mes (${gastosMes.length})",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          trailing: Text(
            "-\$${_formatCLPR(gastosMes.fold(0, (s, e) => s + e.amount))}",
            style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          children: gastosMes.map((g) {
            final day = g.date.day.toString().padLeft(2, '0');
            final month = g.date.month.toString().padLeft(2, '0');
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                child: const Icon(Icons.receipt_long, size: 16, color: Colors.redAccent),
              ),
              title: Text(g.description, style: const TextStyle(fontSize: 13)),
              subtitle: Text("$day/$month  •  ${g.category}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
              trailing: Text("-\$${_formatCLPR(g.amount)}", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildChart() {
    final data = _getLast6MonthsData();
    const monthNames = ['', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    final maxVal = data.fold<double>(1, (mx, d) {
      final v = [d['income'] as int, d['expenses'] as int].reduce((a, b) => a > b ? a : b).toDouble();
      return v > mx ? v : mx;
    });

    final barGroups = List.generate(data.length, (i) {
      final d = data[i];
      return BarChartGroupData(
        x: i,
        barsSpace: 4,
        barRods: [
          BarChartRodData(toY: (d['income'] as int).toDouble(), color: Colors.green.shade400, width: 10, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
          BarChartRodData(toY: (d['expenses'] as int).toDouble(), color: Colors.redAccent.shade200, width: 10, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
        ],
      );
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Últimos 6 meses", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        Row(children: [
          _chartLegend(Colors.green.shade400, "Ingresos"),
          const SizedBox(width: 16),
          _chartLegend(Colors.redAccent.shade200, "Gastos"),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxVal * 1.3,
              barGroups: barGroups,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (val, _) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(monthNames[data[val.toInt()]['month'] as int], style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ),
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, _, rod, rodIndex) {
                    final label = rodIndex == 0 ? 'Ingresos' : 'Gastos';
                    final amount = rod.toY.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
                    return BarTooltipItem('$label\n\$$amount', const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold));
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _chartLegend(Color color, String label) {
    return Row(children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
    ]);
  }

  void _exportarReporte() {
    const monthNames = ['', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    final formatCLP = (int v) => v.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');

    final monthOrders = globalOrders.where((o) {
      try {
        final parts = o.date.split('/');
        return int.parse(parts[1]) == _selectedMonth && int.parse(parts[2]) == _selectedYear;
      } catch (_) { return false; }
    }).toList();

    final monthExpenses = globalExpenses.where((e) => e.date.month == _selectedMonth && e.date.year == _selectedYear).toList();

    final orderLines = monthOrders.map((o) {
      final estado = o.paymentStatus == "Monto abonado" ? "Abonado \$${formatCLP(o.amountPaid)}" : o.paymentStatus;
      return "• ${o.product} — \$${formatCLP(o.price)} ($estado)";
    }).join('\n');

    final expenseLines = monthExpenses.map((e) => "• ${e.description} — \$${formatCLP(e.amount)} (${e.category})").join('\n');

    final texto = '''📊 Reporte DolceCatapp
${monthNames[_selectedMonth]} $_selectedYear

💰 Ingresos:  \$${formatCLP(_totalSales)}
💸 Gastos:    \$${formatCLP(_totalExpenses)}
📈 Balance:   \$${formatCLP(_netProfit)}

🎂 Pedidos del mes (${monthOrders.length}):
${orderLines.isEmpty ? 'Sin pedidos' : orderLines}

🛒 Gastos del mes (${monthExpenses.length}):
${expenseLines.isEmpty ? 'Sin gastos' : expenseLines}

— Generado con DolceCatapp''';

    if (kIsWeb) {
      Clipboard.setData(ClipboardData(text: texto));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Reporte copiado al portapapeles"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } else {
      Share.share(texto, subject: 'Reporte ${monthNames[_selectedMonth]} $_selectedYear');
    }
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
          _reportCard("Total ingresos", _totalSales, Colors.green, Icons.account_balance_wallet_outlined, onTap: _mostrarHistorialIngresos),
          const SizedBox(height: 10),
          _reportCard("Total gastos", _totalExpenses, Colors.redAccent, Icons.shopping_bag_outlined, onTap: _mostrarHistorialGastos),
          const SizedBox(height: 10),
          _reportCard("Balance", _netProfit, mainColor, Icons.bar_chart_rounded),
          const SizedBox(height: 30),
          _buildChart(),

          const SizedBox(height: 20),
          _buildGastosExpandible(),
          const SizedBox(height: 25),
          ElevatedButton.icon(
            onPressed: _exportarReporte,
            icon: const Icon(Icons.share_rounded),
            label: const Text("Compartir reporte", style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: mainColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildExpenseListTab() {
    final filteredExpenses = globalExpenses
        .where((e) => e.date.month == _selectedMonth && e.date.year == _selectedYear)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

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

  Widget _reportCard(String title, int amount, Color color, IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                  Text(amount < 0 ? "-\$${_formatCLP(amount.abs())}" : "\$${_formatCLP(amount)}", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: title == "Balance" && amount < 0 ? Colors.red : Colors.black87)),
                ],
              ),
            ),
            if (onTap != null) Icon(Icons.chevron_right, color: Colors.grey.shade300, size: 20),
          ],
        ),
      ),
    );
  }

  void _mostrarHistorialIngresos() {
    final ordenesMes = globalOrders.where((o) {
      try {
        final parts = o.date.split('/');
        return int.parse(parts[1]) == _selectedMonth && int.parse(parts[2]) == _selectedYear &&
            (o.paymentStatus == "Pagado" || o.paymentStatus == "Monto abonado");
      } catch (_) { return false; }
    }).toList()..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (_, controller) => Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, color: Colors.green.shade600),
                    const SizedBox(width: 10),
                    Text("Ingresos — ${_getMonthName(_selectedMonth)} $_selectedYear",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Divider(),
              Expanded(
                child: ordenesMes.isEmpty
                    ? const Center(child: Text("Sin ingresos este mes", style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        controller: controller,
                        itemCount: ordenesMes.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (_, i) {
                          final o = ordenesMes[i];
                          final ingreso = o.paymentStatus == "Pagado" ? o.price : o.amountPaid;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 4),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                              child: Icon(Icons.cake_outlined, size: 18, color: Colors.green.shade600),
                            ),
                            title: Text(o.product, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text("${o.customer}  •  ${o.date}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("+\$${_formatCLP(ingreso)}", style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () {
                                    showDialog(
                                      context: ctx,
                                      builder: (dCtx) => AlertDialog(
                                        backgroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8), Text("Eliminar pedido", style: TextStyle(color: Colors.red))]),
                                        content: Text("¿Eliminar permanentemente el pedido '${o.product}'?"),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                            onPressed: () {
                                              FirebaseFirestore.instance.collection('pedidos').doc(o.id).delete();
                                              Navigator.pop(dCtx);
                                              Navigator.pop(ctx);
                                              setState(() {});
                                            },
                                            child: const Text("Eliminar", style: TextStyle(color: Colors.white)),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarHistorialGastos() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final gastosMes = globalExpenses
              .where((e) => e.date.month == _selectedMonth && e.date.year == _selectedYear)
              .toList()..sort((a, b) => b.date.compareTo(a.date));

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            builder: (_, controller) => Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Icon(Icons.shopping_bag_outlined, color: Colors.redAccent),
                      const SizedBox(width: 10),
                      Text("Gastos — ${_getMonthName(_selectedMonth)} $_selectedYear",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(),
                Expanded(
                  child: gastosMes.isEmpty
                      ? const Center(child: Text("Sin gastos este mes", style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          controller: controller,
                          itemCount: gastosMes.length,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemBuilder: (_, i) {
                            final g = gastosMes[i];
                            final day = g.date.day.toString().padLeft(2, '0');
                            final month = g.date.month.toString().padLeft(2, '0');
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 4),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                                child: const Icon(Icons.receipt_long, size: 18, color: Colors.redAccent),
                              ),
                              title: Text(g.description, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text("$day/$month  •  ${g.category}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text("-\$${_formatCLP(g.amount)}", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () {
                                      showDialog(
                                        context: ctx,
                                        builder: (dCtx) => AlertDialog(
                                          backgroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                          title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8), Text("Eliminar gasto", style: TextStyle(color: Colors.red))]),
                                          content: Text("¿Eliminar el gasto '${g.description}'?"),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                              onPressed: () async {
                                                await FirebaseFirestore.instance.collection('gastos').doc(g.id).delete();
                                                if (!dCtx.mounted) return;
                                                Navigator.pop(dCtx);
                                                if (!ctx.mounted) return;
                                                Navigator.pop(ctx);
                                                setState(() {});
                                              },
                                              child: const Text("Eliminar", style: TextStyle(color: Colors.white)),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _abrirFormularioGasto({ExpenseData? expenseToEdit}) {
    final descCtrl = TextEditingController(text: expenseToEdit?.description ?? "");
    final amtCtrl = TextEditingController(
      text: expenseToEdit != null ? _formatCLP(expenseToEdit.amount) : "",
    );
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
              TextField(
                controller: amtCtrl,
                decoration: const InputDecoration(labelText: "Monto", prefixText: "\$ "),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _ThousandSeparatorFormatter(),
                ],
              ),
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
                      'amount': int.parse(amtCtrl.text.replaceAll('.', '')),
                      'date': Timestamp.fromDate(tempDate),
                      'category': selectedCat,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                  } else {
                    // ACTUALIZAR EXISTENTE
                    await expenseRef.doc(expenseToEdit.id).update({
                      'description': descCtrl.text,
                      'amount': int.parse(amtCtrl.text.replaceAll('.', '')),
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