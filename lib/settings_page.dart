import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isUpdating = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки приложения', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueGrey[900],
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 20),
              _buildSettingsSection(
                context,
                'Общие настройки',
                [
                  _buildSettingsItem(
                    context,
                    icon: Icons.language,
                    title: 'Язык',
                    subtitle: 'Выберите язык интерфейса',
                  ),
                  _buildSettingsItem(
                    context,
                    icon: Icons.notifications,
                    title: 'Уведомления',
                    subtitle: 'Настройки уведомлений',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildSettingsSection(
                context,
                'Учетная запись',
                [
                  _buildSettingsItem(
                    context,
                    icon: Icons.account_circle,
                    title: 'Профиль',
                    subtitle: 'Редактировать профиль',
                  ),
                  _buildSettingsItem(
                    context,
                    icon: Icons.lock,
                    title: 'Конфиденциальность',
                    subtitle: 'Настройки конфиденциальности',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildUpdateButton(context),
            ],
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: Text(
              'Версия 1.0.8',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
          if (_isUpdating)
            Container(
              color: Colors.black54,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context, String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey[700]),
        ),
        const SizedBox(height: 10),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: items,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsItem(BuildContext context, {required IconData icon, required String title, String? subtitle}) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: Colors.blueGrey[700]),
          title: Text(title),
          subtitle: subtitle != null ? Text(subtitle) : null,
          trailing: Icon(Icons.chevron_right, color: Colors.blueGrey[700]),
          onTap: () {
            // Handle item tap
          },
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildUpdateButton(BuildContext context) {
    return Center(
      child: ElevatedButton.icon(
        onPressed: _update,
        icon: Icon(Icons.system_update, color: Colors.white),
        label: Text('Обновить', style: TextStyle(color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.teal,
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          textStyle: TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Future<void> _update() async {
    setState(() {
      _isUpdating = true;
    });

    await Future.delayed(Duration(seconds: 2));

    setState(() {
      _isUpdating = false;
    });

    _showUpdateNotification(context);
  }

  void _showUpdateNotification(BuildContext context) {
    final snackBar = SnackBar(
      content: Text('Ваша версия приложения самая актуальная!'),
      backgroundColor: Colors.teal,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}
