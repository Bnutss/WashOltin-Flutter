import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

void initializeOrderCheck() {
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
    Workmanager().registerPeriodicTask(
      "1",
      "checkOrders",
      frequency: const Duration(minutes: 20), // Изменено на 20 минут
      initialDelay: const Duration(minutes: 3),
    );
  }
}

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == "checkOrders") {
      bool noOrders = await checkOrders();
      if (noOrders) {
        await scheduleNotification();
        await checkUsers(); // Добавлена проверка пользователей
      }
    }
    return Future.value(true);
  });
}

Future<bool> checkOrders() async {
  final response = await http.get(Uri.parse('https://oltinwash.pythonanywhere.com/api/check_orders/'));

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    return data['no_orders'];
  }
  return false;
}

Future<void> checkUsers() async {
  final response = await http.get(Uri.parse('https://oltinwash.pythonanywhere.com/api/user_list/'));

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    // Обработка данных о пользователях, если необходимо
    print(data);
  }
}

Future<void> scheduleNotification() async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
  AndroidNotificationDetails(
    'no_order_channel_id',
    'No Orders Notification',
    channelDescription: 'Channel for no orders notifications',
    importance: Importance.max,
    priority: Priority.high,
  );
  const NotificationDetails platformChannelSpecifics =
  NotificationDetails(android: androidPlatformChannelSpecifics);

  await flutterLocalNotificationsPlugin.show(
    0,
    'Нет заказов',
    'Вы не создали заказ сегодня с 9:00 до 23:00',
    platformChannelSpecifics,
  );
}
