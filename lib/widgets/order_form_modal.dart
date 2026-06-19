import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../screens/orders_screen.dart';

class ThousandSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    String numbers = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (numbers.isEmpty) return newValue.copyWith(text: '');
    String formatted = numbers.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}

String _formatMonto(int monto) {
  return monto.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');
}

void showOrderForm(BuildContext context, {OrderData? orderToEdit}) {
  final productCtrl = TextEditingController();
  final customerCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final abonoCtrl = TextEditingController();
  final notasCtrl = TextEditingController();

  String tempDate = orderToEdit?.date ?? "";
  String tempPaymentStatus = orderToEdit?.paymentStatus ?? "No pagado";
  String tempProdStatus = orderToEdit?.productionStatus ?? "Tomado";
  List<dynamic> tempImages = List.from(orderToEdit?.imagenesRef ?? []);
  bool isSaving = false;
  int currentStep = 0;

  if (orderToEdit != null) {
    productCtrl.text = orderToEdit.product;
    customerCtrl.text = orderToEdit.customer;
    priceCtrl.text = _formatMonto(orderToEdit.price);
    abonoCtrl.text = _formatMonto(orderToEdit.amountPaid);
    notasCtrl.text = orderToEdit.notas;
  }

  const Color mainColor = Color(0xFFD98A7A);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) {
        // ─── Indicador de pasos ───
        Widget stepIndicator = Row(
          children: [
            Expanded(child: Container(height: 4, decoration: BoxDecoration(color: mainColor, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(width: 6),
            Expanded(child: Container(height: 4, decoration: BoxDecoration(color: currentStep >= 1 ? mainColor : Colors.grey.shade200, borderRadius: BorderRadius.circular(2)))),
          ],
        );

        // ─── Paso 1: datos básicos ───
        Widget step1 = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: productCtrl, decoration: const InputDecoration(labelText: "Producto / Pastel", prefixIcon: Icon(Icons.cake_outlined))),
            TextField(controller: customerCtrl, decoration: const InputDecoration(labelText: "Cliente", prefixIcon: Icon(Icons.person_outline))),
            const SizedBox(height: 4),
            TextField(
              controller: priceCtrl,
              decoration: const InputDecoration(labelText: "Total", prefixText: "\$ ", prefixIcon: Icon(Icons.payments_outlined)),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandSeparatorInputFormatter()],
            ),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              value: tempPaymentStatus,
              decoration: const InputDecoration(labelText: "Estado de pago", prefixIcon: Icon(Icons.account_balance_wallet_outlined)),
              items: ["No pagado", "Monto abonado", "Pagado"]
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (val) => setModalState(() => tempPaymentStatus = val!),
            ),
            if (tempPaymentStatus == "Monto abonado")
              TextField(
                controller: abonoCtrl,
                decoration: const InputDecoration(labelText: "Monto abonado", prefixText: "\$ ", prefixIcon: Icon(Icons.savings_outlined)),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandSeparatorInputFormatter()],
              ),
          ],
        );

        // ─── Paso 2: detalles ───
        Widget step2 = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imágenes
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
                              imagenes: tempImages,
                              indiceInicial: index,
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
                      ),
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
                      setModalState(() {});
                    }
                  },
                  child: Container(
                    width: 70, height: 70,
                    decoration: BoxDecoration(color: const Color(0xFFFFF5F0), borderRadius: BorderRadius.circular(10), border: Border.all(color: mainColor)),
                    child: const Icon(Icons.add_a_photo, color: mainColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),

            // Fecha
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_month, color: mainColor),
              title: Text(
                tempDate.isEmpty ? "Seleccionar Fecha de Entrega" : "Entrega: $tempDate",
                style: TextStyle(color: tempDate.isEmpty ? Colors.red : Colors.black87, fontWeight: FontWeight.w500),
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2024),
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  setModalState(() => tempDate = "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}");
                }
              },
            ),

            // Notas
            TextField(
              controller: notasCtrl,
              decoration: const InputDecoration(labelText: "Notas", prefixIcon: Icon(Icons.notes_outlined)),
              maxLines: 2,
            ),
          ],
        );

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20, right: 20, top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    orderToEdit == null ? "Nuevo Pedido" : "Editar Pedido",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    currentStep == 0 ? "Paso 1 de 2 — Datos básicos" : "Paso 2 de 2 — Fecha e imágenes",
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 12),
                stepIndicator,
                const SizedBox(height: 16),

                currentStep == 0 ? step1 : step2,

                const SizedBox(height: 20),

                // Botones de navegación
                if (currentStep == 0)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mainColor,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: () {
                      if (productCtrl.text.trim().isEmpty) return;
                      setModalState(() => currentStep = 1);
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Siguiente", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                      ],
                    ),
                  )
                else
                  Column(
                    children: [
                      if (isSaving)
                        const Center(child: CircularProgressIndicator(color: mainColor))
                      else
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: mainColor,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          onPressed: () async {
                            if (tempDate.isEmpty) {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                  title: const Row(children: [Icon(Icons.event_busy, color: Colors.orange), SizedBox(width: 10), Text("Falta la fecha")]),
                                  content: const Text("Debes seleccionar una fecha de entrega para guardar el pedido."),
                                  actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Entendido", style: TextStyle(color: mainColor, fontWeight: FontWeight.bold)))],
                                ),
                              );
                              return;
                            }
                            if (productCtrl.text.isEmpty) return;

                            final p = int.tryParse(priceCtrl.text.replaceAll('.', '')) ?? 0;
                            final a = int.tryParse(abonoCtrl.text.replaceAll('.', '')) ?? 0;
                            setModalState(() => isSaving = true);

                            try {
                              List<String> finalImageUrls = [];
                              for (var img in tempImages) {
                                if (img is String) {
                                  finalImageUrls.add(img);
                                } else if (img is Uint8List) {
                                  final fileName = 'pedidos/${DateTime.now().millisecondsSinceEpoch}.jpg';
                                  final ref = FirebaseStorage.instance.ref().child(fileName);
                                  await ref.putData(img, SettableMetadata(contentType: 'image/jpeg'));
                                  finalImageUrls.add(await ref.getDownloadURL());
                                }
                              }

                              final data = {
                                'product': productCtrl.text,
                                'customer': customerCtrl.text,
                                'date': tempDate,
                                'price': p,
                                'amountPaid': a,
                                'paymentStatus': tempPaymentStatus,
                                'productionStatus': tempProdStatus,
                                'notas': notasCtrl.text,
                                'imagenesRef': finalImageUrls,
                              };

                              if (orderToEdit == null) {
                                await FirebaseFirestore.instance.collection('pedidos').add(data);
                              } else {
                                await FirebaseFirestore.instance.collection('pedidos').doc(orderToEdit.id).update(data);
                              }

                              if (context.mounted) Navigator.pop(context);
                            } catch (e) {
                              setModalState(() => isSaving = false);
                            }
                          },
                          child: const Text("Guardar Pedido", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => setModalState(() => currentStep = 0),
                        icon: const Icon(Icons.arrow_back_rounded, size: 16),
                        label: const Text("Anterior"),
                        style: TextButton.styleFrom(foregroundColor: Colors.grey),
                      ),
                    ],
                  ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    ),
  );
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
    if (widget.imagenes.isEmpty) {
      Navigator.pop(context);
    } else {
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
        backgroundColor: Colors.transparent, elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: _eliminarActual)],
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
                    : Image.memory(widget.imagenes[index] as Uint8List, fit: BoxFit.contain),
              );
            },
          ),
          if (_currentIndex > 0)
            Positioned(left: 10, child: CircleAvatar(backgroundColor: Colors.black54, child: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18), onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)))),
          if (_currentIndex < widget.imagenes.length - 1)
            Positioned(right: 10, child: CircleAvatar(backgroundColor: Colors.black54, child: IconButton(icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18), onPressed: () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)))),
          Positioned(
            bottom: 30,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(15)),
              child: Text("${_currentIndex + 1} / ${widget.imagenes.length}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
