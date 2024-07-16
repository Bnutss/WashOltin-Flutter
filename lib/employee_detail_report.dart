import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'employee_report.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EmployeeDetailPage extends StatefulWidget {
  final EmployeeStats employeeStats;
  final DateTime selectedDate;

  const EmployeeDetailPage({Key? key, required this.employeeStats, required this.selectedDate}) : super(key: key);

  @override
  _EmployeeDetailPageState createState() => _EmployeeDetailPageState();
}

class _EmployeeDetailPageState extends State<EmployeeDetailPage> {
  late Future<List<WashOrder>> futureWashOrders;

  @override
  void initState() {
    super.initState();
    futureWashOrders = fetchWashOrders(widget.employeeStats.id, widget.selectedDate);
  }

  Future<List<WashOrder>> fetchWashOrders(int employeeId, DateTime selectedDate) async {
    final formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);
    final response = await http.get(Uri.parse('http://bnutss.pythonanywhere.com/api/employee/$employeeId/wash_orders/?date=$formattedDate'));

    if (response.statusCode == 200) {
      List jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      return jsonResponse.map((order) => WashOrder.fromJson(order)).toList();
    } else {
      throw Exception('Failed to load wash orders');
    }
  }

  String formatNumber(double number) {
    return NumberFormat("#,##0", "en_US").format(number).replaceAll(',', ' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Помытые машины', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueGrey[900],
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                futureWashOrders = fetchWashOrders(widget.employeeStats.id, widget.selectedDate);
              });
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<List<WashOrder>>(
          future: futureWashOrders,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Ошибка загрузки данных'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(child: Text('Нет данных'));
            } else {
              return ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final order = snapshot.data![index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                    elevation: 4.0,
                    child: ListTile(
                      title: Text(
                        '${index + 1}. ${order.typeOfCarWash}',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Цена: ${formatNumber(order.negotiatedPrice)} UZS'),
                          Text('Касса: ${formatNumber(order.companyShare)} UZS'),
                          Text('На руки: ${formatNumber(order.employeeShare)} UZS'),
                          Text('Фонд: ${formatNumber(order.fund)} UZS'),
                          Text('Дата: ${DateFormat('dd-MM-yyyy').format(order.orderDate)}'),
                        ],
                      ),
                      trailing: Icon(order.isCompleted ? Icons.check_circle : Icons.pending),
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

class WashOrder {
  final String carPhoto;
  final String typeOfCarWash;
  final double negotiatedPrice;
  final double fund;
  final double employeeShare;
  final double companyShare;
  final DateTime orderDate;
  final bool isCompleted;

  WashOrder({
    required this.carPhoto,
    required this.typeOfCarWash,
    required this.negotiatedPrice,
    required this.fund,
    required this.employeeShare,
    required this.companyShare,
    required this.orderDate,
    required this.isCompleted,
  });

  factory WashOrder.fromJson(Map<String, dynamic> json) {
    return WashOrder(
      carPhoto: json['car_photo'] ?? '',
      typeOfCarWash: json['type_of_car_wash']['name'] ?? '',
      negotiatedPrice: double.tryParse(json['negotiated_price'].toString()) ?? 0.0,
      fund: double.tryParse(json['fund'].toString()) ?? 0.0,
      employeeShare: double.tryParse(json['employee_share'].toString()) ?? 0.0,
      companyShare: double.tryParse(json['company_share'].toString()) ?? 0.0,
      orderDate: DateTime.parse(json['order_date']),
      isCompleted: json['is_completed'] ?? false,
    );
  }
}
