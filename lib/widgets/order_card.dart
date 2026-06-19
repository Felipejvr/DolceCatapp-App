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

  bool get _isPagado => paymentStatus.contains("Pagado") && !paymentStatus.contains("No");
  bool get _isAbonado => paymentStatus.contains("Abonado") || paymentStatus.contains("abonado");
  Color get _paymentBgColor {
    if (_isPagado) return const Color(0xFFD4EDDA);
    if (_isAbonado) return const Color(0xFFFFECB3);
    return const Color(0xFFFFCDD2);
  }

  Color get _paymentTextColor {
    if (_isPagado) return const Color(0xFF1B5E20);
    if (_isAbonado) return const Color(0xFF7B5800);
    return const Color(0xFFB71C1C);
  }

  IconData get _paymentIcon {
    if (_isPagado) return Icons.check_circle_rounded;
    if (_isAbonado) return Icons.account_balance_wallet_rounded;
    return Icons.cancel_rounded;
  }

  String get _paymentLabel {
    if (_isPagado) return "Pagado";
    if (_isAbonado) return paymentStatus;
    return "Sin pagar";
  }

  Color _getCardColor() {
    final List<Color> pastelColors = [
      const Color(0xFFCDE8E0), const Color(0xFFFFD8C7), const Color(0xFFFDF0D5),
      const Color(0xFFE2D4F0), const Color(0xFFD4E2F0), const Color(0xFFFFD1DC),
      const Color(0xFFE2F0CB), const Color(0xFFFFE4E1), const Color(0xFFE6E6FA),
      const Color(0xFFD0F0C0),
    ];
    try {
      final day = int.parse(date.split('/')[0]);
      return pastelColors[(day - 1) % pastelColors.length];
    } catch (_) {
      return pastelColors[0];
    }
  }

  Widget _buildPipelineStatic() {
    const activeCol = Color(0xFFD98A7A);
    final inactiveCol = Colors.grey.shade300;
    final op2 = (productionStatus == "Listo" || productionStatus == "Entregado") ? 1.0 : 0.3;
    final op3 = productionStatus == "Entregado" ? 1.0 : 0.3;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Opacity(opacity: 1.0, child: Icon(Icons.receipt_long_outlined, size: 18, color: activeCol)),
        const SizedBox(width: 6),
        Icon(Icons.arrow_right_alt, size: 14, color: inactiveCol),
        const SizedBox(width: 6),
        Opacity(opacity: op2, child: const Icon(Icons.outdoor_grill_outlined, size: 18, color: activeCol)),
        const SizedBox(width: 6),
        Icon(Icons.arrow_right_alt, size: 14, color: inactiveCol),
        const SizedBox(width: 6),
        Opacity(opacity: op3, child: const Icon(Icons.local_shipping_outlined, size: 18, color: activeCol)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _getCardColor(),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fila superior: producto + precio + menú
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.cake_outlined, color: Colors.brown, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    product,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  "\$$price",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFD98A7A)),
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

            const SizedBox(height: 4),

            // Cliente + fecha
            Row(
              children: [
                const SizedBox(width: 26),
                Icon(Icons.person_outline, size: 13, color: Colors.grey.shade600),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(customer, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                ),
                Icon(Icons.calendar_today_outlined, size: 13, color: Colors.grey.shade600),
                const SizedBox(width: 3),
                Text(date, style: const TextStyle(fontSize: 12, color: Color(0xFFD98A7A), fontWeight: FontWeight.bold)),
              ],
            ),

            const Divider(height: 14, color: Colors.black12),

            // Fila inferior: badge de pago + pipeline
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _paymentBgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_paymentIcon, size: 12, color: _paymentTextColor),
                      const SizedBox(width: 4),
                      Text(
                        _paymentLabel,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _paymentTextColor),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                _buildPipelineStatic(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
