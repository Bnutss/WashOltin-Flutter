import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' as io;
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:universal_html/html.dart' as html;

class CreateEmployeePage extends StatefulWidget {
  @override
  _CreateEmployeePageState createState() => _CreateEmployeePageState();
}

class _CreateEmployeePageState extends State<CreateEmployeePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _passportNumberController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  String? _gender;
  String? _position;
  List<Map<String, String>> _positions = [];
  Uint8List? _imageBytes;
  io.File? _imageFile;

  @override
  void initState() {
    super.initState();
    _fetchPositions();
  }

  Future<void> _fetchPositions() async {
    try {
      final response = await http.get(Uri.parse('http://bnutss.pythonanywhere.com/employees/api/positions/'));
      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _positions = responseData.map((data) => {
            'id': data['id'].toString(),
            'name': data['name_positions'] as String,
          }).toList();
        });
      } else {
        throw Exception('Failed to load positions');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось загрузить список позиций: $e')),
      );
    }
  }

  Future<void> _createEmployee() async {
    if (_position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Пожалуйста, выберите должность')),
      );
      return;
    }

    final uri = Uri.parse('http://bnutss.pythonanywhere.com/employees/api/employees/add/');
    var request = http.MultipartRequest('POST', uri);

    request.fields['name_employees'] = _nameController.text;
    request.fields['position'] = _position!;
    request.fields['birth_date'] = _birthDateController.text;
    request.fields['phone_number'] = _phoneNumberController.text;
    request.fields['address'] = _addressController.text;
    request.fields['passport_number'] = _passportNumberController.text;
    request.fields['gender'] = _gender!;

    if (_imageFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'photo',
          _imageFile!.path,
        ),
      );
    } else if (_imageBytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'photo',
          _imageBytes!,
          filename: 'upload.jpg',
        ),
      );
    }

    final response = await request.send();

    if (response.statusCode == 201) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось создать сотрудника')),
      );
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await showDialog<XFile>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Выбрать фото'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text('Сделать фото'),
                onTap: () async {
                  final XFile? photo = await picker.pickImage(source: ImageSource.camera);
                  Navigator.pop(context, photo);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Выбрать из галереи'),
                onTap: () async {
                  final XFile? photo = await picker.pickImage(source: ImageSource.gallery);
                  Navigator.pop(context, photo);
                },
              ),
            ],
          ),
        );
      },
    );

    if (pickedFile != null) {
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _imageBytes = bytes;
        });
      } else {
        setState(() {
          _imageFile = io.File(pickedFile.path);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Создать сотрудника', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueGrey[900],
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField(_nameController, 'Имя'),
              _buildDropdownField(
                'Должность',
                _positions,
                _position,
                    (String? newValue) {
                  setState(() {
                    _position = newValue;
                  });
                },
              ),
              _buildDateField(_birthDateController, 'Дата рождения'),
              _buildTextField(_phoneNumberController, 'Телефон', keyboardType: TextInputType.phone),
              _buildTextField(_addressController, 'Адрес'),
              _buildTextField(_passportNumberController, 'Номер паспорта'),
              _buildDropdownField(
                'Пол',
                [
                  {'id': 'Мужской', 'name': 'Мужской'},
                  {'id': 'Женский', 'name': 'Женский'}
                ],
                _gender,
                    (String? newValue) {
                  setState(() {
                    _gender = newValue;
                  });
                },
              ),
              SizedBox(height: 20),
              _buildImagePicker(),
              SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _createEmployee();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey[900],
                  padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  textStyle: TextStyle(fontSize: 18, color: Colors.white),
                ),
                child: Text('Создать', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String labelText, {TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: labelText,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          filled: true,
          fillColor: Colors.grey[200],
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
        keyboardType: keyboardType,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Пожалуйста, введите $labelText';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDateField(TextEditingController controller, String labelText) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: labelText,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          filled: true,
          fillColor: Colors.grey[200],
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
        readOnly: true,
        onTap: () => _selectDate(context),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Пожалуйста, выберите $labelText';
          }
          return null;
        },
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _birthDateController.text = DateFormat('dd.MM.yyyy').format(picked);
      });
    }
  }

  Widget _buildDropdownField(
      String labelText,
      List<Map<String, String>> options,
      String? value,
      void Function(String?) onChanged
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: labelText,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          filled: true,
          fillColor: Colors.grey[200],
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
        value: value,
        items: options.map((Map<String, String> item) {
          return DropdownMenuItem<String>(
            value: item['id'],
            child: Text(item['name']!),
          );
        }).toList(),
        onChanged: onChanged,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Пожалуйста, выберите $labelText';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildImagePicker() {
    return Column(
      children: [
        _imageBytes != null
            ? Image.memory(
          _imageBytes!,
          height: 150,
          fit: BoxFit.cover,
        )
            : _imageFile != null
            ? Image.file(
          _imageFile!,
          height: 150,
          fit: BoxFit.cover,
        )
            : Icon(
          Icons.person,
          size: 150,
          color: Colors.grey,
        ),
        SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: _pickImage,
          icon: Icon(Icons.camera_alt, color: Colors.white),
          label: Text('Выбрать фото', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueGrey[900],
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            textStyle: TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }
}
