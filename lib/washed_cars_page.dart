import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'detail_washed_cars_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Washed Cars',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: WashedCarsPage(),
    );
  }
}

class WashedCarsPage extends StatefulWidget {
  const WashedCarsPage({Key? key}) : super(key: key);

  @override
  _WashedCarsPageState createState() => _WashedCarsPageState();
}

class _WashedCarsPageState extends State<WashedCarsPage> {
  late Future<List<WashedCar>> futureWashedCars;
  TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  DateTime? selectedDate = DateTime.now();
  int washedCarCount = 0;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _initializeFuture();
    _searchController.addListener(_onSearchChanged);
    _loadPrefs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _initializeFuture() {
    setState(() {
      futureWashedCars = fetchWashedCars();
    });
  }

  Future<void> _loadPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    final savedDate = _prefs?.getString('selectedDate');
    if (savedDate != null) {
      setState(() {
        selectedDate = DateTime.parse(savedDate);
      });
    }
  }

  Future<List<WashedCar>> fetchWashedCars() async {
    final queryParameters = {
      if (selectedDate != null)
        'order_date': DateFormat('yyyy-MM-dd').format(selectedDate!),
    };

    final uri = Uri.parse('https://oltinwash.pythonanywhere.com/api/wash-orders/').replace(queryParameters: queryParameters);

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      List jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      List<WashedCar> washedCars = jsonResponse.map((car) => WashedCar.fromJson(car)).toList();

      washedCars = washedCars.where((car) => car.orderDate != null && DateFormat('yyyy-MM-dd').format(DateTime.parse(car.orderDate!)) == DateFormat('yyyy-MM-dd').format(selectedDate!)).toList();

      if (searchQuery.isNotEmpty) {
        washedCars = washedCars.where((car) => car.washerName.toLowerCase().contains(searchQuery.toLowerCase())).toList();
      }

      setState(() {
        washedCarCount = washedCars.length;
      });

      return washedCars;
    } else {
      print('Failed to load washed cars');
      throw Exception('Не удалось загрузить помытые машины');
    }
  }

  void _onSearchChanged() {
    setState(() {
      searchQuery = _searchController.text;
      futureWashedCars = fetchWashedCars();
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null && pickedDate != selectedDate) {
      setState(() {
        selectedDate = pickedDate;
        _prefs?.setString('selectedDate', pickedDate.toIso8601String());
        futureWashedCars = fetchWashedCars();
      });
    }
  }

  void _viewDetails(WashedCar car) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DetailWashedCarsPage(car: car)),
    );
  }

  Future<void> _deleteCar(int id) async {
    final uri = Uri.parse('https://oltinwash.pythonanywhere.com/api/wash-orders/$id/');

    final response = await http.delete(uri);

    if (response.statusCode == 204) {
      setState(() {
        futureWashedCars = fetchWashedCars();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Мойка успешно удалена'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      print('Failed to delete the car');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при удалении мойки'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> _confirmDelete(int id) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Подтверждение удаления'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Вы точно хотите удалить мойку?'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Отмена'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: Text('Удалить'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    return confirm ?? false;
  }

  Future<void> _refreshData() async {
    setState(() {
      futureWashedCars = fetchWashedCars();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Список помытых машин', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueGrey[900],
        actions: [
          Row(
            children: [
              Icon(Icons.directions_car, color: Colors.white),
              SizedBox(width: 4.0),
              Text(
                '$washedCarCount',
                style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              SizedBox(width: 16.0),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(56.0),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Поиск по имени мойщика...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.calendar_today, color: Colors.white),
                  onPressed: () => _selectDate(context),
                ),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: FutureBuilder<List<WashedCar>>(
          future: futureWashedCars,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(child: Text('Нет помытых машин'));
            } else {
              return ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  var car = snapshot.data![index];
                  final formatter = NumberFormat("#,###", "ru_RU");
                  return Dismissible(
                    key: Key(car.id.toString()),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: EdgeInsets.only(right: 20.0),
                      child: Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (direction) async {
                      return await _confirmDelete(car.id);
                    },
                    onDismissed: (direction) async {
                      await _deleteCar(car.id);
                    },
                    child: Card(
                      margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                      elevation: 4.0,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.transparent,
                          child: ClipOval(
                            child: car.carPhoto != null && car.carPhoto!.isNotEmpty
                                ? Image.network(
                              car.carPhoto!,
                              fit: BoxFit.cover,
                              width: 40,
                              height: 40,
                              loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                );
                              },
                              errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
                                return Icon(Icons.error);
                              },
                            )
                                : Image.asset('assets/images/placeholder.png', fit: BoxFit.cover, width: 40, height: 40),
                          ),
                        ),
                        title: Text(car.washerName, style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Цена: ${formatter.format(car.washPrice)} UZS'),
                            Text('Дата: ${car.getFormattedOrderDate()}'),
                            Text('Вид мойки: ${car.washType}'),
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.visibility, color: Colors.blueGrey[900]),
                          onPressed: () => _viewDetails(car),
                        ),
                      ),
                    ),
                  );
                },
              );
            }
          },
        ),
      ),
    );
  }
}

class WashedCar {
  final int id;
  final String? carPhoto;
  final String washerName;
  final double washPrice;
  final String? orderDate;
  final String washType;

  WashedCar({
    required this.id,
    this.carPhoto,
    required this.washerName,
    required this.washPrice,
    this.orderDate,
    required this.washType,
  });

  factory WashedCar.fromJson(Map<String, dynamic> json) {
    double washPrice = 0.0;
    if (json['negotiated_price'] != null) {
      washPrice = double.tryParse(json['negotiated_price'].toString()) ?? 0.0;
    } else if (json['type_of_car_wash'] != null && json['type_of_car_wash']['price'] != null) {
      washPrice = double.tryParse(json['type_of_car_wash']['price'].toString()) ?? 0.0;
    }

    return WashedCar(
      id: json['id'],
      carPhoto: json['car_photo'],
      washerName: json['employees'] != null ? json['employees']['name_employees'] : 'Неизвестно',
      washPrice: washPrice,
      orderDate: json['order_date'],
      washType: json['type_of_car_wash'] != null ? json['type_of_car_wash']['name'] : 'Неизвестно',
    );
  }

  String getFormattedOrderDate() {
    if (orderDate == null) return 'Неизвестно';
    final parsedDate = DateTime.parse(orderDate!);
    return DateFormat('dd.MM.yyyy').format(parsedDate);
  }
}