import 'dart:convert';
import 'dart:typed_data';

import 'package:barcode_widget/barcode_widget.dart' as bw;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const appName = 'Cashier Lebanon Pro';
const packageName = 'com.cashier.lebanon.pro';
final money = NumberFormat('#,##0.##', 'en');

void main() => runApp(const ProviderScope(child: CashierApp()));

class Product {
  const Product({required this.id, required this.name, required this.price, this.barcode = '', this.category = '', this.stock = 0});
  final String id, name, barcode, category;
  final double price, stock;
  Product copyWith({String? name, String? barcode, String? category, double? price, double? stock}) => Product(id: id, name: name ?? this.name, price: price ?? this.price, barcode: barcode ?? this.barcode, category: category ?? this.category, stock: stock ?? this.stock);
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'price': price, 'barcode': barcode, 'category': category, 'stock': stock};
  factory Product.fromJson(Map<String, dynamic> j) => Product(id: '${j['id']}', name: '${j['name']}', price: (j['price'] as num).toDouble(), barcode: '${j['barcode'] ?? ''}', category: '${j['category'] ?? ''}', stock: (j['stock'] as num? ?? 0).toDouble());
}

class CartLine {
  const CartLine(this.product, this.quantity, this.price);
  final Product product;
  final double quantity, price;
  double get total => quantity * price;
  CartLine copyWith({double? quantity, double? price}) => CartLine(product, quantity ?? this.quantity, price ?? this.price);
  Map<String, dynamic> toJson() => {'product': product.toJson(), 'quantity': quantity, 'price': price};
  factory CartLine.fromJson(Map<String, dynamic> j) => CartLine(Product.fromJson(Map<String, dynamic>.from(j['product'])), (j['quantity'] as num).toDouble(), (j['price'] as num).toDouble());
}

class Sale {
  const Sale({required this.id, required this.date, required this.lines, required this.total, required this.usdPaid, required this.lbpPaid, required this.rate});
  final String id;
  final DateTime date;
  final List<CartLine> lines;
  final double total, usdPaid, lbpPaid, rate;
  Map<String, dynamic> toJson() => {'id': id, 'date': date.toIso8601String(), 'lines': lines.map((e) => e.toJson()).toList(), 'total': total, 'usdPaid': usdPaid, 'lbpPaid': lbpPaid, 'rate': rate};
  factory Sale.fromJson(Map<String, dynamic> j) => Sale(id: '${j['id']}', date: DateTime.parse(j['date']), lines: (j['lines'] as List).map((e) => CartLine.fromJson(Map<String, dynamic>.from(e))).toList(), total: (j['total'] as num).toDouble(), usdPaid: (j['usdPaid'] as num).toDouble(), lbpPaid: (j['lbpPaid'] as num).toDouble(), rate: (j['rate'] as num).toDouble());
}

class AppData {
  const AppData({this.products = const [], this.sales = const [], this.rate = 89500, this.dark = false});
  final List<Product> products;
  final List<Sale> sales;
  final double rate;
  final bool dark;
  AppData copyWith({List<Product>? products, List<Sale>? sales, double? rate, bool? dark}) => AppData(products: products ?? this.products, sales: sales ?? this.sales, rate: rate ?? this.rate, dark: dark ?? this.dark);
  Map<String, dynamic> toJson() => {'app': appName, 'version': 1, 'products': products.map((e) => e.toJson()).toList(), 'sales': sales.map((e) => e.toJson()).toList(), 'rate': rate, 'dark': dark};
  factory AppData.fromJson(Map<String, dynamic> j) => AppData(products: (j['products'] as List? ?? []).map((e) => Product.fromJson(Map<String, dynamic>.from(e))).toList(), sales: (j['sales'] as List? ?? []).map((e) => Sale.fromJson(Map<String, dynamic>.from(e))).toList(), rate: (j['rate'] as num? ?? 89500).toDouble(), dark: j['dark'] == true);
}

class DataController extends AsyncNotifier<AppData> {
  static const key = 'cashier_lebanon_pro_data';
  @override Future<AppData> build() async { final p = await SharedPreferences.getInstance(); final raw = p.getString(key); return raw == null ? const AppData() : AppData.fromJson(jsonDecode(raw)); }
  Future<void> save(AppData d) async { state = AsyncData(d); final p = await SharedPreferences.getInstance(); await p.setString(key, jsonEncode(d.toJson())); }
  Future<void> upsert(Product product) async { final d = state.value!; final list = [...d.products]; final i = list.indexWhere((e) => e.id == product.id); i < 0 ? list.add(product) : list[i] = product; await save(d.copyWith(products: list)); }
  Future<void> remove(String id) async { final d = state.value!; await save(d.copyWith(products: d.products.where((e) => e.id != id).toList())); }
  Future<void> complete(Sale sale) async { final d = state.value!; final products = d.products.map((p) { final line = sale.lines.where((e) => e.product.id == p.id).firstOrNull; return line == null ? p : p.copyWith(stock: p.stock - line.quantity); }).toList(); await save(d.copyWith(products: products, sales: [sale, ...d.sales])); }
  Future<void> importJson(Uint8List bytes) async { final decoded = jsonDecode(utf8.decode(bytes)); if (decoded['app'] != appName) throw const FormatException('ملف النسخة الاحتياطية غير صالح'); await save(AppData.fromJson(decoded)); }
}
final dataProvider = AsyncNotifierProvider<DataController, AppData>(DataController.new);

class CartController extends Notifier<List<CartLine>> {
  @override List<CartLine> build() => [];
  void add(Product p) { final i = state.indexWhere((e) => e.product.id == p.id); if (i < 0) state = [...state, CartLine(p, 1, p.price)]; else { final x = [...state]; x[i] = x[i].copyWith(quantity: x[i].quantity + 1); state = x; } }
  void update(int i, {double? quantity, double? price}) { final x = [...state]; x[i] = x[i].copyWith(quantity: quantity, price: price); state = x; }
  void remove(int i) { final x = [...state]..removeAt(i); state = x; }
  void clear() => state = [];
}
final cartProvider = NotifierProvider<CartController, List<CartLine>>(CartController.new);

final router = GoRouter(routes: [
  GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
  GoRoute(path: '/products', builder: (_, __) => const ProductsScreen()),
  GoRoute(path: '/inventory', builder: (_, __) => const InventoryScreen()),
  GoRoute(path: '/invoice', builder: (_, __) => const InvoiceScreen()),
  GoRoute(path: '/sales', builder: (_, __) => const SalesScreen()),
  GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
  GoRoute(path: '/backup', builder: (_, __) => const BackupScreen()),
  GoRoute(path: '/about', builder: (_, __) => const AboutScreen()),
]);

class CashierApp extends ConsumerWidget {
  const CashierApp({super.key});
  @override Widget build(BuildContext context, WidgetRef ref) { final dark = ref.watch(dataProvider).value?.dark ?? false; return MaterialApp.router(debugShowCheckedModeBanner: false, title: appName, locale: const Locale('ar'), supportedLocales: const [Locale('ar'), Locale('en')], localizationsDelegates: GlobalMaterialLocalizations.delegates, themeMode: dark ? ThemeMode.dark : ThemeMode.light, theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff006c4c)), useMaterial3: true, inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder())), darkTheme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff43d19e), brightness: Brightness.dark), useMaterial3: true, inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder())), routerConfig: router); }
}

class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key, required this.title, required this.body, this.actions}); final String title; final Widget body; final List<Widget>? actions;
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(title), actions: actions), body: SafeArea(child: body));
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override Widget build(BuildContext context, WidgetRef ref) { final d = ref.watch(dataProvider); return AppScaffold(title: appName, body: d.when(error: (e, _) => Center(child: Text('$e')), loading: () => const Center(child: CircularProgressIndicator()), data: (data) { final items = [('إنشاء فاتورة', Icons.point_of_sale, '/invoice'), ('المنتجات', Icons.inventory_2, '/products'), ('المخزون', Icons.warehouse, '/inventory'), ('سجل الفواتير', Icons.receipt_long, '/sales'), ('الإعدادات', Icons.settings, '/settings'), ('النسخ الاحتياطي', Icons.backup, '/backup'), ('حول التطبيق', Icons.info, '/about')]; return LayoutBuilder(builder: (_, c) => GridView.builder(padding: const EdgeInsets.all(16), gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: c.maxWidth > 900 ? 4 : c.maxWidth > 550 ? 3 : 2, childAspectRatio: 1.15, crossAxisSpacing: 12, mainAxisSpacing: 12), itemCount: items.length, itemBuilder: (_, i) => Card(child: InkWell(borderRadius: BorderRadius.circular(12), onTap: () => context.push(items[i].$3), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(items[i].$2, size: 42, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 12), Text(items[i].$1, style: Theme.of(context).textTheme.titleMedium)])))); }); })); }
}

class ProductsScreen extends ConsumerStatefulWidget { const ProductsScreen({super.key}); @override ConsumerState<ProductsScreen> createState() => _ProductsState(); }
class _ProductsState extends ConsumerState<ProductsScreen> { String query = '';
  @override Widget build(BuildContext context) { final products = ref.watch(dataProvider).value?.products ?? []; final shown = products.where((p) => p.name.toLowerCase().contains(query.toLowerCase()) || p.barcode.contains(query)).toList(); return AppScaffold(title: 'المنتجات', actions: [IconButton(tooltip: 'مسح باركود', onPressed: () => scanAndHandle(context, ref, editUnknown: true), icon: const Icon(Icons.qr_code_scanner))], body: Column(children: [Padding(padding: const EdgeInsets.all(12), child: TextField(onChanged: (v) => setState(() => query = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'بحث بالاسم أو الباركود'))), Expanded(child: shown.isEmpty ? const Center(child: Text('لا توجد منتجات')) : ListView.separated(itemCount: shown.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, i) { final p = shown[i]; return ListTile(leading: CircleAvatar(child: Text(p.name.characters.first)), title: Text(p.name), subtitle: Text('${money.format(p.price)} ل.ل  •  ${p.barcode.isEmpty ? 'بلا باركود' : p.barcode}'), trailing: PopupMenuButton(onSelected: (v) { if (v == 'edit') productDialog(context, ref, product: p); if (v == 'delete') confirmDelete(context, ref, p); }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('تعديل')), PopupMenuItem(value: 'delete', child: Text('حذف'))]); }; })), Padding(padding: const EdgeInsets.all(16), child: SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => productDialog(context, ref), icon: const Icon(Icons.add), label: const Text('إضافة منتج'))))])); }
}

Future<void> confirmDelete(BuildContext c, WidgetRef ref, Product p) async { final yes = await showDialog<bool>(context: c, builder: (_) => AlertDialog(title: const Text('حذف المنتج؟'), content: Text(p.name), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('حذف'))])) ?? false; if (yes) await ref.read(dataProvider.notifier).remove(p.id); }
Future<void> productDialog(BuildContext context, WidgetRef ref, {Product? product, String barcode = ''}) async { final name = TextEditingController(text: product?.name); final price = TextEditingController(text: product?.price.toString()); final code = TextEditingController(text: product?.barcode ?? barcode); final category = TextEditingController(text: product?.category); final stock = TextEditingController(text: product?.stock.toString() ?? '0'); final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: Text(product == null ? 'إضافة منتج' : 'تعديل المنتج'), content: SizedBox(width: 440, child: SingleChildScrollView(child: Column(children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم المنتج')), const SizedBox(height: 10), TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر بالليرة')), const SizedBox(height: 10), TextField(controller: code, decoration: const InputDecoration(labelText: 'الباركود')), const SizedBox(height: 10), TextField(controller: category, decoration: const InputDecoration(labelText: 'التصنيف (اختياري)')), const SizedBox(height: 10), TextField(controller: stock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية بالمخزون'))]))), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')), FilledButton(onPressed: () { if (name.text.trim().isNotEmpty && double.tryParse(price.text) != null) Navigator.pop(c, true); }, child: const Text('حفظ'))])); if (ok == true) await ref.read(dataProvider.notifier).upsert(Product(id: product?.id ?? const Uuid().v4(), name: name.text.trim(), price: double.parse(price.text), barcode: code.text.trim(), category: category.text.trim(), stock: double.tryParse(stock.text) ?? 0)); }

class InventoryScreen extends ConsumerWidget { const InventoryScreen({super.key}); @override Widget build(BuildContext context, WidgetRef ref) { final p = ref.watch(dataProvider).value?.products ?? []; return AppScaffold(title: 'المخزون', body: p.isEmpty ? const Center(child: Text('لا توجد منتجات')) : ListView.builder(itemCount: p.length, itemBuilder: (_, i) => ListTile(leading: Icon(p[i].stock <= 0 ? Icons.warning_amber : Icons.inventory), title: Text(p[i].name), subtitle: Text(p[i].category), trailing: Text(money.format(p[i].stock), style: Theme.of(context).textTheme.titleLarge))); } }

class InvoiceScreen extends ConsumerWidget { const InvoiceScreen({super.key}); @override Widget build(BuildContext context, WidgetRef ref) { final cart = ref.watch(cartProvider); final total = cart.fold<double>(0, (s, e) => s + e.total); return AppScaffold(title: 'فاتورة جديدة', actions: [IconButton(tooltip: 'مسح', onPressed: () => scanAndHandle(context, ref), icon: const Icon(Icons.qr_code_scanner)), IconButton(tooltip: 'إضافة منتج', onPressed: () => chooseProduct(context, ref), icon: const Icon(Icons.add))], body: Column(children: [Expanded(child: cart.isEmpty ? Center(child: FilledButton.icon(onPressed: () => chooseProduct(context, ref), icon: const Icon(Icons.add_shopping_cart), label: const Text('إضافة منتج'))) : ListView.builder(itemCount: cart.length, itemBuilder: (_, i) { final x = cart[i]; return Card(margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), child: ListTile(title: Text(x.product.name), subtitle: Text('${money.format(x.price)} × ${money.format(x.quantity)} = ${money.format(x.total)} ل.ل'), trailing: Wrap(children: [IconButton(onPressed: () => ref.read(cartProvider.notifier).update(i, quantity: x.quantity + 1), icon: const Icon(Icons.add_circle)), IconButton(onPressed: () => x.quantity > 1 ? ref.read(cartProvider.notifier).update(i, quantity: x.quantity - 1) : ref.read(cartProvider.notifier).remove(i), icon: const Icon(Icons.remove_circle)), IconButton(onPressed: () => editLine(context, ref, i, x), icon: const Icon(Icons.edit))])); })), Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest), child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('عدد المنتجات: ${money.format(cart.fold<double>(0, (s, e) => s + e.quantity))}'), Text('${money.format(total)} ل.ل', style: Theme.of(context).textTheme.headlineSmall)]), const SizedBox(height: 12), SizedBox(width: double.infinity, height: 54, child: FilledButton(onPressed: cart.isEmpty ? null : () => paymentDialog(context, ref, cart, total), child: const Text('إتمام الفاتورة')))]))])); } }

Future<void> chooseProduct(BuildContext c, WidgetRef ref) async { final products = ref.read(dataProvider).value?.products ?? []; String q = ''; await showDialog(context: c, builder: (d) => StatefulBuilder(builder: (_, set) { final shown = products.where((p) => p.name.contains(q) || p.barcode.contains(q)).toList(); return AlertDialog(title: const Text('إضافة منتج'), content: SizedBox(width: 500, height: 420, child: Column(children: [TextField(autofocus: true, onChanged: (v) => set(() => q = v), decoration: const InputDecoration(labelText: 'الاسم أو الباركود', prefixIcon: Icon(Icons.search))), Expanded(child: ListView.builder(itemCount: shown.length, itemBuilder: (_, i) => ListTile(title: Text(shown[i].name), subtitle: Text(money.format(shown[i].price)), onTap: () { ref.read(cartProvider.notifier).add(shown[i]); Navigator.pop(d); }))) ])), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('إغلاق'))]); })); }
Future<void> editLine(BuildContext c, WidgetRef ref, int i, CartLine x) async { final q = TextEditingController(text: '${x.quantity}'), p = TextEditingController(text: '${x.price}'); final ok = await showDialog<bool>(context: c, builder: (d) => AlertDialog(title: Text(x.product.name), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: q, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية')), const SizedBox(height: 10), TextField(controller: p, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر'))]), actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('تطبيق'))])); if (ok == true) ref.read(cartProvider.notifier).update(i, quantity: double.tryParse(q.text) ?? x.quantity, price: double.tryParse(p.text) ?? x.price); }

Future<void> paymentDialog(BuildContext context, WidgetRef ref, List<CartLine> cart, double total) async { final rate = ref.read(dataProvider).value!.rate; final usd = TextEditingController(text: '0'), lbp = TextEditingController(text: '0'); await showDialog(context: context, builder: (d) => StatefulBuilder(builder: (_, set) { final u = double.tryParse(usd.text) ?? 0, l = double.tryParse(lbp.text) ?? 0, paid = u * rate + l, balance = paid - total; return AlertDialog(title: const Text('الدفع'), content: SizedBox(width: 450, child: Column(mainAxisSize: MainAxisSize.min, children: [Text('الإجمالي: ${money.format(total)} ل.ل', style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 16), TextField(controller: usd, onChanged: (_) => set(() {}), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'بالدولار الأمريكي ($)')), const SizedBox(height: 10), TextField(controller: lbp, onChanged: (_) => set(() {}), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'بالليرة اللبنانية (ل.ل)')), const SizedBox(height: 16), Text('المدفوع: ${money.format(paid)} ل.ل'), Text(balance >= 0 ? 'الباقي: ${money.format(balance)} ل.ل' : 'المتبقي: ${money.format(-balance)} ل.ل', style: TextStyle(fontWeight: FontWeight.bold, color: balance >= 0 ? Colors.green : Colors.red))])), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('إلغاء')), FilledButton(onPressed: paid < total ? null : () async { final sale = Sale(id: const Uuid().v4(), date: DateTime.now(), lines: [...cart], total: total, usdPaid: u, lbpPaid: l, rate: rate); await ref.read(dataProvider.notifier).complete(sale); ref.read(cartProvider.notifier).clear(); if (d.mounted) Navigator.pop(d); if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الفاتورة بنجاح'))); context.pop(); } }, child: const Text('حفظ الفاتورة'))]); })); }

Future<void> scanAndHandle(BuildContext context, WidgetRef ref, {bool editUnknown = false}) async { final code = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const ScannerScreen())); if (code == null || !context.mounted) return; final products = ref.read(dataProvider).value!.products; final p = products.where((e) => e.barcode == code).firstOrNull; if (p != null) { if (editUnknown) { await productDialog(context, ref, product: p); } else { ref.read(cartProvider.notifier).add(p); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تمت إضافة ${p.name}'))); } } else { final yes = await showDialog<bool>(context: context, builder: (d) => AlertDialog(title: const Text('هذا المنتج غير محفوظ'), content: Text('الباركود: $code\nهل تريد إضافته؟'), actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('لا')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('إضافة'))])) ?? false; if (yes && context.mounted) await productDialog(context, ref, barcode: code); } }
class ScannerScreen extends StatefulWidget { const ScannerScreen({super.key}); @override State<ScannerScreen> createState() => _ScannerState(); }
class _ScannerState extends State<ScannerScreen> { bool done = false; @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('مسح الباركود')), body: MobileScanner(onDetect: (capture) { if (!done && capture.barcodes.firstOrNull?.rawValue != null) { done = true; Navigator.pop(context, capture.barcodes.first.rawValue); } }, overlayBuilder: (_, __) => Center(child: Container(width: 280, height: 160, decoration: BoxDecoration(border: Border.all(color: Colors.greenAccent, width: 3), borderRadius: BorderRadius.circular(16)))))); }

class SalesScreen extends ConsumerWidget { const SalesScreen({super.key}); @override Widget build(BuildContext context, WidgetRef ref) { final sales = ref.watch(dataProvider).value?.sales ?? []; return AppScaffold(title: 'سجل الفواتير', body: sales.isEmpty ? const Center(child: Text('لا توجد فواتير محفوظة')) : ListView.builder(itemCount: sales.length, itemBuilder: (_, i) { final s = sales[i]; return ListTile(leading: const CircleAvatar(child: Icon(Icons.receipt)), title: Text('${money.format(s.total)} ل.ل'), subtitle: Text('${DateFormat('yyyy/MM/dd  HH:mm').format(s.date)}  •  ${s.lines.length} منتجات'), onTap: () => showSale(context, s), trailing: IconButton(tooltip: 'طباعة PDF', onPressed: () => printSale(s), icon: const Icon(Icons.picture_as_pdf))); })); } }
Future<void> showSale(BuildContext c, Sale s) => showDialog(context: c, builder: (_) => AlertDialog(title: Text('فاتورة ${DateFormat('yyyy/MM/dd HH:mm').format(s.date)}'), content: SizedBox(width: 500, child: ListView(shrinkWrap: true, children: [...s.lines.map((x) => ListTile(title: Text(x.product.name), trailing: Text('${money.format(x.quantity)} × ${money.format(x.price)}'))), const Divider(), Text('الإجمالي: ${money.format(s.total)} ل.ل', style: Theme.of(c).textTheme.titleLarge)])), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('إغلاق')), FilledButton.icon(onPressed: () => printSale(s), icon: const Icon(Icons.print), label: const Text('طباعة'))]));
Future<void> printSale(Sale s) async { final doc = pw.Document(); doc.addPage(pw.Page(build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text(appName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)), pw.Text('Invoice ${DateFormat('yyyy-MM-dd HH:mm').format(s.date)}'), pw.Divider(), ...s.lines.map((x) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(x.product.name), pw.Text('${money.format(x.quantity)} x ${money.format(x.price)} = ${money.format(x.total)} LBP')])), pw.Divider(), pw.Text('TOTAL: ${money.format(s.total)} LBP', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)), pw.Spacer(), pw.Center(child: pw.Text(appName))])); await Printing.layoutPdf(onLayout: (_) => doc.save(), name: 'Cashier_Lebanon_Pro_${s.id}.pdf'); }

class SettingsScreen extends ConsumerWidget { const SettingsScreen({super.key}); @override Widget build(BuildContext context, WidgetRef ref) { final d = ref.watch(dataProvider).value!; final rate = TextEditingController(text: '${d.rate}'); return AppScaffold(title: 'الإعدادات', body: ListView(padding: const EdgeInsets.all(16), children: [TextField(controller: rate, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سعر صرف الدولار (ل.ل)')), const SizedBox(height: 12), FilledButton(onPressed: () async { final v = double.tryParse(rate.text); if (v != null && v > 0) { await ref.read(dataProvider.notifier).save(d.copyWith(rate: v)); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ سعر الصرف'))); } }, child: const Text('حفظ سعر الصرف')), SwitchListTile(title: const Text('الوضع الداكن'), value: d.dark, onChanged: (v) => ref.read(dataProvider.notifier).save(d.copyWith(dark: v))) ])); } }

class BackupScreen extends ConsumerWidget { const BackupScreen({super.key}); @override Widget build(BuildContext context, WidgetRef ref) => AppScaffold(title: 'النسخ الاحتياطي', body: ListView(padding: const EdgeInsets.all(16), children: [const Icon(Icons.cloud_off, size: 70), const Text('النسخ الاحتياطية تعمل محليًا بالكامل ولا تحتاج إلى الإنترنت.', textAlign: TextAlign.center), const SizedBox(height: 24), FilledButton.icon(onPressed: () async { final bytes = Uint8List.fromList(utf8.encode(jsonEncode(ref.read(dataProvider).value!.toJson()))); await FilePicker.platform.saveFile(dialogTitle: 'تصدير نسخة احتياطية', fileName: 'Cashier_Lebanon_Pro_backup.json', bytes: bytes); }, icon: const Icon(Icons.download), label: const Text('تصدير قاعدة البيانات')), const SizedBox(height: 12), OutlinedButton.icon(onPressed: () async { try { final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'], withData: true); if (picked?.files.single.bytes != null) { await ref.read(dataProvider.notifier).importJson(picked!.files.single.bytes!); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم استيراد النسخة بنجاح'))); } } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); } }, icon: const Icon(Icons.upload), label: const Text('استيراد قاعدة البيانات')) ])); }

class AboutScreen extends StatelessWidget { const AboutScreen({super.key}); @override Widget build(BuildContext context) => AppScaffold(title: 'حول التطبيق', body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.point_of_sale, size: 90, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 20), Text(appName, style: Theme.of(context).textTheme.headlineMedium), const SizedBox(height: 8), const SelectableText(packageName), const Text('الإصدار 1.0.0'), const SizedBox(height: 32), const Text('© All Rights Reserved - Cashier Lebanon Pro', textAlign: TextAlign.center)])))); }
