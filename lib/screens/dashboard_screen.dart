import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:table_calendar/table_calendar.dart'; 
import 'orders_screen.dart'; 
import 'inventory_screen.dart'; 
import 'reports_screen.dart'; 
import '../widgets/custom_header.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final Color mainColor = const Color(0xFFD98A7A);
  final Color backgroundColor = const Color(0xFFFFF5F0);
  
  final _productCtrl = TextEditingController();
  final _customerCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _abonoCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();

  DateTime _focusedDay = DateTime.now();

  // --- HELPER DE MES ---
  String _getMonthName(int month) {
    const months = ['', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    return months[month];
  }

  // --- LÓGICA DE CONTEO DE INSUMOS ---
  Map<String, int> _getInventorySummary() {
    int red = 0;    
    int yellow = 0; 
    int green = 0;  

    for (var item in globalInventory) {
      if (item.quantity == 0) {
        red++;
      } else if (item.quantity <= item.minThreshold) {
        yellow++;
      } else {
        green++;
      }
    }
    return {'red': red, 'yellow': yellow, 'green': green};
  }

  // --- FINANZAS: MES ACTUAL ---
  int get _currentMonthSales {
    int total = 0;
    DateTime now = DateTime.now();
    for (var o in globalOrders) {
      try {
        List<String> parts = o.date.split('/');
        int m = int.parse(parts[1]);
        int y = int.parse(parts[2]);
        if (m == now.month && y == now.year) {
          if (o.paymentStatus == "Pagado") {
            total += o.price;
          } else if (o.paymentStatus == "Monto abonado") {
            total += o.amountPaid;
          }
        }
      } catch (e) {}
    }
    return total;
  }

  int get _currentMonthExpenses {
    DateTime now = DateTime.now();
    return globalExpenses
        .where((e) => e.date.month == now.month && e.date.year == now.year)
        .fold(0, (sum, item) => sum + item.amount);
  }

  // --- FINANZAS: MES ANTERIOR ---
  int get _prevMonthBalance {
    DateTime now = DateTime.now();
    int pMonth = now.month == 1 ? 12 : now.month - 1;
    int pYear = now.month == 1 ? now.year - 1 : now.year;
    
    int prevSales = 0;
    for (var o in globalOrders) {
      try {
        List<String> parts = o.date.split('/');
        int m = int.parse(parts[1]);
        int y = int.parse(parts[2]);
        if (m == pMonth && y == pYear) {
          if (o.paymentStatus == "Pagado") prevSales += o.price;
          else if (o.paymentStatus == "Monto abonado") prevSales += o.amountPaid;
        }
      } catch (e) {}
    }
    
    int prevExpenses = globalExpenses
        .where((e) => e.date.month == pMonth && e.date.year == pYear)
        .fold(0, (sum, item) => sum + item.amount);
        
    return prevSales - prevExpenses;
  }

  List<OrderData> get _upcomingOrders {
    var pending = globalOrders.where((order) => order.productionStatus != 'Entregado').toList();
    pending.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return pending.take(3).toList();
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
    if (status.contains("Abonado")) return Colors.orange.shade100;
    return Colors.red.shade100;
  }

  String _formatCLP(int value) => value.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');

  // --- LÓGICA DEL CALENDARIO ---
  List<OrderData> _getOrdersForDay(DateTime day) {
    return globalOrders.where((order) {
      return order.dateTime.year == day.year &&
             order.dateTime.month == day.month &&
             order.dateTime.day == day.day;
    }).toList();
  }

  void _showCalendarPopup() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder( 
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Agenda de Pedidos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: mainColor)),
                    const SizedBox(height: 10),
                    TableCalendar(
                      firstDay: DateTime.utc(2024, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      eventLoader: _getOrdersForDay, 
                      
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                      ),

                      onHeaderTapped: (focusedDay) async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _focusedDay,
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2030),
                          initialDatePickerMode: DatePickerMode.year, 
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(primary: mainColor, onPrimary: Colors.white, onSurface: Colors.black),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setDialogState(() => _focusedDay = picked);
                          setState(() => _focusedDay = picked);
                        }
                      },

                      calendarStyle: CalendarStyle(
                        todayDecoration: BoxDecoration(color: mainColor.withOpacity(0.3), shape: BoxShape.circle),
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
                                child: Center(
                                  child: Text('${events.length}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            );
                          }
                          return null;
                        },
                      ),
                      
                      onPageChanged: (focusedDay) {
                        setDialogState(() => _focusedDay = focusedDay);
                        setState(() => _focusedDay = focusedDay);
                      },
                      
                      onDaySelected: (selectedDay, focusedDay) {
                        setDialogState(() => _focusedDay = focusedDay);
                        setState(() => _focusedDay = focusedDay);
                        
                        Navigator.pop(context); 
                        String d = selectedDay.day.toString().padLeft(2, '0');
                        String m = selectedDay.month.toString().padLeft(2, '0');
                        String y = selectedDay.year.toString();
                        
                        globalSearchNotifier.value = "$d/$m/$y"; 
                        appTabIndex.value = 1;                   
                      },
                    ),
                    TextButton(onPressed: () => Navigator.pop(context), child: Text("Cerrar", style: TextStyle(color: mainColor)))
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  // --- FORMULARIO RÁPIDO DE GASTOS CON SELECTOR DE FECHA ---
  void _abrirFormularioGastoRapido() {
    final descCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    String selectedCat = "Insumos";
    DateTime tempDate = DateTime.now(); // Fecha actual por defecto
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
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
              // NUEVO: Selector de fecha en el dashboard
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today, size: 18),
                title: Text("Fecha: ${tempDate.day}/${tempDate.month}/${tempDate.year}"),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context, 
                    initialDate: tempDate, 
                    firstDate: DateTime(2024), 
                    lastDate: DateTime(2030)
                  );
                  if (picked != null) setModalState(() => tempDate = picked);
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if(descCtrl.text.isEmpty || amtCtrl.text.isEmpty) return;
                  setState(() {
                    globalExpenses.add(ExpenseData(
                      id: DateTime.now().toString(),
                      description: descCtrl.text,
                      amount: int.parse(amtCtrl.text),
                      date: tempDate, // Guarda con la fecha seleccionada
                      category: selectedCat,
                    ));
                  });
                  appDataNotifier.value++; 
                  Navigator.pop(context);
                  ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text("Gasto guardado"), backgroundColor: Colors.green));
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

  // --- FORMULARIO DE EDICIÓN (PEDIDOS) ---
  void _abrirFormularioEdicion(OrderData orderToEdit) {
    String tempDate = orderToEdit.date;
    String tempPaymentStatus = orderToEdit.paymentStatus;

    _productCtrl.text = orderToEdit.product;
    _customerCtrl.text = orderToEdit.customer;
    _priceCtrl.text = _formatCLP(orderToEdit.price);
    _abonoCtrl.text = _formatCLP(orderToEdit.amountPaid);
    _notasCtrl.text = orderToEdit.notas;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: Text("Editar Pedido", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                TextField(controller: _productCtrl, decoration: const InputDecoration(labelText: "Producto")),
                TextField(controller: _customerCtrl, decoration: const InputDecoration(labelText: "Cliente")),
                TextField(controller: _priceCtrl, decoration: const InputDecoration(labelText: "Total", prefixText: "\$ "), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, CLPInputFormatter()]),
                DropdownButtonFormField<String>(
                  value: tempPaymentStatus, 
                  items: ["No pagado", "Monto abonado", "Pagado"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), 
                  onChanged: (val) => setModalState(() => tempPaymentStatus = val!)
                ),
                if (tempPaymentStatus == "Monto abonado") TextField(controller: _abonoCtrl, decoration: const InputDecoration(labelText: "Abono", prefixText: "\$ "), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, CLPInputFormatter()]),
                TextField(controller: _notasCtrl, decoration: const InputDecoration(labelText: "Notas"), maxLines: 2),
                
                const SizedBox(height: 15),
                ListTile(
                  leading: const Icon(Icons.calendar_month), 
                  title: Text("Fecha: $tempDate"), 
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2024), lastDate: DateTime(2030));
                    if (picked != null) setModalState(() => tempDate = "${picked.day.toString().padLeft(2,'0')}/${picked.month.toString().padLeft(2,'0')}/${picked.year}");
                  }
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: mainColor, minimumSize: const Size(double.maxFinite, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("Confirmar Cambios"),
                        content: const Text("¿Estás seguro de que deseas guardar los cambios?"),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: mainColor),
                            onPressed: () {
                              orderToEdit.product = _productCtrl.text;
                              orderToEdit.customer = _customerCtrl.text;
                              orderToEdit.price = int.tryParse(_priceCtrl.text.replaceAll('.', '')) ?? 0;
                              orderToEdit.amountPaid = int.tryParse(_abonoCtrl.text.replaceAll('.', '')) ?? 0;
                              orderToEdit.date = tempDate;
                              orderToEdit.paymentStatus = tempPaymentStatus;
                              orderToEdit.notas = _notasCtrl.text;
                              appDataNotifier.value++; 
                              Navigator.pop(ctx); 
                              Navigator.pop(context); 
                              ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text("Pedido actualizado"), backgroundColor: Colors.green));
                            }, 
                            child: const Text("Confirmar", style: TextStyle(color: Colors.white))
                          ),
                        ],
                      ),
                    );
                  }, 
                  child: const Text("Guardar Cambios", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- VENTANA DE DETALLES ---
  void _mostrarDetalles(OrderData order) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog( 
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: mainColor),
            const SizedBox(width: 10),
            Text("Detalles", style: TextStyle(color: mainColor, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
            onPressed: () {
              Navigator.pop(dialogContext); 
              _abrirFormularioEdicion(order); 
            }, 
            child: Text("Editar", style: TextStyle(color: mainColor, fontWeight: FontWeight.bold))
          ),
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Cerrar", style: TextStyle(color: Colors.grey))),
        ],
      ),
    );
  }

  Widget _itemDetalle(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
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
          final invSummary = _getInventorySummary(); 
          final pendingCompras = globalChecklist.where((item) => !item.isDone).length;
          
          // Cálculos financieros
          final currentSales = _currentMonthSales;
          final currentExpenses = _currentMonthExpenses;
          final currentBalance = currentSales - currentExpenses;
          final prevBalance = _prevMonthBalance;
          
          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 15, left: 15, right: 15, bottom: 20),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFE4E1),
                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
                ),
                child: CustomHeader(
                  onCalendarTap: _showCalendarPopup,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Próximos pedidos", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                        const SizedBox(height: 10), 
                        upcoming.isEmpty
                            ? const Padding(padding: EdgeInsets.all(20), child: Center(child: Text("No tienes pedidos pendientes 🍰")))
                            : Container(
                                padding: const EdgeInsets.only(top: 12, left: 8, right: 8, bottom: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: mainColor.withOpacity(0.4), width: 1.5),
                                ),
                                child: Column(
                                  children: upcoming.asMap().entries.map((entry) => _buildOrderRow(entry.value, entry.key)).toList(),
                                ),
                              ),
                        
                        const SizedBox(height: 25),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text("Insumos", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: () {
                                    inventoryTabNotifier.value = 1; 
                                    appTabIndex.value = 2; 
                                    appDataNotifier.value++; 
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: mainColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: mainColor.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.shopping_cart_outlined, size: 16, color: mainColor),
                                        const SizedBox(width: 4),
                                        Text(
                                          pendingCompras.toString(),
                                          style: TextStyle(fontWeight: FontWeight.bold, color: mainColor, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            
                            Row(
                              children: [
                                _circleStatus(invSummary['red']!, const Color(0xFFFFD1D1), Colors.red.shade900, "Crítico"),
                                const SizedBox(width: 8),
                                _circleStatus(invSummary['yellow']!, const Color(0xFFFFF4D1), Colors.orange.shade900, "Alerta"),
                                const SizedBox(width: 8),
                                _circleStatus(invSummary['green']!, const Color(0xFFD1FFD1), Colors.green.shade900, "Hay stock"),
                              ],
                            )
                          ],
                        ),
                        const SizedBox(height: 20),

                        // TARJETA DE BALANCE
                        _buildBalanceCard(currentBalance, currentSales, currentExpenses, prevBalance),
                        
                        // ELIMINADO EL CUADRO DE ESTADO DE INVENTARIO CRÍTICO AQUÍ
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }
      ),
    );
  }

  // WIDGET: TARJETA DE BILLETERA COMPACTA
  Widget _buildBalanceCard(int balance, int sales, int expenses, int prevBalance) {
    String monthName = _getMonthName(DateTime.now().month);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: mainColor.withOpacity(0.2), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icono a la izquierda
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: mainColor.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.account_balance_wallet_rounded, color: mainColor, size: 28),
          ),
          const SizedBox(width: 15),
          
          // Centro: Balance principal
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Balance de $monthName", style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                Text(
                  balance < 0 ? "-\$${_formatCLP(balance.abs())}" : "\$${_formatCLP(balance)}",
                  style: TextStyle(
                    fontWeight: FontWeight.w900, 
                    fontSize: 22, 
                    color: balance < 0 ? Colors.red : Colors.black87
                  ),
                ),
                const SizedBox(height: 6),
                // Información del mes anterior
                Row(
                  children: [
                    Icon(prevBalance >= 0 ? Icons.trending_up : Icons.trending_down, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      "Mes ant: ${prevBalance < 0 ? "-" : ""}\$${_formatCLP(prevBalance.abs())}", 
                      style: const TextStyle(fontSize: 10, color: Colors.grey)
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Derecha: Ingresos, Gastos y Botón "+"
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  const Icon(Icons.arrow_upward_rounded, color: Colors.green, size: 14),
                  const SizedBox(width: 4),
                  Text("\$${_formatCLP(sales)}", style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.arrow_downward_rounded, color: Colors.redAccent, size: 14),
                  const SizedBox(width: 4),
                  Text("\$${_formatCLP(expenses)}", style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 10),
              // Botón rápido para agregar gasto
              InkWell(
                onTap: _abrirFormularioGastoRapido,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: mainColor, borderRadius: BorderRadius.circular(8)),
                  child: const Row(
                    children: [
                      Icon(Icons.add, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text("Gasto", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  // WIDGET PARA LOS CÍRCULOS DEL INVENTARIO
  Widget _circleStatus(int count, Color bgColor, Color textColor, String statusName) {
    return GestureDetector(
      onTap: () {
        globalSelectedStatuses.clear();
        globalSelectedStatuses.add(statusName);
        inventoryTabNotifier.value = 0;
        appTabIndex.value = 2; 
        appDataNotifier.value++; 
      },
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: bgColor, 
          shape: BoxShape.circle, 
          border: Border.all(color: textColor.withOpacity(0.2), width: 2)
        ),
        child: Center(
          child: Text(
            count.toString(),
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderRow(OrderData order, int index) {
    List<Color> cardColors = [const Color(0xFFCDE8E0), const Color(0xFFFFD8C7), const Color(0xFFFDF0D5)];
    Color bgColor = cardColors[index % cardColors.length];
    String shortPaymentStatus = order.paymentStatus.contains("abonado") ? "Abonado" : order.paymentStatus;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: InkWell( 
        onTap: () => _mostrarDetalles(order),
        borderRadius: BorderRadius.circular(15),
        child: Row(
          children: [
            SizedBox(
              width: 38, 
              child: Text(_formatDateToDashboard(order.dateTime).toUpperCase(), textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: mainColor, height: 1.1)),
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
                          Row(
                            children: [
                              Text(order.customer, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(color: _getPaymentColor(order.paymentStatus), borderRadius: BorderRadius.circular(4)),
                                child: Text(shortPaymentStatus, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(_getStatusIcon(order.productionStatus), color: Colors.black87, size: 18),
                    const SizedBox(width: 4),
                    SizedBox(
                      height: 24, width: 24,
                      child: PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        iconSize: 20,
                        onSelected: (val) {
                          if (val.startsWith('status_')) {
                            String nuevoEstado = val.split('_')[1];
                            if (nuevoEstado == "Entregado") {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                  title: Text("Confirmar Entrega", style: TextStyle(color: mainColor)),
                                  content: const Text("¿Estás seguro que deseas marcar este pedido como entregado? Desaparecerá de esta vista."),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: mainColor),
                                      onPressed: () {
                                        order.productionStatus = nuevoEstado;
                                        appDataNotifier.value++; 
                                        Navigator.pop(ctx);
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pedido entregado"), backgroundColor: Colors.green));
                                      },
                                      child: const Text("Confirmar", style: TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                )
                              );
                            } else {
                              order.productionStatus = nuevoEstado;
                              appDataNotifier.value++; 
                            }
                          } else if (val == 'edit') {
                            _abrirFormularioEdicion(order);
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(enabled: false, height: 30, child: Text('Cambiar estado', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold))),
                          PopupMenuItem(value: 'status_Tomado', height: 40, child: Row(children: [Icon(Icons.receipt_long, size: 18, color: order.productionStatus == 'Tomado' ? mainColor : Colors.grey), const SizedBox(width: 10), Text('Tomado', style: TextStyle(fontWeight: order.productionStatus == 'Tomado' ? FontWeight.bold : FontWeight.normal))])),
                          PopupMenuItem(value: 'status_Listo', height: 40, child: Row(children: [Icon(Icons.outdoor_grill, size: 18, color: order.productionStatus == 'Listo' ? mainColor : Colors.grey), const SizedBox(width: 10), Text('Pedido Listo', style: TextStyle(fontWeight: order.productionStatus == 'Listo' ? FontWeight.bold : FontWeight.normal))])),
                          PopupMenuItem(value: 'status_Entregado', height: 40, child: Row(children: [Icon(Icons.local_shipping, size: 18, color: order.productionStatus == 'Entregado' ? mainColor : Colors.grey), const SizedBox(width: 10), Text('Entregado', style: TextStyle(fontWeight: order.productionStatus == 'Entregado' ? FontWeight.bold : FontWeight.normal))])),
                          const PopupMenuDivider(),
                          const PopupMenuItem(value: 'edit', height: 40, child: Row(children: [Icon(Icons.edit, size: 16), SizedBox(width: 8), Text('Editar pedido')])),
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