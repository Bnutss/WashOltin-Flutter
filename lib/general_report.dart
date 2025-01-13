import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class GeneralReportPage extends StatefulWidget {
  const GeneralReportPage({Key? key}) : super(key: key);

  @override
  _GeneralReportPageState createState() => _GeneralReportPageState();
}

class _GeneralReportPageState extends State<GeneralReportPage> {
  late Future<List<ReportData>> reportData;
  DateTimeRange selectedDateRange = DateTimeRange(
    start: DateTime.now().subtract(Duration(days: 30)),
    end: DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    reportData = fetchReportData(selectedDateRange);
  }

  Future<List<ReportData>> fetchReportData(DateTimeRange dateRange) async {
    final formattedStartDate = DateFormat('yyyy-MM-dd').format(dateRange.start);
    final formattedEndDate = DateFormat('yyyy-MM-dd').format(dateRange.end);
    final response = await http.get(
      Uri.parse('https://oltinwash.pythonanywhere.com/api/report?start_date=$formattedStartDate&end_date=$formattedEndDate'),
    );

    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((item) => ReportData.fromJson(item)).toList();
    } else {
      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');
      throw Exception('Failed to load report');
    }
  }

  void _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: selectedDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != selectedDateRange) {
      setState(() {
        selectedDateRange = picked;
        reportData = fetchReportData(selectedDateRange);
      });
    }
  }

  void _refreshData() {
    setState(() {
      reportData = fetchReportData(selectedDateRange);
    });
  }

  Future<void> _sendReportToTelegram(double totalAmount, double cashierAmount, double employeesAmount, int totalWashes) async {
    final String apiUrl = 'https://oltinwash.pythonanywhere.com/api/send_telegram_message/';
    final String startDate = DateFormat('dd.MM.yyyy').format(selectedDateRange.start);
    final String endDate = DateFormat('dd.MM.yyyy').format(selectedDateRange.end);

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'total_amount': totalAmount.toString(),
        'cashier_amount': cashierAmount.toString(),
        'employees_amount': employeesAmount.toString(),
        'total_washes': totalWashes.toString(),
        'start_date': startDate,
        'end_date': endDate,
      },
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Отчет отправлен в Telegram'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка отправки отчета в Telegram'),
        ),
      );
    }
  }

  String formatNumber(double number) {
    if (number % 1 == 0) {
      final formatter = NumberFormat("#,###", "en_US");
      return formatter.format(number).replaceAll(',', ' ');
    } else {
      final formatter = NumberFormat("#,##0.0", "en_US");
      return formatter.format(number).replaceAll(',', ' ');
    }
  }

  double calculateTotal(List<ReportData> data, double Function(ReportData) selector) {
    return data.fold(0, (sum, item) => sum + selector(item));
  }

  int calculateTotalWashes(List<ReportData> data) {
    return data.fold(0, (sum, item) => sum + item.totalWashes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Общий отчет', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueGrey[900],
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDateRange(context),
            tooltip: 'Выбрать диапазон дат',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Обновить данные',
          ),
          FutureBuilder<List<ReportData>>(
            future: reportData,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final totalAmount = calculateTotal(snapshot.data!, (item) => item.totalAmount);
                final totalCashierAmount = calculateTotal(snapshot.data!, (item) => item.cashierAmount);
                final totalEmployeesAmount = calculateTotal(snapshot.data!, (item) => item.employeesAmount);
                final totalWashes = calculateTotalWashes(snapshot.data!);

                return IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _sendReportToTelegram(totalAmount, totalCashierAmount, totalEmployeesAmount, totalWashes),
                  tooltip: 'Отправить отчет в Telegram',
                );
              } else {
                return Container();
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                "Отчет с ${DateFormat('dd.MM.yyyy').format(selectedDateRange.start)} по ${DateFormat('dd.MM.yyyy').format(selectedDateRange.end)}",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: FutureBuilder<List<ReportData>>(
                future: reportData,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final totalAmount = calculateTotal(snapshot.data!, (item) => item.totalAmount);
                    final totalCashierAmount = calculateTotal(snapshot.data!, (item) => item.cashierAmount);
                    final totalEmployeesAmount = calculateTotal(snapshot.data!, (item) => item.employeesAmount);
                    final totalWashes = calculateTotalWashes(snapshot.data!);

                    return Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            itemCount: snapshot.data!.length,
                            itemBuilder: (context, index) {
                              return ReportCard(
                                data: snapshot.data![index],
                                formatNumber: formatNumber,
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildTotalBlock(totalAmount, totalCashierAmount, totalEmployeesAmount, totalWashes),
                      ],
                    );
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Ошибка: ${snapshot.error}'));
                  }

                  return const Center(child: CircularProgressIndicator());
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalBlock(double totalAmount, double totalCashierAmount, double totalEmployeesAmount, int totalWashes) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      color: Colors.blueGrey[50],
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Итоги',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[900]),
            ),
            const Divider(height: 15, thickness: 1.5),
            _buildTotalItem('Общее кол-во машин', totalWashes.toString()),
            const SizedBox(height: 8),
            _buildTotalItem('Итоговая сумма', formatNumber(totalAmount) + ' UZS'),
            const SizedBox(height: 8),
            _buildTotalItem('Итоги кассы', formatNumber(totalCashierAmount) + ' UZS'),
            const SizedBox(height: 8),
            _buildTotalItem('Итоги мойщиков', formatNumber(totalEmployeesAmount) + ' UZS'),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalItem(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.blueGrey[800]),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey[900]),
        ),
      ],
    );
  }
}

class ReportCard extends StatelessWidget {
  final ReportData data;
  final String Function(double) formatNumber;

  const ReportCard({Key? key, required this.data, required this.formatNumber}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildReportItem('Дата', '${DateFormat('dd.MM.yyyy').format(data.orderDate)}'),
            _buildDivider(),
            _buildReportItem('Общее кол-во моек', '${data.totalWashes}'),
            _buildDivider(),
            _buildReportItem('Общая сумма', formatNumber(data.totalAmount)),
            _buildDivider(),
            _buildReportItem('Сумма кассы', formatNumber(data.cashierAmount)),
            _buildDivider(),
            _buildReportItem('Заработок мойщиков', formatNumber(data.employeesAmount)),
          ],
        ),
      ),
    );
  }

  Widget _buildReportItem(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey[800]),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      color: Colors.grey[300],
      height: 1,
      thickness: 1,
    );
  }
}

class ReportData {
  final DateTime orderDate;
  final int totalWashes;
  final double totalAmount;
  final double cashierAmount;
  final double employeesAmount;

  ReportData({
    required this.orderDate,
    required this.totalWashes,
    required this.totalAmount,
    required this.cashierAmount,
    required this.employeesAmount,
  });

  factory ReportData.fromJson(Map<String, dynamic> json) {
    return ReportData(
      orderDate: DateTime.parse(json['order_date_only']),
      totalWashes: json['total_washes'] ?? 0,
      totalAmount: json['total_amount'] != null ? double.tryParse(json['total_amount'].toString()) ?? 0.0 : 0.0,
      cashierAmount: json['cashier_amount'] != null ? double.tryParse(json['cashier_amount'].toString()) ?? 0.0 : 0.0,
      employeesAmount: json['employees_amount'] != null ? double.tryParse(json['employees_amount'].toString()) ?? 0.0 : 0.0,
    );
  }
}
