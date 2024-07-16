import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'employee_detail_report.dart';

class EmployeeReportPage extends StatefulWidget {
  const EmployeeReportPage({Key? key}) : super(key: key);

  @override
  _EmployeeReportPageState createState() => _EmployeeReportPageState();
}

class _EmployeeReportPageState extends State<EmployeeReportPage> {
  List<EmployeeStats> _employeeStats = [];
  String _message = '';
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  DateTime _selectedDate = DateTime.now();
  Future<void>? _initialLoad;
  final String baseUrl = 'http://bnutss.pythonanywhere.com';

  @override
  void initState() {
    super.initState();
    _initialLoad = _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _loadData() async {
    try {
      final data = await fetchEmployeeStats();
      if (mounted) {
        setState(() {
          _employeeStats = data;
          _message = '';
          if (_employeeStats.isEmpty) {
            _message = 'На выбранную дату нет данных';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = 'Ошибка: $e';
        });
      }
    }
  }

  Future<List<EmployeeStats>> fetchEmployeeStats() async {
    final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final response = await http.get(Uri.parse('$baseUrl/api/employee-stats/?date=$formattedDate'));

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      if (data is Map && data.containsKey('message')) {
        if (mounted) {
          setState(() {
            _message = data['message'];
          });
        }
        return [];
      } else {
        List<dynamic> jsonList = data;
        List<EmployeeStats> statsList = jsonList.map((json) => EmployeeStats.fromJson(json, baseUrl)).toList();

        // Сортировка списка по количеству помытых машин
        statsList.sort((a, b) => b.washedCarsCount.compareTo(a.washedCarsCount));

        return statsList;
      }
    } else {
      throw Exception('Не удалось загрузить статистику сотрудников.');
    }
  }

  void _filterResults() {
    setState(() {
      _employeeStats = _employeeStats.where((stats) {
        final nameMatch = stats.name.toLowerCase().contains(_searchQuery.toLowerCase());
        final dateMatch = stats.date == null ||
            (_selectedDate.year == stats.date!.year &&
                _selectedDate.month == stats.date!.month &&
                _selectedDate.day == stats.date!.day);
        return nameMatch && dateMatch;
      }).toList();
    });
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      _filterResults();
    });
  }

  String formatNumber(double number) {
    return NumberFormat("#,##0", "en_US").format(number).replaceAll(',', ' ');
  }

  String proxyUrl(String url) {
    return 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Отчет по сотрудникам', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueGrey[900],
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {
                _initialLoad = _loadData();
              });
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56.0),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Поиск по имени...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0),
                    ),
                    onChanged: (text) => _onSearchChanged(),
                  ),
                ),
                const SizedBox(width: 8.0),
                IconButton(
                  icon: const Icon(Icons.calendar_today, color: Colors.white),
                  onPressed: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2101),
                    );
                    if (picked != null && picked != _selectedDate) {
                      setState(() {
                        _selectedDate = picked;
                        _initialLoad = _loadData();
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: Center(
        child: FutureBuilder<void>(
          future: _initialLoad,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            } else if (_message.isNotEmpty) {
              return Text(_message);
            } else if (_employeeStats.isEmpty) {
              return const Text('Данные недоступны');
            } else {
              return ListView.builder(
                itemCount: _employeeStats.length,
                itemBuilder: (context, index) {
                  var stats = _employeeStats[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                    elevation: 4.0,
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.transparent,
                        child: ClipOval(
                          child: stats.photoUrl.isNotEmpty
                              ? CachedNetworkImage(
                            imageUrl: proxyUrl(stats.photoUrl),
                            placeholder: (context, url) => const CircularProgressIndicator(),
                            errorWidget: (context, url, error) => const Icon(Icons.error),
                            fit: BoxFit.cover,
                            width: 60,
                            height: 60,
                          )
                              : Image.asset('assets/images/placeholder.png', fit: BoxFit.cover, width: 60, height: 60),
                        ),
                      ),
                      title: Text(stats.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Количество машин: ${stats.washedCarsCount}'),
                          Text('Общая сумма: ${formatNumber(stats.totalWashAmount)} UZS'),
                          Text('На руки: ${formatNumber(stats.employeeShare)} UZS'),
                          Text('Касса: ${formatNumber(stats.companyShare)} UZS'),
                          Text('Фонд: ${formatNumber(stats.fundShare)} UZS'),
                          if (stats.date != null) Text('Дата: ${DateFormat('dd-MM-yyyy').format(stats.date!)}'),
                        ],
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.info_outline),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EmployeeDetailPage(
                                employeeStats: stats,
                                selectedDate: _selectedDate, // Передаем выбранную дату
                              ),
                            ),
                          );
                        },
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

class EmployeeStats {
  final int id;
  final String name;
  final int washedCarsCount;
  final double totalWashAmount;
  final double employeeShare;
  final double companyShare;
  final double fundShare; // Новое поле
  final DateTime? date;
  final String photoUrl;

  EmployeeStats({
    required this.id,
    required this.name,
    required this.washedCarsCount,
    required this.totalWashAmount,
    required this.employeeShare,
    required this.companyShare,
    required this.fundShare, // Новое поле
    required this.date,
    required this.photoUrl,
  });

  factory EmployeeStats.fromJson(Map<String, dynamic> json, String baseUrl) {
    return EmployeeStats(
      id: json['id'] ?? 0,
      name: json['name_employees'] ?? '',
      washedCarsCount: json['washed_cars_count'] ?? 0,
      totalWashAmount: _toDouble(json['total_wash_amount'] ?? 0.0),
      employeeShare: _toDouble(json['employee_share'] ?? 0.0),
      companyShare: _toDouble(json['company_share'] ?? 0.0),
      fundShare: _toDouble(json['fund_share'] ?? 0.0), // Новое поле
      date: json['date'] != null ? DateTime.parse(json['date']) : null,
      photoUrl: json['photo_url'] != null ? '$baseUrl${json['photo_url']}' : '',
    );
  }

  static double _toDouble(dynamic value) {
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    } else if (value is int) {
      return value.toDouble();
    } else if (value is double) {
      return value;
    } else {
      return 0.0;
    }
  }
}

class WashOrder {
  final String carPhoto;
  final String typeOfCarWash;
  final double negotiatedPrice;
  final DateTime orderDate;
  final bool isCompleted;

  WashOrder({
    required this.carPhoto,
    required this.typeOfCarWash,
    required this.negotiatedPrice,
    required this.orderDate,
    required this.isCompleted,
  });

  factory WashOrder.fromJson(Map<String, dynamic> json) {
    return WashOrder(
      carPhoto: json['car_photo'] ?? '',
      typeOfCarWash: json['type_of_car_wash']['name'] ?? '', // Доступ к name внутри type_of_car_wash
      negotiatedPrice: double.tryParse(json['negotiated_price'].toString()) ?? 0.0,
      orderDate: DateTime.parse(json['order_date']),
      isCompleted: json['is_completed'] ?? false,
    );
  }
}
