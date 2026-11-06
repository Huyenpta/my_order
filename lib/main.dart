import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_saver/file_saver.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'order.dart';

void main() => runApp(const MyApp());

const accent = Color(0xFFCC6B52);
const canvasColor = Color(0xFFF8F5F2);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'My Order',
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: canvasColor,
          colorScheme: ColorScheme.fromSeed(seedColor: accent),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
        home: const OrderPage(),
      );
}

class OrderPage extends StatefulWidget {
  const OrderPage({super.key});
  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  List<Order> orders = [];
  String searchText = '';
  bool loading = true;
  final itemController = TextEditingController();
  final nameController = TextEditingController();
  final priceController = TextEditingController();
  final quantityController = TextEditingController();
  final currencyController = TextEditingController(text: 'USD');
  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadOrders();
  }

  Future<void> loadOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedData = prefs.getString('saved_orders');
      final source = savedData ?? await rootBundle.loadString('assets/order.json');
      final decoded = jsonDecode(source) as List<dynamic>;
      if (!mounted) return;
      setState(() {
        orders = decoded.map((e) => Order.fromJson(e)).toList();
        loading = false;
      });
    } catch (e) {
      debugPrint('Error loading orders: $e');
      if (mounted) {
        setState(() => loading = false);
        showMessage('Cannot load orders: $e');
      }
    }
  }

  Future<void> saveOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(orders.map((o) => o.toJson()).toList());
      final ok = await prefs.setString('saved_orders', data);
      if (!ok && mounted) showMessage('Could not save orders locally');
    } catch (e) {
      if (mounted) showMessage('Save failed: $e');
    }
  }

  Future<void> saveOrdersToJson() async {
    try {
      final content = const JsonEncoder.withIndent('  ')
          .convert(orders.map((o) => o.toJson()).toList());
      await FileSaver.instance.saveFile(
        name: 'order',
        bytes: Uint8List.fromList(utf8.encode(content)),
        fileExtension: 'json',
        mimeType: MimeType.json,
      );
      if (mounted) showMessage('order.json exported successfully');
    } catch (e) {
      if (mounted) showMessage('Export failed: $e');
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void addOrder() {
    final price = double.tryParse(priceController.text.trim());
    final quantity = int.tryParse(quantityController.text.trim());
    if (itemController.text.trim().isEmpty ||
        nameController.text.trim().isEmpty ||
        price == null || !price.isFinite || price < 0 ||
        quantity == null || quantity <= 0) {
      showMessage('Please enter valid information');
      return;
    }
    setState(() {
      orders.add(Order(
        item: itemController.text.trim(),
        itemName: nameController.text.trim(),
        price: price,
        quantity: quantity,
        currency: currencyController.text.trim().isEmpty
            ? 'USD' : currencyController.text.trim(),
      ));
    });
    saveOrders();
    itemController.clear();
    nameController.clear();
    priceController.clear();
    quantityController.clear();
    showMessage('Order added successfully');
  }

  void deleteOrder(Order order) {
    setState(() => orders.remove(order));
    saveOrders();
    showMessage('Order deleted');
  }

  Widget inputField(String label, TextEditingController controller,
      {double width = 210, TextInputType? keyboardType}) => SizedBox(
        width: width,
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(labelText: label),
        ),
      );

  Widget panel({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEDE5DF)),
          boxShadow: const [BoxShadow(color: Color(0x0B000000), blurRadius: 16, offset: Offset(0, 4))],
        ),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final filteredOrders = orders.where((o) =>
        o.itemName.toLowerCase().contains(searchText.trim().toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.shopping_bag_outlined), SizedBox(width: 10), Text('My Order'),
        ]),
        backgroundColor: accent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Order Management', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Color(0xFF3F3530))),
              const SizedBox(height: 5),
              const Text('Manage, search and export your orders', style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 24),
              panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Add New Order', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                Wrap(spacing: 12, runSpacing: 14, children: [
                  inputField('Item', itemController),
                  inputField('Item Name', nameController, width: 255),
                  inputField('Price', priceController, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                  inputField('Quantity', quantityController, keyboardType: TextInputType.number),
                  inputField('Currency', currencyController),
                ]),
                const SizedBox(height: 22),
                Wrap(spacing: 12, runSpacing: 10, children: [
                  FilledButton.icon(
                    onPressed: addOrder,
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Add Item to Cart'),
                    style: FilledButton.styleFrom(backgroundColor: accent, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16)),
                  ),
                  OutlinedButton.icon(
                    onPressed: saveOrdersToJson,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Save order.json'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16)),
                  ),
                ]),
              ])),
              const SizedBox(height: 22),
              panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Expanded(child: Text('Order List', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
                  Text('${filteredOrders.length} orders', style: const TextStyle(color: accent, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 16),
                TextField(
                  controller: searchController,
                  onChanged: (value) => setState(() => searchText = value),
                  decoration: InputDecoration(
                    labelText: 'Search by Item Name',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchText.isEmpty ? null : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () { searchController.clear(); setState(() => searchText = ''); },
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                if (loading) const Center(child: CircularProgressIndicator())
                else if (filteredOrders.isEmpty)
                  const Padding(padding: EdgeInsets.all(28), child: Center(child: Text('No orders found')))
                else SizedBox(width: double.infinity, child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF4E2DA)),
                    dataRowMinHeight: 54,
                    dataRowMaxHeight: 62,
                    columns: const [
                      DataColumn(label: Text('Id')),
                      DataColumn(label: Text('Item')),
                      DataColumn(label: Text('Item Name')),
                      DataColumn(label: Text('Quantity')),
                      DataColumn(label: Text('Price')),
                      DataColumn(label: Text('Currency')),
                      DataColumn(label: Text('Action')),
                    ],
                    rows: filteredOrders.map((order) {
                      final originalIndex = orders.indexOf(order) + 1;
                      return DataRow(cells: [
                        DataCell(Text('$originalIndex')),
                        DataCell(Text(order.item)),
                        DataCell(Text(order.itemName)),
                        DataCell(Text('${order.quantity}')),
                        DataCell(Text('${order.price}')),
                        DataCell(Text(order.currency)),
                        DataCell(IconButton(
                          tooltip: 'Delete order',
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => deleteOrder(order),
                        )),
                      ]);
                    }).toList(),
                  ),
                )),
              ])),
              const SizedBox(height: 22),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(12)),
                child: const Text('So 8, Ton That Thuyet, Cau Giay, Ha Noi', style: TextStyle(color: Colors.white)),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    itemController.dispose();
    nameController.dispose();
    priceController.dispose();
    quantityController.dispose();
    currencyController.dispose();
    searchController.dispose();
    super.dispose();
  }
}
