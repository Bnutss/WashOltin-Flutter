import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
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
  final String baseUrl = 'https://oltinwash.pythonanywhere.com';

  @override
  void initState() {
    super.initState();
    tzdata.initializeTimeZones();
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

  Future<void> _completeOrdersForToday(int employeeId) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/api/employee-stats/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'employee_id': employeeId}),
    );

    if (response.statusCode == 200) {
      setState(() {
        _employeeStats = _employeeStats.map((stats) {
          if (stats.id == employeeId) {
            stats.isCompleted = true;
            stats.completionDate = DateTime.now();
          }
          return stats;
        }).toList();
      });
    } else {
      throw Exception('Не удалось завершить заказы.');
    }
  }

  DateTime _parseServerTime(String timeString) {
    final serverTime = DateTime.parse(timeString);
    final localTime = serverTime.toLocal();
    return localTime;
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
                    color: stats.isCompleted ? Colors.lightGreenAccent : null,
                    margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                    elevation: 4.0,
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.transparent,
                        child: ClipOval(
                          child: stats.photoUrl.isNotEmpty
                              ? Image.network(
                            stats.photoUrl,
                            fit: BoxFit.cover,
                            width: 60,
                            height: 60,
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
                              return const Icon(Icons.error);
                            },
                          )
                              : Image.asset('assets/images/placeholder.png', fit: BoxFit.cover, width: 60, height: 60),
                        ),
                      ),
                      title: Text(stats.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Количество машин: ${stats.washedCarsCount}', style: const TextStyle(fontSize: 12)),
                          Text('Общая сумма: ${formatNumber(stats.totalWashAmount)} UZS', style: const TextStyle(fontSize: 12)),
                          Text('На руки: ${formatNumber(stats.employeeShare)} UZS', style: const TextStyle(fontSize: 12)),
                          Text('Касса: ${formatNumber(stats.companyShare)} UZS', style: const TextStyle(fontSize: 12)),
                          Text('Фонд: ${formatNumber(stats.fundShare)} UZS', style: const TextStyle(fontSize: 12)),
                          if (stats.date != null) Text('Дата: ${DateFormat('dd-MM-yyyy').format(stats.date!)}', style: const TextStyle(fontSize: 12)),
                          if (stats.isCompleted && stats.completionDate != null)
                            Text(
                              'Сдал кассу: ${DateFormat('dd-MM-yyyy HH:mm').format(_parseServerTime(stats.completionDate!.toIso8601String()))}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.info_outline),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EmployeeDetailPage(
                                    employeeStats: stats,
                                    selectedDate: _selectedDate,
                                  ),
                                ),
                              );
                            },
                          ),
                          if (!stats.isCompleted)
                            IconButton(
                              icon: Icon(Icons.check_circle_outline, color: Colors.green),
                              onPressed: () {
                                _completeOrdersForToday(stats.id);
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

class EmployeeStats {
  final int id;
  final int orderId;
  final String name;
  final int washedCarsCount;
  final double totalWashAmount;
  final double employeeShare;
  final double companyShare;
  final double fundShare;
  final DateTime? date;
  final String photoUrl;
  bool isCompleted;
  DateTime? completionDate;

  EmployeeStats({
    required this.id,
    required this.orderId,
    required this.name,
    required this.washedCarsCount,
    required this.totalWashAmount,
    required this.employeeShare,
    required this.companyShare,
    required this.fundShare,
    required this.date,
    required this.photoUrl,
    this.isCompleted = false,
    this.completionDate,
  });

  factory EmployeeStats.fromJson(Map<String, dynamic> json, String baseUrl) {
    return EmployeeStats(
      id: json['id'] ?? 0,
      orderId: json['order_id'] ?? 0,
      name: json['name_employees'] ?? '',
      washedCarsCount: json['washed_cars_count'] ?? 0,
      totalWashAmount: _toDouble(json['total_wash_amount'] ?? 0.0),
      employeeShare: _toDouble(json['employee_share'] ?? 0.0),
      companyShare: _toDouble(json['company_share'] ?? 0.0),
      fundShare: _toDouble(json['fund_share'] ?? 0.0),
      date: json['date'] != null ? DateTime.parse(json['date']) : null,
      photoUrl: json['photo_url'] != null ? '$baseUrl${json['photo_url']}' : '',
      isCompleted: json['is_completed'] ?? false,
      completionDate: json['completion_date'] != null ? DateTime.parse(json['completion_date']) : null,
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