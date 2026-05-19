import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:table_calendar/table_calendar.dart';
import 'orders_screen.dart'; 
import '../widgets/custom_header.dart';

// ==========================================
// MODELOS DE DATOS
// ==========================================
class InventoryItem {
  String id; String name; String category; 
  int quantity; String unit; int minThreshold; int lastPrice;

  InventoryItem({
    required this.id, required this.name, required this.category,
    required this.quantity, required this.unit, required this.minThreshold, required this.lastPrice,
  });
}

class ChecklistItem {
  String id; String name; bool isDone;
  ChecklistItem({required this.id, required this.name, this.isDone = false});
}

// Listas y Controles Globales (Para que el Dashboard los pueda modificar)
List<InventoryItem> globalInventory = [
  InventoryItem(id: '1', name: 'Harina sin polvos', category: 'Secos', quantity: 15, unit: 'kg', minThreshold: 5, lastPrice: 1200),
  InventoryItem(id: '2', name: 'Mantequilla sin sal', category: 'Refrigerados', quantity: 2, unit: 'kg', minThreshold: 4, lastPrice: 8500),
  InventoryItem(id: '3', name: 'Cajas 20x20 altas', category: 'Empaque', quantity: 0, unit: 'un', minThreshold: 10, lastPrice: 450),
];
List<ChecklistItem> globalChecklist = [];

// NUEVO: Filtros globales para que el dashboard los modifique
Set<String> globalSelectedStatuses = {};   
ValueNotifier<int> inventoryTabNotifier = ValueNotifier(0); // Para forzar ir a la pestaña "Inventario"

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> with SingleTickerProviderStateMixin {
  final Color mainColor = const Color(0xFFD98A7A);
  final Color pastelPink = const Color(0xFFFDE9E0);
  
  late TabController _tabController;
  late PageController _pageController;
  DateTime _focusedDay = DateTime.now();

  // Controladores de búsqueda
  final _searchController = TextEditingController();
  String _searchQuery = "";
  Set<String> _selectedCategories = {}; 

  // Controladores de formularios
  final _checklistCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _minCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _pageController = PageController();

    // Escucha si el Dashboard pide cambiar a la pestaña de "Inventario"
    inventoryTabNotifier.addListener(_onTabNotifierChanged);
  }

  void _onTabNotifierChanged() {
    if (mounted && _tabController.index != inventoryTabNotifier.value) {
      _tabController.animateTo(inventoryTabNotifier.value);
      _pageController.jumpToPage(inventoryTabNotifier.value);
    }
  }

  @override
  void dispose() {
    inventoryTabNotifier.removeListener(_onTabNotifierChanged);
    _tabController.dispose(); _pageController.dispose();
    _searchController.dispose(); _checklistCtrl.dispose();
    super.dispose();
  }

  // --- LÓGICA DE BÚSQUEDA Y FILTRADO MÚLTIPLE ---
  List<InventoryItem> _getFilteredInventory() {
    return globalInventory.where((item) {
      bool matchesSearch = item.name.toLowerCase().contains(_searchQuery.toLowerCase());
      bool matchesCategory = _selectedCategories.isEmpty || _selectedCategories.contains(item.category);
      
      bool matchesStatus = true;
      if (globalSelectedStatuses.isNotEmpty) {
        String currentStatus = "Hay stock";
        if (item.quantity == 0) {
          currentStatus = "Crítico";
        } else if (item.quantity <= item.minThreshold) {
          currentStatus = "Alerta";
        }
        matchesStatus = globalSelectedStatuses.contains(currentStatus);
      }

      return matchesSearch && matchesCategory && matchesStatus;
    }).toList();
  }

  // --- MENÚ INFERIOR DE FILTROS ---
  void _mostrarFiltros() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 30),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Filtros Avanzados", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              _selectedCategories.clear();
                              globalSelectedStatuses.clear();
                            });
                            setState(() {}); 
                          },
                          child: Text("Limpiar todo", style: TextStyle(color: mainColor, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 10),
                            const Text("Categorías", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                            const SizedBox(height: 5),
                            _buildChecklistItem("Secos", _selectedCategories, setModalState),
                            _buildChecklistItem("Refrigerados", _selectedCategories, setModalState),
                            _buildChecklistItem("Decoración", _selectedCategories, setModalState),
                            _buildChecklistItem("Empaque", _selectedCategories, setModalState),
                            
                            const SizedBox(height: 20),
                            const Text("Estado del Stock", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                            const SizedBox(height: 5),
                            _buildChecklistItem("Crítico", globalSelectedStatuses, setModalState),
                            _buildChecklistItem("Alerta", globalSelectedStatuses, setModalState),
                            _buildChecklistItem("Hay stock", globalSelectedStatuses, setModalState),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: mainColor, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Ver resultados", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildChecklistItem(String title, Set<String> targetSet, Function setModalState) {
    return CheckboxListTile(
      title: Text(title, style: const TextStyle(fontSize: 14)),
      value: targetSet.contains(title),
      activeColor: mainColor,
      dense: true, 
      contentPadding: EdgeInsets.zero, 
      controlAffinity: ListTileControlAffinity.leading, 
      onChanged: (bool? value) {
        setModalState(() {
          if (value == true) {
            targetSet.add(title);
          } else {
            targetSet.remove(title);
          }
        });
        setState(() {}); 
      },
    );
  }

  // --- CAMBIO MANUAL DE CANTIDAD ---
  void _editarCantidadManual(InventoryItem item) {
    final manualQtyCtrl = TextEditingController(text: item.quantity.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text("Editar Stock: ${item.name}", style: const TextStyle(fontSize: 16)),
        content: TextField(
          controller: manualQtyCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: "Cantidad en ${item.unit}", suffixText: item.unit),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: mainColor),
            onPressed: () {
              setState(() => item.quantity = int.tryParse(manualQtyCtrl.text) ?? 0);
              appDataNotifier.value++; 
              Navigator.pop(context);
            },
            child: const Text("Actualizar", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  // --- ELIMINAR INSUMO ---
  void _confirmarEliminacion(InventoryItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8), Text("Eliminar insumo")]),
        content: Text("Se borrará '${item.name}' permanentemente."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() => globalInventory.remove(item));
              appDataNotifier.value++; 
              Navigator.pop(context);
            },
            child: const Text("Eliminar", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  // --- FORMULARIO DE INSUMO ---
  void _abrirFormularioInsumo({InventoryItem? itemToEdit}) {
    String selectedCat = itemToEdit?.category ?? 'Secos';
    String selectedUnit = itemToEdit?.unit ?? 'un';
    _nameCtrl.text = itemToEdit?.name ?? "";
    _qtyCtrl.text = itemToEdit?.quantity.toString() ?? "";
    _minCtrl.text = itemToEdit?.minThreshold.toString() ?? "";
    _priceCtrl.text = itemToEdit?.lastPrice.toString() ?? "";

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(itemToEdit == null ? "Nuevo Insumo" : "Editar Insumo", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: "Nombre")),
                Row(
                  children: [
                    Expanded(child: DropdownButtonFormField<String>(value: selectedCat, items: ["Secos", "Refrigerados", "Decoración", "Empaque"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setModalState(() => selectedCat = v!))),
                    const SizedBox(width: 10),
                    Expanded(child: DropdownButtonFormField<String>(value: selectedUnit, items: ["un", "kg", "gr", "lt", "ml"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setModalState(() => selectedUnit = v!))),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _qtyCtrl, decoration: const InputDecoration(labelText: "Stock"), keyboardType: TextInputType.number)),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: _minCtrl, decoration: const InputDecoration(labelText: "Alerta Mín."), keyboardType: TextInputType.number)),
                  ],
                ),
                TextField(controller: _priceCtrl, decoration: const InputDecoration(labelText: "Precio", prefixText: "\$"), keyboardType: TextInputType.number),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: mainColor, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  onPressed: () {
                    setState(() {
                      if (itemToEdit == null) {
                        globalInventory.add(InventoryItem(id: DateTime.now().toString(), name: _nameCtrl.text, category: selectedCat, quantity: int.tryParse(_qtyCtrl.text) ?? 0, unit: selectedUnit, minThreshold: int.tryParse(_minCtrl.text) ?? 0, lastPrice: int.tryParse(_priceCtrl.text) ?? 0));
                      } else {
                        itemToEdit.name = _nameCtrl.text; itemToEdit.category = selectedCat; itemToEdit.unit = selectedUnit;
                        itemToEdit.quantity = int.tryParse(_qtyCtrl.text) ?? 0; itemToEdit.minThreshold = int.tryParse(_minCtrl.text) ?? 0; itemToEdit.lastPrice = int.tryParse(_priceCtrl.text) ?? 0;
                      }
                    });
                    appDataNotifier.value++; 
                    Navigator.pop(context);
                  },
                  child: const Text("Guardar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
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
                    String d = selectedDay.day.toString().padLeft(2, '0'); String m = selectedDay.month.toString().padLeft(2, '0');
                    globalSearchNotifier.value = "$d/$m/${selectedDay.year}"; appTabIndex.value = 1; 
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
      floatingActionButton: _tabController.index == 0 ? FloatingActionButton(onPressed: () => _abrirFormularioInsumo(), backgroundColor: mainColor, mini: true, child: const Icon(Icons.add, color: Colors.white, size: 20)) : null,
      
      // EL ESCUCHADOR ENVOLVIENDO TODO EL BODY
      body: ValueListenableBuilder<int>(
        valueListenable: appDataNotifier,
        builder: (context, dataValue, child) {
          
          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 15, left: 15, right: 15, bottom: 20),
                decoration: const BoxDecoration(color: Color(0xFFFFE4E1), borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30))),
                child: CustomHeader(title: "DolceCatapp", onCalendarTap: _showCalendarPopup),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: TabBar(
                  controller: _tabController, labelColor: mainColor, unselectedLabelColor: Colors.grey,
                  indicatorSize: TabBarIndicatorSize.tab, indicator: BoxDecoration(color: pastelPink, borderRadius: const BorderRadius.vertical(top: Radius.circular(15))),
                  tabs: const [Tab(text: "Inventario"), Tab(text: "Por Comprar")],
                  onTap: (i) => setState(() => _pageController.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)),
                ),
              ),
              Expanded(
                child: Container(
                  color: pastelPink,
                  child: PageView(
                    controller: _pageController, onPageChanged: (i) => setState(() => _tabController.animateTo(i)),
                    children: [_buildInventarioTab(), _buildComprasTab()],
                  ),
                ),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildInventarioTab() {
    final filteredItems = _getFilteredInventory();
    bool isFilterActive = _selectedCategories.isNotEmpty || globalSelectedStatuses.isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))]),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: "Buscar insumo...", hintStyle: const TextStyle(fontSize: 13),
                      prefixIcon: Icon(Icons.search, color: mainColor, size: 18),
                      suffixIcon: _searchController.text.isNotEmpty 
                          ? IconButton(icon: const Icon(Icons.clear, size: 16, color: Colors.grey), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ""); }) : null,
                      border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                height: 40, width: 45,
                decoration: BoxDecoration(color: isFilterActive ? mainColor : Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))]),
                child: IconButton(padding: EdgeInsets.zero, icon: Icon(Icons.filter_list, color: isFilterActive ? Colors.white : mainColor, size: 22), onPressed: _mostrarFiltros),
              )
            ],
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: filteredItems.length,
            itemBuilder: (context, index) {
              final item = filteredItems[index];
              Color statusColor = item.quantity == 0 ? Colors.red : (item.quantity <= item.minThreshold ? Colors.orange : Colors.green);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                child: Row(
                  children: [
                    Container(width: 40, height: 40, decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(_getCategoryIcon(item.category), color: statusColor, size: 20)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), Text("\$${item.lastPrice} · ${item.category}", style: const TextStyle(fontSize: 11, color: Colors.grey))])),
                    
                    Row(
                      children: [
                        IconButton(icon: const Icon(Icons.remove_circle_outline, size: 20), onPressed: () => setState(() { if(item.quantity > 0) item.quantity--; appDataNotifier.value++; })),
                        InkWell(
                          onTap: () => _editarCantidadManual(item),
                          child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: pastelPink, borderRadius: BorderRadius.circular(8)), child: Text("${item.quantity} ${item.unit}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                        ),
                        IconButton(icon: const Icon(Icons.add_circle_outline, size: 20, color: Color(0xFFD98A7A)), onPressed: () => setState(() { item.quantity++; appDataNotifier.value++; })),
                      ],
                    ),
                    
                    PopupMenuButton<String>(
                      onSelected: (val) => val == 'edit' ? _abrirFormularioInsumo(itemToEdit: item) : _confirmarEliminacion(item),
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text("Editar")])),
                        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 18), SizedBox(width: 8), Text("Eliminar", style: TextStyle(color: Colors.red))])),
                      ],
                    )
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

Widget _buildComprasTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(child: TextField(controller: _checklistCtrl, decoration: InputDecoration(hintText: "Agregar a la lista...", filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () { 
                  if(_checklistCtrl.text.isNotEmpty) {
                    setState(() { 
                      globalChecklist.add(ChecklistItem(id: DateTime.now().toString(), name: _checklistCtrl.text)); 
                      _checklistCtrl.clear(); 
                      appDataNotifier.value++; // <--- ESTO AVISA AL DASHBOARD
                    }); 
                  }
                }, 
                icon: const Icon(Icons.add), 
                style: IconButton.styleFrom(backgroundColor: mainColor)
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: globalChecklist.length,
            itemBuilder: (ctx, i) {
              final item = globalChecklist[i];
              return Card(
                elevation: 0, color: Colors.white,
                child: CheckboxListTile(
                  value: item.isDone, 
                  activeColor: mainColor, 
                  title: Text(item.name, style: TextStyle(decoration: item.isDone ? TextDecoration.lineThrough : null)),
                  onChanged: (v) => setState(() { 
                    item.isDone = v!; 
                    appDataNotifier.value++; // <--- ESTO AVISA AL DASHBOARD
                  }),
                  secondary: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.grey), 
                    onPressed: () => setState(() { 
                      globalChecklist.removeAt(i); 
                      appDataNotifier.value++; // <--- ESTO AVISA AL DASHBOARD
                    })
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(15),
          child: ElevatedButton.icon(
            onPressed: () => setState(() { 
              globalChecklist.removeWhere((x) => x.isDone); 
              appDataNotifier.value++; // <--- ESTO AVISA AL DASHBOARD
            }), 
            icon: const Icon(Icons.delete_sweep), 
            label: const Text("Limpiar completados", style: TextStyle(fontWeight: FontWeight.bold)), 
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 45), backgroundColor: Colors.white, foregroundColor: mainColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: mainColor.withOpacity(0.5))))
          ),
        )
      ],
    );
  }

  IconData _getCategoryIcon(String category) {
    if (category == 'Secos') return Icons.grain;
    if (category == 'Refrigerados') return Icons.ac_unit;
    if (category == 'Decoración') return Icons.color_lens;
    return Icons.inventory_2;
  }
}