import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'detail_washed_cars_page.dart';

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

  @override
  void initState() {
    super.initState();
    _initializeFuture();
    _searchController.addListener(_onSearchChanged);
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

  Future<List<WashedCar>> fetchWashedCars() async {
    final queryParameters = {
      if (selectedDate != null)
        'order_date': DateFormat('yyyy-MM-dd').format(selectedDate!),
    };

    final uri = Uri.http(
      'bnutss.pythonanywhere.com',
      '/api/wash-orders/',
      queryParameters,
    );

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
    final uri = Uri.http('bnutss.pythonanywhere.com', '/api/wash-orders/$id/');

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

  Future<void> _confirmDelete(int id) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // пользователь должен подтвердить или отменить
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
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Удалить'),
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteCar(id);
              },
            ),
          ],
        );
      },
    );
  }

  String proxyUrl(String url) {
    return 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}';
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
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _initializeFuture,
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
      body: Center(
        child: FutureBuilder<List<WashedCar>>(
          future: futureWashedCars,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return CircularProgressIndicator();
            } else if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Text('Нет помытых машин');
            } else {
              return ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  var car = snapshot.data![index];
                  final formatter = NumberFormat("#,###", "ru_RU");
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                    elevation: 4.0,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.transparent,
                        child: ClipOval(
                          child: car.carPhoto != null && car.carPhoto!.isNotEmpty
                              ? CachedNetworkImage(
                            imageUrl: proxyUrl(car.carPhoto!),
                            placeholder: (context, url) => CircularProgressIndicator(),
                            errorWidget: (context, url, error) => Icon(Icons.error),
                            fit: BoxFit.cover,
                            width: 40,
                            height: 40,
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
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.visibility, color: Colors.blueGrey[900]),
                            onPressed: () => _viewDetails(car),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              await _confirmDelete(car.id);
                            },
                          ),
                        ],
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
