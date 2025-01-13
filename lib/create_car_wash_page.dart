import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' as io;
import 'package:image_picker/image_picker.dart';
import 'package:universal_html/html.dart' as html;
import 'package:dropdown_search/dropdown_search.dart';

class CreateCarWashPage extends StatefulWidget {
  const CreateCarWashPage({Key? key}) : super(key: key);

  @override
  _CreateCarWashPageState createState() => _CreateCarWashPageState();
}

class _CreateCarWashPageState extends State<CreateCarWashPage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  Uint8List? _imageBytes;
  io.File? _imageFile;
  int? _serviceClassId;
  double? _negotiatedPrice;
  int? _employeeId;
  List<dynamic> _serviceClasses = [];
  List<dynamic> _employees = [];
  final TextEditingController _negotiatedPriceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchServiceClasses();
    _fetchEmployees();
  }

  void _fetchServiceClasses() async {
    final response = await http.get(Uri.parse('https://oltinwash.pythonanywhere.com/api/service_classes/'));
    if (response.statusCode == 200) {
      setState(() {
        _serviceClasses = json.decode(utf8.decode(response.bodyBytes));
        _serviceClasses.sort((a, b) => a['name'].compareTo(b['name']));
      });
    }
  }

  void _fetchEmployees() async {
    final response = await http.get(Uri.parse('https://oltinwash.pythonanywhere.com/employees/api/washer_employees/'));
    if (response.statusCode == 200) {
      setState(() {
        _employees = json.decode(utf8.decode(response.bodyBytes));
        _employees.sort((a, b) => a['name_employees'].compareTo(b['name_employees']));
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (kIsWeb) {
      final html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
      uploadInput.accept = 'image/*';
      uploadInput.click();

      uploadInput.onChange.listen((e) {
        final files = uploadInput.files;
        if (files!.isNotEmpty) {
          final reader = html.FileReader();
          reader.readAsDataUrl(files[0]);
          reader.onLoadEnd.listen((e) {
            setState(() {
              _imageBytes = Base64Decoder().convert(reader.result.toString().split(',').last);
            });
          });
        }
      });
    } else {
      final pickedFile = await _picker.pickImage(source: source);

      if (pickedFile != null) {
        setState(() {
          _imageFile = io.File(pickedFile.path);
        });
      }
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      if (_serviceClassId != null && _employeeId != null) {
        _sendDataToServer();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Пожалуйста, выберите вид мойки и автомойщика'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _sendDataToServer() async {
    final uri = Uri.parse('https://oltinwash.pythonanywhere.com/api/add_order/');
    final request = http.MultipartRequest('POST', uri);

    String username = 'your_username';
    String password = 'your_password';
    String basicAuth = 'Basic ' + base64Encode(utf8.encode('$username:$password'));
    request.headers['Authorization'] = basicAuth;

    if (_imageFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'car_photo',
          _imageFile!.path,
        ),
      );
    } else if (_imageBytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'car_photo',
          _imageBytes!,
          filename: 'upload.jpg',
        ),
      );
    }

    request.fields['type_of_car_wash'] = _serviceClassId.toString();
    request.fields['employees'] = _employeeId.toString();
    if (_negotiatedPrice != null) {
      request.fields['negotiated_price'] = _negotiatedPrice.toString();
    }

    try {
      final response = await request.send();

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Мойка успешно добавлена'),
            backgroundColor: Colors.green,
          ),
        );
        _clearFormFields();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка при добавлении мойки'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Произошла ошибка: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _clearFormFields() {
    setState(() {
      _imageBytes = null;
      _imageFile = null;
      _serviceClassId = null;
      _negotiatedPrice = null;
      _employeeId = null;
      _negotiatedPriceController.clear();
    });
    _formKey.currentState!.reset();
  }

  String _formatPrice(String price) {
    if (price.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();
    final characters = price.replaceAll(RegExp(r'\D'), '').split('');
    for (int i = 0; i < characters.length; i++) {
      if (i > 0 && (characters.length - i) % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(characters[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Создать мойку',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blueGrey[900],
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              Card(
                elevation: 4.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _pickImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Сделать'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueGrey[900],
                              foregroundColor: Colors.white,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo),
                            label: const Text('Выбрать'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueGrey[900],
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.blueGrey[300]!),
                          borderRadius: BorderRadius.circular(8.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.5),
                              spreadRadius: 2,
                              blurRadius: 7,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: _imageBytes != null
                            ? Image.memory(
                          _imageBytes!,
                          height: 300,
                          fit: BoxFit.cover,
                        )
                            : _imageFile != null
                            ? Image.file(
                          _imageFile!,
                          height: 300,
                          fit: BoxFit.cover,
                        )
                            : Icon(
                          Icons.camera_alt,
                          size: 150,
                          color: Colors.blueGrey[300],
                        ),
                      ),
                      const SizedBox(height: 20),
                      DropdownSearch<String>(
                        items: _serviceClasses.map((serviceClass) {
                          return serviceClass['service_name'].toString();
                        }).toList().cast<String>(),
                        popupProps: const PopupProps.menu(
                          showSearchBox: true,
                        ),
                        dropdownDecoratorProps: const DropDownDecoratorProps(
                          dropdownSearchDecoration: InputDecoration(
                            labelText: "Вид мойки",
                            hintText: "Выберите вид мойки",
                            prefixIcon: Icon(Icons.local_car_wash),
                            border: OutlineInputBorder(),
                          ),
                          baseStyle: TextStyle(fontSize: 14),  // Уменьшение размера шрифта
                        ),
                        onChanged: (value) {
                          setState(() {
                            _serviceClassId = _serviceClasses
                                .firstWhere((element) => element['service_name'] == value)['id'];
                          });
                        },
                        selectedItem: _serviceClassId != null
                            ? _serviceClasses
                            .firstWhere((element) => element['id'] == _serviceClassId)['service_name']
                            : null,
                        validator: (value) {
                          if (value == null) {
                            return 'Пожалуйста, выберите вид мойки';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _negotiatedPriceController,
                        decoration: const InputDecoration(
                          labelText: 'Цена',
                          hintText: 'Введите цену',
                          prefixIcon: Icon(Icons.attach_money),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 14),  // Уменьшение размера шрифта
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Пожалуйста, введите цену';
                          }
                          if (double.tryParse(value.replaceAll(' ', '')) == null) {
                            return 'Пожалуйста, введите правильную цену';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          final formattedPrice = _formatPrice(value);
                          _negotiatedPriceController.value =
                              _negotiatedPriceController.value.copyWith(
                                text: formattedPrice,
                                selection: TextSelection.collapsed(offset: formattedPrice.length),
                              );
                        },
                        onSaved: (value) {
                          if (value!.isNotEmpty) {
                            _negotiatedPrice = double.parse(value.replaceAll(' ', ''));
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                      DropdownSearch<String>(
                        items: _employees.map((employee) {
                          return '${employee['name_employees']}';
                        }).toList(),
                        popupProps: const PopupProps.menu(
                          showSearchBox: true,
                        ),
                        dropdownDecoratorProps: const DropDownDecoratorProps(
                          dropdownSearchDecoration: InputDecoration(
                            labelText: "Автомойщик",
                            hintText: "Выберите автомойщика",
                            prefixIcon: Icon(Icons.person),
                            border: OutlineInputBorder(),
                          ),
                          baseStyle: TextStyle(fontSize: 14),  // Уменьшение размера шрифта
                        ),
                        onChanged: (value) {
                          setState(() {
                            _employeeId = _employees
                                .firstWhere((element) =>
                            element['name_employees'] == value)['id'];
                          });
                        },
                        selectedItem: _employeeId != null
                            ? _employees.firstWhere((element) =>
                        element['id'] == _employeeId)['name_employees']
                            : null,
                        validator: (value) {
                          if (value == null) {
                            return 'Пожалуйста, выберите автомойщика';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _submitForm,
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Добавить мойку'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey[900],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
