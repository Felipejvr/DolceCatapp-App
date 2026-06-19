import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'orders_screen.dart';
import '../widgets/custom_header.dart';

class ChecklistItem {
  String id;
  String name;
  bool isDone;

  ChecklistItem({required this.id, required this.name, this.isDone = false});

  factory ChecklistItem.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return ChecklistItem(
      id: doc.id,
      name: data['name'] ?? '',
      isDone: data['isDone'] ?? false,
    );
  }
}

List<ChecklistItem> globalChecklist = [];

class ComprasScreen extends StatefulWidget {
  const ComprasScreen({super.key});
  @override
  State<ComprasScreen> createState() => _ComprasScreenState();
}

class _ComprasScreenState extends State<ComprasScreen> {
  final Color mainColor = const Color(0xFFD98A7A);
  final _checklistCtrl = TextEditingController();
  StreamSubscription? _checklistSub;

  @override
  void initState() {
    super.initState();
    _escucharChecklist();
  }

  void _escucharChecklist() {
    _checklistSub = FirebaseFirestore.instance
        .collection('compras')
        .orderBy('createdAt')
        .snapshots()
        .listen((snapshot) {
      globalChecklist = snapshot.docs
          .map((doc) => ChecklistItem.fromFirestore(doc))
          .toList();
      if (mounted) {
        appDataNotifier.value++;
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _checklistSub?.cancel();
    _checklistCtrl.dispose();
    super.dispose();
  }

  void _showCalendarPopup() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Lista de Compras", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: mainColor)),
              const SizedBox(height: 10),
              Text("Usa esta pantalla para agregar lo que necesitas comprar.", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              const SizedBox(height: 15),
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Cerrar", style: TextStyle(color: mainColor))),
            ],
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
        builder: (context, _, child) {
          final doneCnt = globalChecklist.where((i) => i.isDone).length;
          final totalCnt = globalChecklist.length;

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 15, left: 15, right: 15, bottom: 20),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFE4E1),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: CustomHeader(onCalendarTap: _showCalendarPopup),
              ),

              if (totalCnt > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "$doneCnt de $totalCnt completados",
                        style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      if (totalCnt - doneCnt > 0)
                        Text(
                          "${totalCnt - doneCnt} pendiente(s)",
                          style: TextStyle(color: mainColor, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _checklistCtrl,
                        decoration: InputDecoration(
                          hintText: "Agregar a la lista...",
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: () async {
                        if (_checklistCtrl.text.isNotEmpty) {
                          await FirebaseFirestore.instance.collection('compras').add({
                            'name': _checklistCtrl.text,
                            'isDone': false,
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                          _checklistCtrl.clear();
                        }
                      },
                      icon: const Icon(Icons.add),
                      style: IconButton.styleFrom(backgroundColor: mainColor),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: globalChecklist.isEmpty
                    ? const Center(
                        child: Text(
                          "Tu lista de compras está vacía.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: globalChecklist.length,
                        itemBuilder: (ctx, i) {
                          final item = globalChecklist[i];
                          return Card(
                            elevation: 0,
                            color: Colors.white,
                            margin: const EdgeInsets.only(bottom: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: CheckboxListTile(
                              value: item.isDone,
                              activeColor: mainColor,
                              title: Text(
                                item.name,
                                style: TextStyle(
                                  decoration: item.isDone ? TextDecoration.lineThrough : null,
                                  color: item.isDone ? Colors.grey : Colors.black87,
                                ),
                              ),
                              secondary: IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                                onPressed: () async {
                                  await FirebaseFirestore.instance.collection('compras').doc(item.id).delete();
                                },
                              ),
                              onChanged: (v) async {
                                await FirebaseFirestore.instance
                                    .collection('compras')
                                    .doc(item.id)
                                    .update({'isDone': v});
                              },
                            ),
                          );
                        },
                      ),
              ),

              if (globalChecklist.any((i) => i.isDone))
                Padding(
                  padding: const EdgeInsets.all(15),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          title: Text("Limpiar completados", style: TextStyle(color: mainColor)),
                          content: const Text("¿Eliminar los elementos completados de la lista?"),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: mainColor),
                              onPressed: () async {
                                Navigator.pop(ctx);
                                var batch = FirebaseFirestore.instance.batch();
                                for (var item in globalChecklist.where((x) => x.isDone)) {
                                  batch.delete(FirebaseFirestore.instance.collection('compras').doc(item.id));
                                }
                                await batch.commit();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Lista limpiada"), backgroundColor: Colors.green),
                                  );
                                }
                              },
                              child: const Text("Confirmar", style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.delete_sweep),
                    label: const Text("Limpiar completados", style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 45),
                      backgroundColor: Colors.white,
                      foregroundColor: mainColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                        side: BorderSide(color: mainColor.withOpacity(0.5)),
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
}
