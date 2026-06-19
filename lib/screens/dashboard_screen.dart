import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'orders_screen.dart';
import 'compras_screen.dart';
import 'reports_screen.dart';
import '../widgets/custom_header.dart';
import '../widgets/order_form_modal.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final Color mainColor = const Color(0xFFD98A7A);
  final Color backgroundColor = const Color(0xFFFFF5F0);

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedMonth = DateTime.now();

  void _prevMonth() => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1));
  void _nextMonth() => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1));

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.month == now.month && _selectedMonth.year == now.year;
  }

  String _getMonthName(int month) {
    const months = ['', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    return months[month];
  }

  int get _currentMonthSales {
    int total = 0;
    for (var o in globalOrders) {
      try {
        final parts = o.date.split('/');
        if (int.parse(parts[1]) == _selectedMonth.month && int.parse(parts[2]) == _selectedMonth.year) {
          if (o.paymentStatus == "Pagado") total += o.price;
          else if (o.paymentStatus == "Monto abonado") total += o.amountPaid;
        }
      } catch (e) {}
    }
    return total;
  }

  int get _currentMonthExpenses {
    return globalExpenses
        .where((e) => e.date.month == _selectedMonth.month && e.date.year == _selectedMonth.year)
        .fold(0, (sum, item) => sum + item.amount);
  }

  int get _prevMonthBalance {
    final pMonth = _selectedMonth.month == 1 ? 12 : _selectedMonth.month - 1;
    final pYear = _selectedMonth.month == 1 ? _selectedMonth.year - 1 : _selectedMonth.year;

    int prevSales = 0;
    for (var o in globalOrders) {
      try {
        final parts = o.date.split('/');
        if (int.parse(parts[1]) == pMonth && int.parse(parts[2]) == pYear) {
          if (o.paymentStatus == "Pagado") prevSales += o.price;
          else if (o.paymentStatus == "Monto abonado") prevSales += o.amountPaid;
        }
      } catch (e) {}
    }
    final prevExpenses = globalExpenses
        .where((e) => e.date.month == pMonth && e.date.year == pYear)
        .fold(0, (sum, item) => sum + item.amount);
    return prevSales - prevExpenses;
  }

  List<OrderData> get _upcomingOrders {
    final pending = globalOrders.where((o) => o.productionStatus != 'Entregado').toList();
    pending.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return pending.take(5).toList();
  }

  // Pedidos con cobro incompleto (No pagado o Monto abonado)
  List<OrderData> get _pendingPaymentOrders {
    return globalOrders.where((o) =>
        o.productionStatus != 'Entregado' &&
        (o.paymentStatus == 'No pagado' || o.paymentStatus == 'Monto abonado')).toList();
  }

  int get _pendingPaymentTotal {
    return _pendingPaymentOrders.fold(0, (sum, o) {
      if (o.paymentStatus == 'No pagado') return sum + o.price;
      return sum + (o.price - o.amountPaid);
    });
  }

  // Pedidos para hoy o mañana (no entregados)
  List<OrderData> _getOrdersForDayOffset(int dayOffset) {
    final target = DateTime.now().add(Duration(days: dayOffset));
    return globalOrders.where((o) {
      final d = o.dateTime;
      return d.year == target.year && d.month == target.month && d.day == target.day &&
          o.productionStatus != 'Entregado';
    }).toList();
  }

  String _formatDateToDashboard(DateTime date) {
    const days = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
    const months = ['', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return "${days[date.weekday % 7]}\n${months[date.month]}\n${date.day}";
  }

  IconData _getStatusIcon(String status) {
    if (status == "Listo") return Icons.outdoor_grill;
    if (status == "Entregado") return Icons.local_shipping;
    return Icons.receipt_long;
  }

  Color _getPaymentColor(String status) {
    if (status.contains("Pagado")) return Colors.green.shade100;
    if (status.contains("Abonado") || status.contains("abonado")) return Colors.orange.shade100;
    return Colors.red.shade100;
  }

  String _formatCLP(int value) => value.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');

  List<OrderData> _getOrdersForDay(DateTime day) {
    return globalOrders.where((o) =>
        o.dateTime.year == day.year &&
        o.dateTime.month == day.month &&
        o.dateTime.day == day.day).toList();
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
                Text("Agenda de Pedidos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: mainColor)),
                const SizedBox(height: 10),
                TableCalendar(
                  firstDay: DateTime.utc(2024, 1, 1), lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay, eventLoader: _getOrdersForDay,
                  headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
                  onHeaderTapped: (focusedDay) async {
                    final picked = await showDatePicker(
                      context: context, initialDate: _focusedDay,
                      firstDate: DateTime(2024), lastDate: DateTime(2030),
                      initialDatePickerMode: DatePickerMode.year,
                      builder: (ctx, child) => Theme(
                        data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.light(primary: mainColor, onPrimary: Colors.white, onSurface: Colors.black)),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      setDialogState(() => _focusedDay = picked);
                      setState(() => _focusedDay = picked);
                    }
                  },
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(color: mainColor.withValues(alpha: 0.3), shape: BoxShape.circle),
                    selectedDecoration: BoxDecoration(color: mainColor, shape: BoxShape.circle),
                    markerDecoration: const BoxDecoration(color: Colors.transparent),
                  ),
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, day, events) {
                      if (events.isNotEmpty) {
                        return Positioned(
                          right: 1, bottom: 1,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Color(0xFF8D6E63), shape: BoxShape.circle),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            child: Center(child: Text('${events.length}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))),
                          ),
                        );
                      }
                      return null;
                    },
                  ),
                  onPageChanged: (d) { setDialogState(() => _focusedDay = d); setState(() => _focusedDay = d); },
                  onDaySelected: (selectedDay, focusedDay) {
                    setDialogState(() => _focusedDay = focusedDay);
                    setState(() => _focusedDay = focusedDay);
                    Navigator.pop(context);
                    final d = selectedDay.day.toString().padLeft(2, '0');
                    final m = selectedDay.month.toString().padLeft(2, '0');
                    globalSearchNotifier.value = "$d/$m/${selectedDay.year}";
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

  void _abrirFormularioGastoRapido() {
    final descCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    String selectedCat = "Insumos";
    DateTime tempDate = DateTime.now();
    bool isSaving = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Registrar Gasto Rápido", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
              isSaving
                  ? const CircularProgressIndicator(color: Color(0xFFD98A7A))
                  : ElevatedButton(
                      onPressed: () async {
                        if (descCtrl.text.isEmpty || amtCtrl.text.isEmpty) return;
                        setModalState(() => isSaving = true);
                        try {
                          await FirebaseFirestore.instance.collection('gastos').add({
                            'description': descCtrl.text,
                            'amount': int.parse(amtCtrl.text),
                            'date': Timestamp.fromDate(tempDate),
                            'category': selectedCat,
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gasto guardado"), backgroundColor: Colors.green));
                          }
                        } catch (e) {
                          setModalState(() => isSaving = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: mainColor, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                      child: const Text("Guardar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarDetalles(OrderData order) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [Icon(Icons.info_outline, color: mainColor), const SizedBox(width: 10), Text("Detalles", style: TextStyle(color: mainColor, fontWeight: FontWeight.bold))]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _itemDetalle("Producto", order.product, Icons.cake),
              _itemDetalle("Cliente", order.customer, Icons.person),
              _itemDetalle("Entrega", order.date, Icons.calendar_today),
              _itemDetalle("Total", "\$${_formatCLP(order.price)}", Icons.payments),
              _itemDetalle("Pago", order.paymentStatus, Icons.check_circle_outline),
              _itemDetalle("Producción", order.productionStatus, Icons.shutter_speed),
              const Divider(),
              const Text("Notas:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              Text(order.notas.isEmpty ? "Sin notas." : order.notas, style: const TextStyle(fontStyle: FontStyle.italic)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(dialogContext); showOrderForm(context, orderToEdit: order); },
            child: Text("Editar", style: TextStyle(color: mainColor, fontWeight: FontWeight.bold)),
          ),
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Cerrar", style: TextStyle(color: Colors.grey))),
        ],
      ),
    );
  }

  Widget _itemDetalle(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(children: [
        Icon(icon, size: 16, color: Colors.grey), const SizedBox(width: 8),
        Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: ValueListenableBuilder<int>(
        valueListenable: appDataNotifier,
        builder: (context, dataValue, child) {
          final upcoming = _upcomingOrders;
          final pendingCompras = globalChecklist.where((item) => !item.isDone).length;
          final currentSales = _currentMonthSales;
          final currentExpenses = _currentMonthExpenses;
          final currentBalance = currentSales - currentExpenses;
          final prevBalance = _prevMonthBalance;
          final pendingPayOrders = _pendingPaymentOrders;
          final pendingPayTotal = _pendingPaymentTotal;
          final todayOrders = _getOrdersForDayOffset(0);
          final tomorrowOrders = _getOrdersForDayOffset(1);

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 15, left: 15, right: 15, bottom: 20),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFE4E1),
                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
                ),
                child: CustomHeader(onCalendarTap: _showCalendarPopup),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // Alerta pedidos hoy/mañana
                        if (isDataLoaded && todayOrders.isNotEmpty)
                          _buildSingleAlertBanner(todayOrders, "HOY", Colors.red.shade50, Colors.red.shade700),
                        if (isDataLoaded && tomorrowOrders.isNotEmpty)
                          _buildSingleAlertBanner(tomorrowOrders, "MAÑANA", Colors.orange.shade50, Colors.orange.shade700),

                        // Próximos pedidos
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Próximos pedidos", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                            InkWell(
                              onTap: () => showOrderForm(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(color: mainColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                child: Row(children: [Icon(Icons.add, size: 14, color: mainColor), const SizedBox(width: 4), Text("Nuevo pedido", style: TextStyle(color: mainColor, fontSize: 11, fontWeight: FontWeight.bold))]),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        !isDataLoaded
                            ? _buildOrdersSkeleton()
                            : upcoming.isEmpty
                                ? const Padding(padding: EdgeInsets.all(20), child: Center(child: Text("No tienes pedidos pendientes 🍰")))
                                : Container(
                                    padding: const EdgeInsets.only(top: 12, left: 8, right: 8, bottom: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: mainColor.withValues(alpha: 0.4), width: 1.5),
                                    ),
                                    child: Column(children: upcoming.asMap().entries.map((e) => _buildOrderRow(e.value, e.key)).toList()),
                                  ),

                        const SizedBox(height: 25),

                        // Selector de mes
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: Icon(Icons.chevron_left, color: mainColor),
                              onPressed: _prevMonth,
                              splashRadius: 20,
                            ),
                            Text(
                              "${_getMonthName(_selectedMonth.month)} ${_selectedMonth.year}",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey.shade700),
                            ),
                            IconButton(
                              icon: Icon(Icons.chevron_right, color: _isCurrentMonth ? Colors.grey.shade300 : mainColor),
                              onPressed: _isCurrentMonth ? null : _nextMonth,
                              splashRadius: 20,
                            ),
                          ],
                        ),

                        // Balance card
                        !isDataLoaded
                            ? _buildBalanceSkeleton()
                            : _buildBalanceCard(currentBalance, currentSales, currentExpenses, prevBalance),

                        const SizedBox(height: 20),

                        // Cobros pendientes
                        !isDataLoaded
                            ? _buildGenericSkeleton(height: 90)
                            : _buildCobrosCard(pendingPayOrders.length, pendingPayTotal),

                        const SizedBox(height: 20),

                        // Compras pendientes
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Lista de compras", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                            GestureDetector(
                              onTap: () { appTabIndex.value = 2; appDataNotifier.value++; },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(color: mainColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: mainColor.withValues(alpha: 0.3))),
                                child: Row(children: [Icon(Icons.shopping_cart_outlined, size: 16, color: mainColor), const SizedBox(width: 4), Text(pendingCompras > 0 ? "$pendingCompras pendiente(s)" : "Ver lista", style: TextStyle(fontWeight: FontWeight.bold, color: mainColor, fontSize: 12))]),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- Widgets de alerta y tarjetas ---

  Widget _buildSingleAlertBanner(List<OrderData> orders, String label, Color bannerColor, Color textColor) {

    return GestureDetector(
      onTap: () => appTabIndex.value = 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bannerColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: textColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.notifications_active_rounded, color: textColor, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Pedido(s) para $label", style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 12)),
                  Text(orders.map((o) => o.product).join(", "), style: TextStyle(fontSize: 12, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: textColor, borderRadius: BorderRadius.circular(20)),
              child: Text("${orders.length}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCobrosCard(int count, int totalAmount) {
    final bool hayPendientes = count > 0;
    return GestureDetector(
      onTap: () => appTabIndex.value = 1,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: hayPendientes ? Colors.orange.withValues(alpha: 0.3) : Colors.green.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: hayPendientes ? Colors.orange.shade50 : Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(hayPendientes ? Icons.pending_actions_rounded : Icons.check_circle_rounded,
                  color: hayPendientes ? Colors.orange.shade700 : Colors.green.shade700, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Cobros pendientes", style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold)),
                  Text(
                    hayPendientes ? "\$${_formatCLP(totalAmount)}" : "Todo al día",
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: hayPendientes ? Colors.orange.shade800 : Colors.green.shade700),
                  ),
                  Text(
                    hayPendientes ? "$count pedido(s) sin cobro completo" : "Sin pedidos pendientes de pago",
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  // --- Skeleton loaders ---

  Widget _buildOrdersSkeleton() {
    return Container(
      padding: const EdgeInsets.only(top: 12, left: 8, right: 8, bottom: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: mainColor.withValues(alpha: 0.2), width: 1.5),
      ),
      child: Column(
        children: List.generate(3, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Shimmer.fromColors(
            baseColor: Colors.grey.shade200,
            highlightColor: Colors.grey.shade100,
            child: Row(
              children: [
                Container(width: 38, height: 44, color: Colors.white),
                const SizedBox(width: 6),
                Expanded(
                  child: Container(height: 44, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
                ),
              ],
            ),
          ),
        )),
      ),
    );
  }

  Widget _buildBalanceSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: 110,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildGenericSkeleton({double height = 80}) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: height,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  // --- Balance card ---

  Widget _buildBalanceCard(int balance, int sales, int expenses, int prevBalance) {
    final monthName = _getMonthName(_selectedMonth.month);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: mainColor.withValues(alpha: 0.2), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: mainColor.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(Icons.account_balance_wallet_rounded, color: mainColor, size: 28)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Balance de $monthName", style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                Text(balance < 0 ? "-\$${_formatCLP(balance.abs())}" : "\$${_formatCLP(balance)}",
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: balance < 0 ? Colors.red : Colors.black87)),
                const SizedBox(height: 6),
                Row(children: [
                  Icon(prevBalance >= 0 ? Icons.trending_up : Icons.trending_down, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text("Mes ant: ${prevBalance < 0 ? "-" : ""}\$${_formatCLP(prevBalance.abs())}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ]),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(children: [const Icon(Icons.arrow_upward_rounded, color: Colors.green, size: 14), const SizedBox(width: 4), Text("\$${_formatCLP(sales)}", style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold))]),
              const SizedBox(height: 4),
              Row(children: [const Icon(Icons.arrow_downward_rounded, color: Colors.redAccent, size: 14), const SizedBox(width: 4), Text("\$${_formatCLP(expenses)}", style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold))]),
              const SizedBox(height: 10),
              InkWell(
                onTap: _abrirFormularioGastoRapido,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: mainColor, borderRadius: BorderRadius.circular(8)),
                  child: const Row(children: [Icon(Icons.add, size: 14, color: Colors.white), SizedBox(width: 4), Text("Gasto", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Order row ---

  Widget _buildOrderRow(OrderData order, int index) {
    final List<Color> pastelColors = [
      const Color(0xFFCDE8E0), const Color(0xFFFFD8C7), const Color(0xFFFDF0D5),
      const Color(0xFFE2D4F0), const Color(0xFFD4E2F0), const Color(0xFFFFD1DC),
      const Color(0xFFE2F0CB), const Color(0xFFFFE4E1), const Color(0xFFE6E6FA), const Color(0xFFD0F0C0),
    ];
    final bgColor = pastelColors[(order.dateTime.day - 1) % pastelColors.length];
    final shortPaymentStatus = order.paymentStatus.contains("abonado") ? "Abonado" : order.paymentStatus;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: InkWell(
        onTap: () => _mostrarDetalles(order),
        borderRadius: BorderRadius.circular(15),
        child: Row(
          children: [
            SizedBox(
              width: 38,
              child: Text(_formatDateToDashboard(order.dateTime).toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: mainColor, height: 1.1)),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(15)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(order.product, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Row(children: [
                            Text(order.customer, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: _getPaymentColor(order.paymentStatus), borderRadius: BorderRadius.circular(4)),
                              child: Text(shortPaymentStatus, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                          ]),
                        ],
                      ),
                    ),
                    Icon(_getStatusIcon(order.productionStatus), color: Colors.black87, size: 18),
                    const SizedBox(width: 4),
                    SizedBox(
                      height: 24, width: 24,
                      child: PopupMenuButton<String>(
                        padding: EdgeInsets.zero, iconSize: 20,
                        onSelected: (val) {
                          if (val.startsWith('status_')) {
                            final nuevoEstado = val.split('_')[1];
                            if (nuevoEstado == "Entregado") {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                  title: Text("Confirmar Entrega", style: TextStyle(color: mainColor)),
                                  content: const Text("¿Marcar este pedido como entregado? Desaparecerá de esta vista."),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: mainColor),
                                      onPressed: () {
                                        FirebaseFirestore.instance.collection('pedidos').doc(order.id).update({'productionStatus': nuevoEstado});
                                        Navigator.pop(ctx);
                                      },
                                      child: const Text("Confirmar", style: TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              FirebaseFirestore.instance.collection('pedidos').doc(order.id).update({'productionStatus': nuevoEstado});
                            }
                          } else if (val == 'edit') {
                            showOrderForm(context, orderToEdit: order);
                          } else if (val == 'delete') {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 10), Text("Eliminar Pedido", style: TextStyle(color: Colors.red))]),
                                content: Text("¿Eliminar el pedido de '${order.product}'?"),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                    onPressed: () {
                                      FirebaseFirestore.instance.collection('pedidos').doc(order.id).delete();
                                      Navigator.pop(ctx);
                                    },
                                    child: const Text("Eliminar", style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            );
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(enabled: false, height: 30, child: Text('Cambiar estado', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold))),
                          PopupMenuItem(value: 'status_Tomado', height: 40, child: Row(children: [Icon(Icons.receipt_long, size: 18, color: order.productionStatus == 'Tomado' ? mainColor : Colors.grey), const SizedBox(width: 10), Text('Tomado', style: TextStyle(fontWeight: order.productionStatus == 'Tomado' ? FontWeight.bold : FontWeight.normal))])),
                          PopupMenuItem(value: 'status_Listo', height: 40, child: Row(children: [Icon(Icons.outdoor_grill, size: 18, color: order.productionStatus == 'Listo' ? mainColor : Colors.grey), const SizedBox(width: 10), Text('Pedido Listo', style: TextStyle(fontWeight: order.productionStatus == 'Listo' ? FontWeight.bold : FontWeight.normal))])),
                          PopupMenuItem(value: 'status_Entregado', height: 40, child: Row(children: [Icon(Icons.local_shipping, size: 18, color: order.productionStatus == 'Entregado' ? mainColor : Colors.grey), const SizedBox(width: 10), Text('Entregado', style: TextStyle(fontWeight: order.productionStatus == 'Entregado' ? FontWeight.bold : FontWeight.normal))])),
                          const PopupMenuDivider(),
                          const PopupMenuItem(value: 'edit', height: 40, child: Row(children: [Icon(Icons.edit, size: 16), SizedBox(width: 8), Text('Editar pedido')])),
                          const PopupMenuItem(value: 'delete', height: 40, child: Row(children: [Icon(Icons.delete, size: 16, color: Colors.red), SizedBox(width: 8), Text('Eliminar pedido', style: TextStyle(color: Colors.red))])),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
