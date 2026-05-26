import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
// IMPORTANTE: Importar orders_screen para acceder a la lista global y los notifiers
import '../screens/orders_screen.dart';

// Variable global para que el calendario recuerde en qué mes lo dejaste sin importar la pestaña
DateTime globalFocusedDay = DateTime.now();

class CustomHeader extends StatefulWidget {
  final String title;
  final VoidCallback? onCalendarTap; // Opcional: lo dejamos para no romper el código de tus otras pantallas

  const CustomHeader({
    super.key, 
    this.title = "DolceCatapp",
    this.onCalendarTap,
  });

  @override
  State<CustomHeader> createState() => _CustomHeaderState();
}

class _CustomHeaderState extends State<CustomHeader> {
  final Color mainColor = const Color(0xFFD98A7A);

  // --- LÓGICA DEL CALENDARIO CENTRALIZADA ---
  List<OrderData> _getOrdersForDay(DateTime day) {
    return globalOrders.where((order) {
      return order.dateTime.year == day.year &&
             order.dateTime.month == day.month &&
             order.dateTime.day == day.day;
    }).toList();
  }

  void _showUniversalCalendar() {
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
                      locale: 'es_ES',
                      startingDayOfWeek: StartingDayOfWeek.monday,
                      firstDay: DateTime.utc(2024, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: globalFocusedDay,
                      eventLoader: _getOrdersForDay, 
                      
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                      ),

                      onHeaderTapped: (focusedDay) async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: globalFocusedDay,
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
                          setDialogState(() => globalFocusedDay = picked);
                          setState(() => globalFocusedDay = picked);
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
                        setDialogState(() => globalFocusedDay = focusedDay);
                        setState(() => globalFocusedDay = focusedDay);
                      },
                      
                      onDaySelected: (selectedDay, focusedDay) {
                        setDialogState(() => globalFocusedDay = focusedDay);
                        setState(() => globalFocusedDay = focusedDay);
                        
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

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(widget.title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: mainColor)),
        Row(
          children: [
            Icon(Icons.person_outline, color: mainColor, size: 28),
            const SizedBox(width: 15),
            Icon(Icons.notifications_none, color: mainColor, size: 28),
            const SizedBox(width: 15),
            GestureDetector(
              onTap: _showUniversalCalendar, // <- AHORA EL HEADER LLAMA A SU PROPIO CALENDARIO
              child: Icon(Icons.calendar_today_outlined, color: mainColor, size: 26),
            ),
          ],
        )
      ],
    );
  }
}