import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AtWorkPage extends StatefulWidget {
  const AtWorkPage({Key? key}) : super(key: key);

  @override
  _AtWorkPageState createState() => _AtWorkPageState();
}

class _AtWorkPageState extends State<AtWorkPage> {
  List<dynamic> employees = [];
  bool isLoading = true;
  String _message = '';
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    fetchEmployees();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> fetchEmployees() async {
    try {
      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final response = await http.get(Uri.parse('http://bnutss.pythonanywhere.com/api/employees/at-work/?date=$formattedDate'));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          employees = data;
          isLoading = false;
          _message = employees.isEmpty ? 'На выбранную дату нет данных' : '';
        });
      } else {
        throw Exception('Не удалось загрузить сотрудников');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        _message = 'Ошибка: $e';
      });
    }
  }

  void _filterResults() {
    setState(() {
      employees = employees.where((employee) {
        final nameMatch = employee['name_employees'].toLowerCase().contains(_searchQuery.toLowerCase());
        return nameMatch;
      }).toList();
    });
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      _filterResults();
    });
  }

  String proxyUrl(String url) {
    return 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сотрудники на работе', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueGrey[900],
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                isLoading = true;
              });
              fetchEmployees();
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.person, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  '${employees.length}',
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
              ],
            ),
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
                SizedBox(width: 8.0),
                IconButton(
                  icon: Icon(Icons.calendar_today, color: Colors.white),
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
                        isLoading = true;
                      });
                      fetchEmployees();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blueGrey[900]!, Colors.blueGrey[500]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: isLoading
            ? Center(child: CircularProgressIndicator())
            : employees.isEmpty
            ? Center(
          child: Text(
            _message.isNotEmpty ? _message : 'Нет сотрудников на работе',
            style: TextStyle(color: Colors.white, fontSize: 24),
          ),
        )
            : ListView.builder(
          itemCount: employees.length,
          itemBuilder: (context, index) {
            final employee = employees[index];
            final name = employee['name_employees'] ?? 'Неизвестно';
            final position = employee['position_name'] ?? 'Неизвестно';
            final photoUrl = employee['photo_url'] ?? 'https://www.strasys.uk/wp-content/uploads/2022/02/Depositphotos_484354208_S.jpg';

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              color: Colors.blueGrey[700],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListTile(
                title: Text(
                  name,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  position,
                  style: TextStyle(color: Colors.white70),
                ),
                leading: CircleAvatar(
                  backgroundColor: Colors.transparent,
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: proxyUrl(photoUrl),
                      placeholder: (context, url) => CircularProgressIndicator(),
                      errorWidget: (context, url, error) => Icon(Icons.error),
                      fit: BoxFit.cover,
                      width: 40,
                      height: 40,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
