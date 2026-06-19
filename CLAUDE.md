# CLAUDE.md — DolceCatapp (Registros Repostería)

App Flutter para gestión de una tienda de repostería. Administra pedidos, inventario, gastos y reportes financieros.

## Stack Tecnológico

| Capa | Tecnología |
|------|-----------|
| Framework | Flutter (Dart) — Android, iOS, Web |
| Base de datos | Cloud Firestore (Firebase) |
| Almacenamiento de archivos | Firebase Storage |
| Autenticación | Firebase Auth (email/password) |
| Hosting web | Firebase Hosting (`build/web`) |
| State management | `ValueNotifier` + listas globales (sin Provider/Riverpod/Bloc) |
| Flutter SDK | ^3.11.5 |
| Versión app | 1.0.0+1 |

## Estructura de Archivos

```
lib/
├── main.dart                   # Entry point, Firebase init, auth gate, bottom nav
├── firebase_options_dev.dart   # Config Firebase proyecto dolcecatapp-dev
├── firebase_options_prod.dart  # Config Firebase proyecto dolcecatapp
├── screens/
│   ├── login_screen.dart       # Auth con Firebase email/password
│   ├── dashboard_screen.dart   # Resumen: pedidos próximos, balance, inventario
│   ├── orders_screen.dart      # CRUD pedidos + definición de globalOrders y appDataNotifier
│   ├── inventory_screen.dart   # Inventario (local) + lista de compras (Firestore)
│   └── reports_screen.dart     # Gastos + utilidad mensual
└── widgets/
    ├── custom_header.dart      # Header con calendario y búsqueda global
    ├── order_card.dart         # Tarjeta de pedido
    └── order_form_modal.dart   # Modal crear/editar pedido + subida de imágenes
```

## Ambientes Dev/Prod

```dart
// lib/main.dart — línea ~16
const bool isDevMode = false;  // false = producción, true = dev
```
- Dev: `dolcecatapp-dev` (Firebase project)
- Prod: `dolcecatapp` (Firebase project)
- Las credentials están en `firebase_options_dev.dart` / `firebase_options_prod.dart`. En Flutter las API keys de Firebase van en el cliente por diseño — la seguridad se gestiona con Firestore Security Rules, no con secrecía de la clave.

## Colecciones Firestore

| Colección | Modelo | Observaciones |
|-----------|--------|--------------|
| `pedidos` | `OrderData` | Pedidos completos con fotos |
| `gastos` | `ExpenseData` | Gastos categorizados por mes |
| `compras` | `ChecklistItem` | Lista de compras pendientes |

> **El inventario de insumos (`globalInventory`) NO persiste en Firebase** — es solo estado en memoria, se reinicia al cerrar la app. Esto es intencional en la versión actual.

## Modelos de Datos

### OrderData (`screens/orders_screen.dart`)
```dart
String id             // Firestore doc ID
String product        // Nombre del producto/pastel
String customer       // Nombre del cliente
String date           // "DD/MM/YYYY" — tiene getter dateTime para comparaciones
int price             // Precio total en CLP
int amountPaid        // Solo si paymentStatus == "Monto abonado"
String paymentStatus  // "No pagado" | "Monto abonado" | "Pagado"
String productionStatus // "Tomado" | "Listo" | "Entregado"
String notas
List<dynamic> imagenesRef  // URLs de Storage o Uint8List en memoria
```

### InventoryItem (`screens/inventory_screen.dart`)
```dart
String id, name, category  // category: "Secos"|"Refrigerados"|"Decoración"|"Empaque"
int quantity, minThreshold, lastPrice
String unit  // "un"|"kg"|"gr"|"lt"|"ml"
```
Stock: **Crítico** (0), **Alerta** (1–minThreshold), **Hay stock** (>minThreshold).

### ExpenseData (`screens/reports_screen.dart`)
```dart
String id, description
int amount             // CLP
DateTime date
String category        // "Insumos"|"Empaque"|"Gastos Fijos"|"Otros"
DateTime? createdAt
```

### ChecklistItem (`screens/inventory_screen.dart`)
```dart
String id, name
bool isDone
```

## Estado Global

Variables globales definidas en los archivos de screen y usadas desde toda la app:

```dart
// orders_screen.dart
List<OrderData> globalOrders = [];
ValueNotifier<int> appDataNotifier = ValueNotifier(0); // event bus — incrementar = rebuild
ValueNotifier<int> appTabIndex = ValueNotifier(0);
ValueNotifier<String> globalSearchNotifier = ValueNotifier("");
bool isDataLoaded = false;

// inventory_screen.dart
List<InventoryItem> globalInventory = [];       // solo memoria
List<ChecklistItem> globalChecklist = [];
Set<String> globalSelectedStatuses = {};
ValueNotifier<int> inventoryTabNotifier = ValueNotifier(0);

// reports_screen.dart
List<ExpenseData> globalExpenses = [];

// custom_header.dart
DateTime globalFocusedDay = DateTime.now();
```

**Patrón de actualización:** cualquier write a Firebase llama `appDataNotifier.value++`. Las pantallas usan `ValueListenableBuilder<int>(valueListenable: appDataNotifier, ...)` para reaccionar.

## Sincronización Firebase (StreamSubscription)

Cada pantalla abre un listener en `initState` y lo cancela en `dispose()`:

| Método | Colección | Actualiza |
|--------|-----------|-----------|
| `_escucharPedidos()` | `pedidos` | `globalOrders` |
| `_escucharChecklist()` | `compras` | `globalChecklist` |
| `_escucharGastos()` | `gastos` | `globalExpenses` |

**No hay persistencia offline** ni manejo de errores de conectividad.

## Flujos de Negocio

### Estado de un Pedido
```
productionStatus: "Tomado" → "Listo" → "Entregado"  (requiere confirmación)
paymentStatus:   "No pagado" → "Monto abonado" → "Pagado"
```
Solo orders con "Pagado" o "Monto abonado" cuentan en ventas del mes.

### Cálculo Mensual
```
Balance = Σ(price de pedidos pagados/abonados del mes) − Σ(gastos del mes)
```

### Imágenes de Pedidos
- Se suben a Firebase Storage: `pedidos/{timestamp}.jpg`
- El campo `imagenesRef` guarda URLs (después de subir) o `Uint8List` (antes de subir — inconsistencia conocida)

## Convenciones de Código

- Archivos: `*_screen.dart` para screens, nombre descriptivo para widgets
- Clases: `PascalCase`, screens con sufijo `Screen`
- Variables privadas: `_camelCase`
- Controladores de texto: `_*Ctrl` o `_*Controller`
- Globales: prefijo `app*` o `global*`
- Moneda: enteros CLP, formato visual "10.000" con `ThousandSeparatorInputFormatter`
- Comentarios: escasos, código en español e inglés mezclados

## Deuda Técnica Vigente

1. **Estado global acoplado a screens** — `globalOrders`, `appDataNotifier`, etc. están declarados en `orders_screen.dart` y se importan desde otras pantallas. Sin capa de servicios ni repositorios.
2. **`imagenesRef: List<dynamic>`** — mezcla URLs (String) y bytes (Uint8List) en el mismo campo. Puede causar bugs silenciosos.
3. **Sin manejo de errores offline** — si falla Firebase la app muestra vacío sin avisar al usuario.
4. **Clientes sin implementar** — tab marcado "en construcción". Los clientes solo existen como string en cada pedido.
5. **Sin tests** — no hay unit, widget ni integration tests.
6. **Gastos con datos de ejemplo hardcodeados** — `globalExpenses` en `reports_screen.dart` inicia con 3 gastos de ejemplo que se sobreescriben al cargar Firebase.

## Despliegue Web

```bash
flutter build web
firebase use dolcecatapp        # o dolcecatapp-dev para dev
firebase deploy --only hosting
```
