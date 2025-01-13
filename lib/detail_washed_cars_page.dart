import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'washed_cars_page.dart';

class DetailWashedCarsPage extends StatelessWidget {
  final WashedCar car;

  const DetailWashedCarsPage({Key? key, required this.car}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat("#,###", "ru_RU");

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Детали мойки',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blueGrey[900],
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 5,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: double.infinity,
                    height: 350,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      image: DecorationImage(
                        image: car.carPhoto != null && car.carPhoto!.isNotEmpty
                            ? NetworkImage(car.carPhoto!) // Используем NetworkImage для загрузки изображения
                            : AssetImage('assets/images/placeholder.png') as ImageProvider,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Text('Имя мойщика', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(car.washerName, style: TextStyle(fontSize: 18)),
                Divider(),
                Text('Цена', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('${formatter.format(car.washPrice)} UZS', style: TextStyle(fontSize: 18)),
                Divider(),
                Text('Дата', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(
                  car.orderDate != null
                      ? DateFormat('dd.MM.yyyy').format(DateTime.parse(car.orderDate!))
                      : 'Неизвестно',
                  style: TextStyle(fontSize: 18),
                ),
                Divider(),
                Text('Вид мойки', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(car.washType, style: TextStyle(fontSize: 18)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}