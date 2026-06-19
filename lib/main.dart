import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/dashboard_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/compras_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/login_screen.dart';

import 'firebase_options_dev.dart' as dev;
import 'firebase_options_prod.dart' as prod;

// Cambia a 'false' SOLO cuando vayas a lanzar la app real a tus clientes.
const bool isDevMode = true; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // La app decide a qué base de datos conectarse según el interruptor
  await Firebase.initializeApp(
    options: isDevMode 
        ? dev.DefaultFirebaseOptions.currentPlatform 
        : prod.DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const BakerApp());
}

class BakerApp extends StatelessWidget {
  const BakerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DolceCatapp',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'), // Español
        Locale('en', 'US'), // Inglés (fallback)
      ],
      locale: const Locale('es', 'ES'), // Forzamos el uso de español
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFDE9E0)),
        scaffoldBackgroundColor: const Color(0xFFFFF5F0),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // 1. Si está comprobando la llave digital, mostramos una carga rápida
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFFD98A7A)),
              ),
            );
          }
          // 2. Si el usuario tiene una sesión activa válida, entra directo a tu menú
          if (snapshot.hasData) {
            return const MyHomePage();
          }
          // 3. Si no hay sesión o la cerraron, mostramos el Login
          return const LoginScreen();
        },
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  @override
  void initState() {
    super.initState();
    _inicializarDatosGlobales();
  }

  void _inicializarDatosGlobales() {
    if (globalOrders.isEmpty) {
      globalOrders.addAll([
        OrderData(
          id: '1', product: "Torta Red Velvet", customer: "Carolina Soto", 
          date: "26/05/2026", price: 35000, amountPaid: 15000, 
          paymentStatus: "Monto abonado", productionStatus: "Tomado", notas: "Feliz Cumpleaños"
        ),
        OrderData(
          id: '2', product: "12 Alfajores Maicena", customer: "Pedro Vargas", 
          date: "28/05/2026", price: 12000, amountPaid: 0, 
          paymentStatus: "No pagado", productionStatus: "Listo", notas: "Bordes con coco"
        ),
        OrderData(
          id: '3', product: "Cheesecake Frambuesa", customer: "María Ignacia", 
          date: "27/05/2026", price: 22000, amountPaid: 22000, 
          paymentStatus: "Pagado", productionStatus: "Tomado", notas: "Sin azúcar"
        ),
      ]);
    }
  }

  List<Widget> get _paginas => [
    const DashboardScreen(), // Index 0
    const OrdersScreen(),    // Index 1
    const ComprasScreen(),   // Index 2
    const ReportsScreen(),   // Index 3
  ];

  @override
  Widget build(BuildContext context) {
    // 1. Escucha cambios en los datos (precios, estados, etc)
    return ValueListenableBuilder<int>(
      valueListenable: appDataNotifier,
      builder: (context, dataVal, child) {
        
        // 2. Escucha cambios en la pestaña actual (para que el calendario pueda cambiarla)
        return ValueListenableBuilder<int>(
          valueListenable: appTabIndex,
          builder: (context, tabIndex, child) {
            return Scaffold(
              body: SafeArea(
                child: IndexedStack(
                  index: tabIndex,
                  children: _paginas,
                ),
              ),
              bottomNavigationBar: BottomNavigationBar(
                currentIndex: tabIndex,
                onTap: (index) => appTabIndex.value = index, // Actualiza la pestaña global
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.white,
                selectedItemColor: const Color(0xFFD98A7A),
                unselectedItemColor: Colors.grey[700],
                selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                unselectedLabelStyle: const TextStyle(fontSize: 11),
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Resumen'),
                  BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), activeIcon: Icon(Icons.receipt_long), label: 'Pedidos'),
                  BottomNavigationBarItem(icon: Icon(Icons.shopping_cart_outlined), activeIcon: Icon(Icons.shopping_cart), label: 'Compras'),
                  BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), activeIcon: Icon(Icons.bar_chart), label: 'Reportes'),
                ],
              ),
            );
          },
        );
      },
    );
  }
}