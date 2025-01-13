import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_page.dart';
import 'employees_detail_page.dart';
import 'create_employee_page.dart';

class EmployeesPage extends StatefulWidget {
  const EmployeesPage({Key? key}) : super(key: key);

  @override
  _EmployeesPageState createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage> {
  late Future<List<Employee>> futureEmployees;
  TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  int employeeCount = 0;

  @override
  void initState() {
    super.initState();
    futureEmployees = fetchEmployees();
  }

  Future<List<Employee>> fetchEmployees() async {
    final response = await http.get(Uri.parse('https://oltinwash.pythonanywhere.com/employees/api/employees/'));

    if (response.statusCode == 200) {
      List jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      List<Employee> employees = jsonResponse.map((employee) => Employee.fromJson(employee)).toList().where((employee) => employee.name.toLowerCase().contains(searchQuery.toLowerCase())).toList();
      setState(() {
        employeeCount = employees.length;
      });
      return employees;
    } else {
      throw Exception('Failed to load employees');
    }
  }

  Future<void> deleteEmployee(int id) async {
    final response = await http.delete(Uri.parse('https://oltinwash.pythonanywhere.com/employees/api/employees/$id/delete/'));

    if (response.statusCode == 204) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Сотрудник успешно удален', style: TextStyle(fontSize: 16)),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        futureEmployees = fetchEmployees(); // Refresh the list after deletion
      });
    } else {
      // Parse the error message from the server response
      final errorMessage = json.decode(utf8.decode(response.bodyBytes))['error'] ?? 'Не удалось удалить сотрудника';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage, style: TextStyle(fontSize: 16)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _logout() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => LoginPage()),
    );
  }

  void _onSearchChanged() {
    setState(() {
      searchQuery = _searchController.text;
      futureEmployees = fetchEmployees();
    });
  }

  void _navigateToCreateEmployee() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreateEmployeePage()),
    ).then((value) {
      if (value == true) {
        setState(() {
          futureEmployees = fetchEmployees();
        });
      }
    });
  }

  Future<void> _refreshData() async {
    setState(() {
      futureEmployees = fetchEmployees();
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
        title: const Text('Список сотрудников', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueGrey[900],
        actions: [
          Center(
            child: Row(
              children: [
                Icon(Icons.people, color: Colors.white),
                SizedBox(width: 4),
                Text('$employeeCount', style: TextStyle(color: Colors.white, fontSize: 18)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.exit_to_app, color: Colors.white),
            onPressed: _logout,
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
                  icon: Icon(Icons.person_add_alt_outlined, color: Colors.white),
                  onPressed: _navigateToCreateEmployee,
                ),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: FutureBuilder<List<Employee>>(
          future: futureEmployees,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(child: Text('Нет сотрудников'));
            } else {
              return ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  var employee = snapshot.data![index];
                  return Dismissible(
                    key: Key(employee.id.toString()),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: EdgeInsets.only(right: 20.0),
                      child: Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (direction) async {
                      return await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Подтверждение удаления'),
                          content: Text('Вы уверены, что хотите удалить сотрудника?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: Text('Нет'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: Text('Да'),
                            ),
                          ],
                        ),
                      );
                    },
                    onDismissed: (direction) async {
                      await deleteEmployee(employee.id);
                    },
                    child: Card(
                      margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                      elevation: 4.0,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.transparent,
                          child: ClipOval(
                            child: employee.photoUrl != null && employee.photoUrl!.isNotEmpty
                                ? Image.network(
                              employee.photoUrl!,
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
                        title: Text(employee.name, style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Должность: ${employee.position}\nВозраст: ${employee.age} лет'),
                        trailing: IconButton(
                          icon: Icon(Icons.info),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EmployeeDetailPage(employeeId: employee.id),
                              ),
                            );
                          },
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

class Employee {
  final int id;
  final String name;
  final String position;
  final int? age;
  final String? photoUrl;

  Employee({required this.id, required this.name, required this.position, this.age, this.photoUrl});

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'],
      name: json['name_employees'],
      position: json['position_name'],
      age: json['age'],
      photoUrl: json['photo_url'],
    );
  }
}