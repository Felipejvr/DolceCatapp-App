import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:table_calendar/table_calendar.dart'; 
import 'dart:typed_data';
import 'dart:async'; 
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_storage/firebase_storage.dart'; 

import '../widgets/order_card.dart';
import '../widgets/custom_header.dart';

class CLPInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    String cleanText = newValue.text.replaceAll('.', '');
    String formattedText = cleanText.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}

class OrderData {
  String id; 
  String product; 
  String customer; 
  String date; 
  int price;
  int amountPaid; 
  String paymentStatus; 
  String productionStatus; 
  String notas;
  List<dynamic> imagenesRef;

  OrderData({
    required this.id, required this.product, required this.customer,
    required this.date, required this.price, this.amountPaid = 0,
    required this.paymentStatus, required this.productionStatus, required this.notas,
    this.imagenesRef = const [], 
  });

  DateTime get dateTime {
    try {
      List<String> parts = date.split('/');
      return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
    } catch (e) { return DateTime(2099); }
  }

  factory OrderData.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return OrderData(
      id: doc.id,
      product: data['product'] ?? '',
      customer: data['customer'] ?? '',
      date: data['date'] ?? '',
      price: data['price'] ?? 0,
      amountPaid: data['amountPaid'] ?? 0,
      paymentStatus: data['paymentStatus'] ?? 'No pagado',
      productionStatus: data['productionStatus'] ?? 'Tomado',
      notas: data['notas'] ?? '',
      imagenesRef: data['imagenesRef'] != null ? List<dynamic>.from(data['imagenesRef']) : [],
    );
  }
}

// ==========================================
// NOTIFICADORES GLOBALES
// ==========================================
List<OrderData> globalOrders = [];
bool isDataLoaded = false; // EL INTERRUPTOR QUE CONTROLA LAS CARGAS
ValueNotifier<int> appDataNotifier = ValueNotifier(0);
ValueNotifier<int> appTabIndex = ValueNotifier(0);
ValueNotifier<String> globalSearchNotifier = ValueNotifier("");

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  String _searchQuery = "";
  DateTime _focusedDay = DateTime.now();
  
  final _searchController = TextEditingController(); 
  final _productCtrl = TextEditingController();
  final _customerCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _abonoCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();

  late TabController _tabController;
  late PageController _pageController; 
  
  StreamSubscription? _pedidosSub; 

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _pageController = PageController(); 

    _searchController.text = globalSearchNotifier.value;
    _searchQuery = globalSearchNotifier.value;

    globalSearchNotifier.addListener(_onGlobalSearchChanged);
    
    _escucharPedidos();
  }

  void _escucharPedidos() {
    _pedidosSub = FirebaseFirestore.instance.collection('pedidos').snapshots().listen((snapshot) {
      globalOrders = snapshot.docs.map((doc) => OrderData.fromFirestore(doc)).toList();
      isDataLoaded = true; // Avisa a toda la app que ya hay datos
      if (mounted) {
        appDataNotifier.value++; 
      }
    }, onError: (error) {
      // Si hay un error (ej. sin internet), quitamos la pantalla de carga para no dejar la app pegada
      isDataLoaded = true; 
      if (mounted) appDataNotifier.value++;
      print("Error en Firebase: $error");
    });
  }

  void _onGlobalSearchChanged() {
    if (mounted) {
      setState(() {
        _searchController.text = globalSearchNotifier.value;
        _searchQuery = globalSearchNotifier.value;
        if (_searchQuery.isNotEmpty && _tabController.index != 0) {
          _tabController.animateTo(0);
          _pageController.jumpToPage(0);
        }
      });
    }
  }

  @override
  void dispose() { 
    _pedidosSub?.cancel(); 
    globalSearchNotifier.removeListener(_onGlobalSearchChanged);
    _tabController.dispose(); 
    _pageController.dispose(); 
    _searchController.dispose();
    super.dispose(); 
  }

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
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Agenda de Pedidos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFD98A7A))),
                const SizedBox(height: 10),
                TableCalendar(
                  firstDay: DateTime.utc(2024, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  eventLoader: _getOrdersForDay,
                  headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
                  
                  onHeaderTapped: (day) async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _focusedDay,
                      firstDate: DateTime(2024), lastDate: DateTime(2030),
                      initialDatePickerMode: DatePickerMode.year,
                    );
                    if (picked != null) {
                      setDialogState(() => _focusedDay = picked);
                      setState(() => _focusedDay = picked);
                    }
                  },
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(color: const Color(0xFFD98A7A).withOpacity(0.3), shape: BoxShape.circle),
                    selectedDecoration: const BoxDecoration(color: Color(0xFFD98A7A), shape: BoxShape.circle),
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
                  onDaySelected: (selectedDay, focusedDay) {
                    Navigator.pop(context);
                    String d = selectedDay.day.toString().padLeft(2, '0');
                    String m = selectedDay.month.toString().padLeft(2, '0');
                    String y = selectedDay.year.toString();
                    globalSearchNotifier.value = "$d/$m/$y"; 
                  },
                  onPageChanged: (focusedDay) => _focusedDay = focusedDay,
                ),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cerrar", style: TextStyle(color: Color(0xFFD98A7A)))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatCLP(int value) => value.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');

  List<OrderData> _getListaFiltrada(bool esFinalizado) {
    return globalOrders.where((o) { 
      bool coincidePestana = esFinalizado ? (o.productionStatus == "Entregado") : (o.productionStatus != "Entregado");
      bool coincideBusqueda = o.product.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                              o.customer.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                              o.date.contains(_searchQuery); 
      return coincidePestana && coincideBusqueda;
    }).toList()..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  void _abrirFormulario({OrderData? orderToEdit}) {
    String tempDate = orderToEdit?.date ?? "";
    String tempPaymentStatus = orderToEdit?.paymentStatus ?? "No pagado";
    String tempProdStatus = orderToEdit?.productionStatus ?? "Tomado";
    List<dynamic> tempImages = List.from(orderToEdit?.imagenesRef ?? []); 
    bool isSaving = false; 

    if (orderToEdit != null) {
      _productCtrl.text = orderToEdit.product;
      _customerCtrl.text = orderToEdit.customer;
      _priceCtrl.text = _formatCLP(orderToEdit.price);
      _abonoCtrl.text = _formatCLP(orderToEdit.amountPaid);
      _notasCtrl.text = orderToEdit.notas;
    } else {
      _productCtrl.clear(); _customerCtrl.clear(); _priceCtrl.clear(); _abonoCtrl.clear(); _notasCtrl.clear();
    }

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
                Center(child: Text(orderToEdit == null ? "Nuevo Pedido" : "Editar Pedido", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                TextField(controller: _productCtrl, decoration: const InputDecoration(labelText: "Producto")),
                TextField(controller: _customerCtrl, decoration: const InputDecoration(labelText: "Cliente")),
                TextField(controller: _priceCtrl, decoration: const InputDecoration(labelText: "Total", prefixText: "\$ "), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, CLPInputFormatter()]),
                DropdownButtonFormField<String>(value: tempPaymentStatus, items: ["No pagado", "Monto abonado", "Pagado"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (val) => setModalState(() => tempPaymentStatus = val!)),
                if (tempPaymentStatus == "Monto abonado") TextField(controller: _abonoCtrl, decoration: const InputDecoration(labelText: "Abono", prefixText: "\$ "), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, CLPInputFormatter()]),
                TextField(controller: _notasCtrl, decoration: const InputDecoration(labelText: "Notas"), maxLines: 2),
                
                const SizedBox(height: 15),
                const Text("Imágenes de referencia", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                
                Wrap(
                  spacing: 10, runSpacing: 10,
                  children: [
                    ...List.generate(tempImages.length, (index) {
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => VisorImagenes(
                                  imagenes: tempImages, indiceInicial: index,
                                  onEliminar: (idx) => setModalState(() => tempImages.removeAt(idx)),
                                ),
                              ));
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: tempImages[index] is String 
                                ? Image.network(tempImages[index], width: 70, height: 70, fit: BoxFit.cover)
                                : Image.memory(tempImages[index] as Uint8List, width: 70, height: 70, fit: BoxFit.cover),
                            ),
                          ),
                          Positioned(
                            right: -5, top: -5,
                            child: GestureDetector(
                              onTap: () => setModalState(() => tempImages.removeAt(index)),
                              child: const CircleAvatar(radius: 12, backgroundColor: Colors.red, child: Icon(Icons.close, size: 14, color: Colors.white)),
                            ),
                          )
                        ],
                      );
                    }),
                    GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        final List<XFile> images = await picker.pickMultiImage(); 
                        if (images.isNotEmpty) {
                          for (var img in images) {
                            final bytes = await img.readAsBytes();
                            tempImages.add(bytes);
                          }
                          setModalState((){});
                        }
                      },
                      child: Container(
                        width: 70, height: 70,
                        decoration: BoxDecoration(color: const Color(0xFFFFF5F0), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFD98A7A))),
                        child: const Icon(Icons.add_a_photo, color: Color(0xFFD98A7A)),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 15),
                ListTile(leading: const Icon(Icons.calendar_month), title: Text(tempDate.isEmpty ? "Seleccionar Fecha" : "Fecha: $tempDate"), onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2024), lastDate: DateTime(2030));
                  if (picked != null) setModalState(() => tempDate = "${picked.day.toString().padLeft(2,'0')}/${picked.month.toString().padLeft(2,'0')}/${picked.year}");
                }),
                const SizedBox(height: 20),
                
                isSaving 
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFD98A7A)))
                : ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD98A7A), minimumSize: const Size(double.maxFinite, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  onPressed: () async {
                    if (_productCtrl.text.isEmpty || tempDate.isEmpty) return;
                    
                    int p = int.tryParse(_priceCtrl.text.replaceAll('.', '')) ?? 0;
                    int a = int.tryParse(_abonoCtrl.text.replaceAll('.', '')) ?? 0;
                    
                    if (orderToEdit == null) {
                      setModalState(() => isSaving = true);
                      
                      try {
                        List<String> finalImageUrls = [];
                        for (var img in tempImages) {
                          if (img is String) finalImageUrls.add(img);
                          if (img is Uint8List) {
                            String fileName = 'pedidos/${DateTime.now().millisecondsSinceEpoch}.jpg';
                            Reference ref = FirebaseStorage.instance.ref().child(fileName);
                            await ref.putData(img);
                            finalImageUrls.add(await ref.getDownloadURL());
                          }
                        }

                        await FirebaseFirestore.instance.collection('pedidos').add({
                          'product': _productCtrl.text,
                          'customer': _customerCtrl.text,
                          'date': tempDate,
                          'price': p,
                          'amountPaid': a,
                          'paymentStatus': tempPaymentStatus,
                          'productionStatus': tempProdStatus,
                          'notas': _notasCtrl.text,
                          'imagenesRef': finalImageUrls,
                        });

                        if(mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pedido guardado en la nube"), backgroundColor: Colors.green));
                        }
                      } catch (e) {
                        setModalState(() => isSaving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al guardar: $e"), backgroundColor: Colors.red));
                        }
                      }
                    } else {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          title: const Text("Confirmar cambios", style: TextStyle(color: Color(0xFFD98A7A))),
                          content: const Text("¿Estás seguro que deseas guardar las modificaciones?"),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD98A7A)),
                              onPressed: () async {
                                Navigator.pop(ctx); 
                                setModalState(() => isSaving = true); 
                                
                                try {
                                  List<String> finalImageUrls = [];
                                  for (var img in tempImages) {
                                    if (img is String) finalImageUrls.add(img);
                                    if (img is Uint8List) {
                                      String fileName = 'pedidos/${DateTime.now().millisecondsSinceEpoch}.jpg';
                                      Reference ref = FirebaseStorage.instance.ref().child(fileName);
                                      await ref.putData(img);
                                      finalImageUrls.add(await ref.getDownloadURL());
                                    }
                                  }

                                  await FirebaseFirestore.instance.collection('pedidos').doc(orderToEdit.id).update({
                                    'product': _productCtrl.text,
                                    'customer': _customerCtrl.text,
                                    'date': tempDate,
                                    'price': p,
                                    'amountPaid': a,
                                    'paymentStatus': tempPaymentStatus,
                                    'productionStatus': tempProdStatus,
                                    'notas': _notasCtrl.text,
                                    'imagenesRef': finalImageUrls,
                                  });

                                  if(mounted) {
                                    Navigator.pop(context); 
                                    Navigator.pop(context); 
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cambios guardados en la nube"), backgroundColor: Colors.green));
                                  }
                                } catch (e) {
                                  setModalState(() => isSaving = false);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al actualizar: $e"), backgroundColor: Colors.red));
                                  }
                                }
                              },
                              child: const Text("Guardar", style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        )
                      );
                    }
                  }, 
                  child: const Text("Guardar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _mostrarDetalles(OrderData order) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder( 
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFFFFF5F0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [Icon(Icons.info_outline, color: Color(0xFFD98A7A)), SizedBox(width: 10), Text("Detalles", style: TextStyle(color: Color(0xFFD98A7A), fontWeight: FontWeight.bold))]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _itemDetalle("Producto", order.product, Icons.cake),
                _itemDetalle("Cliente", order.customer, Icons.person),
                _itemDetalle("Entrega", order.date, Icons.calendar_today),
                _itemDetalle("Total", "\$${_formatCLP(order.price)}", Icons.payments),
                _itemDetalle("Abonado", "\$${_formatCLP(order.amountPaid)}", Icons.account_balance_wallet),
                _itemDetalle("Pago", order.paymentStatus, Icons.check_circle_outline),
                _itemDetalle("Producción", order.productionStatus, Icons.shutter_speed),
                const Divider(),
                const Text("Notas:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                Text(order.notas.isEmpty ? "Sin notas." : order.notas, style: const TextStyle(fontStyle: FontStyle.italic)),
                
                if (order.imagenesRef.isNotEmpty) ...[
                  const SizedBox(height: 15),
                  const Text("Imágenes adjuntas:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10, runSpacing: 10,
                    children: List.generate(order.imagenesRef.length, (index) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => VisorImagenes(imagenes: order.imagenesRef, indiceInicial: index, onEliminar: (idx) {
                                  setDialogState(() => order.imagenesRef.removeAt(idx));
                                  appDataNotifier.value++; 
                                }),
                              ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10), 
                          child: order.imagenesRef[index] is String 
                              ? Image.network(order.imagenesRef[index], width: 60, height: 60, fit: BoxFit.cover)
                              : Image.memory(order.imagenesRef[index] as Uint8List, width: 60, height: 60, fit: BoxFit.cover)
                        ),
                      );
                    }),
                  )
                ]
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); 
                _abrirFormulario(orderToEdit: order); 
              }, 
              child: const Text("Editar", style: TextStyle(color: Color(0xFFD98A7A), fontWeight: FontWeight.bold))
            ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cerrar", style: TextStyle(color: Colors.grey))),
          ],
        ),
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
    const Color pastelPink = Color(0xFFFDE9E0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(onPressed: () => _abrirFormulario(), backgroundColor: const Color(0xFFD98A7A), mini: true, child: const Icon(Icons.add, color: Colors.white, size: 20)),
      
      body: ValueListenableBuilder<int>(
        valueListenable: appDataNotifier,
        builder: (context, dataValue, child) {
          
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
              
              const SizedBox(height: 15),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: TextField(
                    controller: _searchController, 
                    onChanged: (v) {
                      setState(() => _searchQuery = v);
                      globalSearchNotifier.value = v;
                    }, 
                    decoration: InputDecoration(
                      hintText: "Buscar cliente, producto, fecha...", 
                      hintStyle: const TextStyle(fontSize: 13), 
                      prefixIcon: const Icon(Icons.search, color: Color(0xFFD98A7A), size: 18), 
                      suffixIcon: _searchController.text.isNotEmpty 
                        ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ""); globalSearchNotifier.value = ""; })
                        : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    )
                  ),
                ),
              ),
              
              const SizedBox(height: 15),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: TabBar(
                  controller: _tabController,
                  labelColor: const Color(0xFFD98A7A),
                  unselectedLabelColor: Colors.grey[600],
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: const BoxDecoration(color: pastelPink, borderRadius: BorderRadius.only(topLeft: Radius.circular(15), topRight: Radius.circular(15))),
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
                  tabs: const [Tab(text: "En progreso"), Tab(text: "Finalizados")],
                  onTap: (index) => _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                ),
              ),
              Expanded(
                child: Container(
                  color: pastelPink,
                  child: PageView(
                    controller: _pageController, 
                    onPageChanged: (index) => setState(() => _tabController.animateTo(index)), 
                    children: [_buildListHojaDeLibro(esFinalizado: false), _buildListHojaDeLibro(esFinalizado: true)]
                  )
                )
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildListHojaDeLibro({required bool esFinalizado}) {
    if (!isDataLoaded) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFD98A7A)));
    }

    final lista = _getListaFiltrada(esFinalizado);
    if (lista.isEmpty) return Center(child: Text(esFinalizado ? "Sin pedidos finalizados" : "Sin pedidos activos.", style: TextStyle(color: Colors.grey[600], fontSize: 13)));
    
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: lista.length,
      itemBuilder: (context, index) {
        final order = lista[index];
        String payStatus = order.paymentStatus;
        if (payStatus == "Monto abonado") payStatus = "Abonado: \$${_formatCLP(order.amountPaid)}";
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: OrderCard(
            product: order.product, 
            customer: order.customer, 
            date: order.date, 
            paymentStatus: payStatus, 
            productionStatus: order.productionStatus, 
            price: _formatCLP(order.price),
            onDelete: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 10), Text("Eliminar Pedido", style: TextStyle(color: Colors.red))]),
                  content: Text("¿Estás seguro que deseas eliminar permanentemente el pedido de '${order.product}'?"),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () {
                        FirebaseFirestore.instance.collection('pedidos').doc(order.id).delete();
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pedido eliminado de la nube"), backgroundColor: Colors.red));
                      },
                      child: const Text("Eliminar", style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
            },
            onEdit: () => _abrirFormulario(orderToEdit: order),
            onTap: () => _mostrarDetalles(order), 
            onStatusChange: (nuevoEstado) {
              if (nuevoEstado == "Entregado") {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    title: const Text("Confirmar Entrega", style: TextStyle(color: Color(0xFFD98A7A))),
                    content: const Text("¿Estás seguro que deseas marcar este pedido como entregado? Se moverá a la pestaña de finalizados."),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD98A7A)),
                        onPressed: () {
                          FirebaseFirestore.instance.collection('pedidos').doc(order.id).update({'productionStatus': nuevoEstado});
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pedido movido a Finalizados"), backgroundColor: Colors.green));
                        },
                        child: const Text("Confirmar", style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  )
                );
              } else {
                FirebaseFirestore.instance.collection('pedidos').doc(order.id).update({'productionStatus': nuevoEstado});
              }
            },
          ),
        );
      },
    );
  }
}

class VisorImagenes extends StatefulWidget {
  final List<dynamic> imagenes; 
  final int indiceInicial;
  final Function(int) onEliminar;

  const VisorImagenes({super.key, required this.imagenes, required this.indiceInicial, required this.onEliminar});

  @override
  State<VisorImagenes> createState() => _VisorImagenesState();
}

class _VisorImagenesState extends State<VisorImagenes> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.indiceInicial;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() { _pageController.dispose(); super.dispose(); }

  void _eliminarActual() {
    widget.onEliminar(_currentIndex);
    if (widget.imagenes.isEmpty) { Navigator.pop(context); } else {
      if (_currentIndex >= widget.imagenes.length) _currentIndex = widget.imagenes.length - 1; 
      _pageController.jumpToPage(_currentIndex);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.white),
        actions: [ IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: _eliminarActual) ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          PageView.builder(
            controller: _pageController, itemCount: widget.imagenes.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) { 
              return InteractiveViewer(
                minScale: 0.5, maxScale: 4.0, 
                child: widget.imagenes[index] is String 
                    ? Image.network(widget.imagenes[index], fit: BoxFit.contain)
                    : Image.memory(widget.imagenes[index] as Uint8List, fit: BoxFit.contain)
              ); 
            },
          ),
          if (_currentIndex > 0)
            Positioned(left: 10, child: CircleAvatar(backgroundColor: Colors.black54, child: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18), onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)))),
          if (_currentIndex < widget.imagenes.length - 1)
            Positioned(right: 10, child: CircleAvatar(backgroundColor: Colors.black54, child: IconButton(icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18), onPressed: () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)))),
          Positioned(bottom: 30, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(15)), child: Text("${_currentIndex + 1} / ${widget.imagenes.length}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))
        ],
      ),
    );
  }
}