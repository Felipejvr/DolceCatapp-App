import 'package:flutter/material.dart';

class OrderCard extends StatelessWidget {
  final String product;
  final String customer;
  final String date;
  final String paymentStatus;
  final String productionStatus; 
  final String price; 
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onTap; 
  final Function(String) onStatusChange; 

  const OrderCard({
    super.key,
    required this.product,
    required this.customer,
    required this.date,
    required this.paymentStatus,
    required this.productionStatus,
    required this.price,
    required this.onDelete,
    required this.onEdit,
    required this.onTap,
    required this.onStatusChange,
  });

  Color _getPaymentColor() {
    if (paymentStatus.contains("Pagado")) return Colors.green.shade100; 
    if (paymentStatus.contains("Abonado")) return Colors.orange.shade100; 
    return Colors.red.shade100; 
  }

  Widget _buildPipelineStatic() {
    Color activeCol = const Color(0xFFD98A7A); 
    Color inactiveCol = Colors.grey.shade300;

    double op1 = 1.0; 
    double op2 = (productionStatus == "Listo" || productionStatus == "Entregado") ? 1.0 : 0.3;
    double op3 = (productionStatus == "Entregado") ? 1.0 : 0.3;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(opacity: op1, child: Icon(Icons.receipt_long_outlined, size: 20, color: activeCol)),
        const SizedBox(width: 8),
        Icon(Icons.arrow_right_alt, size: 16, color: inactiveCol),
        const SizedBox(width: 8),
        Opacity(opacity: op2, child: Icon(Icons.outdoor_grill_outlined, size: 20, color: activeCol)),
        const SizedBox(width: 8),
        Icon(Icons.arrow_right_alt, size: 16, color: inactiveCol),
        const SizedBox(width: 8),
        Opacity(opacity: op3, child: Icon(Icons.local_shipping_outlined, size: 20, color: activeCol)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15), 
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08), 
              blurRadius: 8, 
              offset: const Offset(0, 3)
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.cake, color: Colors.brown, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 1),
                      Text(customer, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("\$$price", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFD98A7A))),
                    const SizedBox(height: 1),
                    Text(date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFD98A7A))),
                  ],
                ),
                SizedBox(
                  height: 24, width: 28,
                  child: PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    iconSize: 20,
                    onSelected: (val) {
                      if (val == 'edit') onEdit();
                      else if (val == 'delete') onDelete();
                      else if (val.startsWith('status_')) onStatusChange(val.split('_')[1]);
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(enabled: false, height: 30, child: Text('Estado actual', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold))),
                      PopupMenuItem(value: 'status_Tomado', height: 40, child: Row(children: [Icon(Icons.receipt_long, size: 18, color: productionStatus == 'Tomado' ? const Color(0xFFD98A7A) : Colors.grey), const SizedBox(width: 10), Text('Tomado', style: TextStyle(fontWeight: productionStatus == 'Tomado' ? FontWeight.bold : FontWeight.normal))])),
                      PopupMenuItem(value: 'status_Listo', height: 40, child: Row(children: [Icon(Icons.outdoor_grill, size: 18, color: productionStatus == 'Listo' ? const Color(0xFFD98A7A) : Colors.grey), const SizedBox(width: 10), Text('Pedido Listo', style: TextStyle(fontWeight: productionStatus == 'Listo' ? FontWeight.bold : FontWeight.normal))])),
                      PopupMenuItem(value: 'status_Entregado', height: 40, child: Row(children: [Icon(Icons.local_shipping, size: 18, color: productionStatus == 'Entregado' ? const Color(0xFFD98A7A) : Colors.grey), const SizedBox(width: 10), Text('Entregado', style: TextStyle(fontWeight: productionStatus == 'Entregado' ? FontWeight.bold : FontWeight.normal))])),
                      const PopupMenuDivider(),
                      const PopupMenuItem(value: 'edit', height: 40, child: Row(children: [Icon(Icons.edit, size: 16), SizedBox(width: 8), Text('Editar')])),
                      const PopupMenuItem(value: 'delete', height: 40, child: Row(children: [Icon(Icons.delete, size: 16, color: Colors.red), SizedBox(width: 8), Text('Eliminar', style: TextStyle(color: Colors.red))])),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 16, color: Colors.black12), 
            SizedBox(
              height: 20, 
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: _getPaymentColor(), borderRadius: BorderRadius.circular(5)),
                      child: Text(paymentStatus, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
                    ),
                  ),
                  _buildPipelineStatic(),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}