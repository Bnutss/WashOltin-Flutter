import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

class EmployeeDetailPage extends StatefulWidget {
  final int employeeId;

  EmployeeDetailPage({required this.employeeId});

  @override
  _EmployeeDetailPageState createState() => _EmployeeDetailPageState();
}

class _EmployeeDetailPageState extends State<EmployeeDetailPage> {
  late Future<Employee> _employeeDetail;

  @override
  void initState() {
    super.initState();
    _employeeDetail = fetchEmployeeDetail();
  }

  Future<Employee> fetchEmployeeDetail() async {
    final response = await http.get(Uri.parse('http://bnutss.pythonanywhere.com/employees/api/employee/${widget.employeeId}/'));

    if (response.statusCode == 200) {
      Map<String, dynamic> jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      print('Employee JSON Response: $jsonResponse');
      return Employee.fromJson(jsonResponse);
    } else {
      print('Failed to load employee details');
      throw Exception('Не удалось загрузить данные сотрудника');
    }
  }

  Future<void> fireEmployee(int employeeId) async {
    final response = await http.post(
      Uri.parse('http://bnutss.pythonanywhere.com/employees/api/employees/$employeeId/fire/'),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Сотрудник уволен'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true); // Возвращает пользователя на список сотрудников
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось уволить сотрудника'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String proxyUrl(String url) {
    return 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}';
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunch(launchUri.toString())) {
      await launch(launchUri.toString());
    } else {
      throw 'Could not launch $launchUri';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Детали сотрудника',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blueGrey[900],
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {
                _employeeDetail = fetchEmployeeDetail();
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<Employee>(
        future: _employeeDetail,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return Center(child: Text('Нет данных о сотруднике'));
          } else {
            var employee = snapshot.data!;
            print('Employee: ${employee.name}, Photo URL: ${employee.photoUrl}');
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 100,
                      backgroundImage: employee.photoUrl != null && employee.photoUrl!.isNotEmpty
                          ? CachedNetworkImageProvider(proxyUrl(employee.photoUrl!))
                          : AssetImage('assets/images/placeholder.png') as ImageProvider,
                    ),
                  ),
                  SizedBox(height: 24),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 5,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Имя', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text(employee.name, style: TextStyle(fontSize: 18)),
                          Divider(),
                          Text('Должность', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text(employee.positionName, style: TextStyle(fontSize: 18)),
                          Divider(),
                          Text('Возраст', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text(employee.age?.toString() ?? 'Не указан', style: TextStyle(fontSize: 18)),
                          Divider(),
                          Text('Телефон', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text(employee.phoneNumber ?? 'Не указан', style: TextStyle(fontSize: 18)),
                          Divider(),
                          Text('Адрес', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text(employee.address ?? 'Не указан', style: TextStyle(fontSize: 18)),
                          Divider(),
                          Text('Дата приёма на работу', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text(employee.hireDate ?? 'Не указана', style: TextStyle(fontSize: 18)),
                          Divider(),
                          Text('Дата увольнения', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text(employee.dateOfTermination ?? 'Не уволен', style: TextStyle(fontSize: 18)),
                          SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () {
                                  fireEmployee(employee.id);
                                },
                                icon: Icon(Icons.block),
                                label: Text('Уволить'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  if (employee.phoneNumber != null && employee.phoneNumber!.isNotEmpty) {
                                    _makePhoneCall(employee.phoneNumber!);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Номер телефона не указан')),
                                    );
                                  }
                                },
                                icon: Icon(Icons.phone),
                                label: Text('Позвонить'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}

class Employee {
  final int id;
  final String name;
  final String positionName;
  final int? age;
  final String? phoneNumber;
  final String? address;
  final String? hireDate;
  final String? dateOfTermination;
  final String? photoUrl;

  Employee({
    required this.id,
    required this.name,
    required this.positionName,
    this.age,
    this.phoneNumber,
    this.address,
    this.hireDate,
    this.dateOfTermination,
    this.photoUrl,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'],
      name: json['name_employees'] ?? '',
      positionName: json['position_name'] ?? '',
      age: json['age'],
      phoneNumber: json['phone_number'],
      address: json['address'],
      hireDate: json['hire_date'],
      dateOfTermination: json['date_of_termination'],
      photoUrl: json['photo_url'],
    );
  }
}
