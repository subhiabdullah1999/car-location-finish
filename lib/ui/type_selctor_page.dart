import 'package:car_location/services/car_security_service.dart';
import 'package:car_location/ui/admin_page.dart';
import 'package:car_location/ui/car_device_page.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTypeSelector extends StatefulWidget {
  const AppTypeSelector({super.key});
  @override
  State<AppTypeSelector> createState() => _AppTypeSelectorState();
}

class _AppTypeSelectorState extends State<AppTypeSelector> {
  final TextEditingController _idController = TextEditingController();
  final CarSecurityService _service = CarSecurityService(); // إضافة مرجع للخدمة

  void _saveIDAndGo(String type, Widget target) async {
    if (_idController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى إدخال رقم هاتف السيارة")));
      return;
    }

    String carId = _idController.text;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('car_id', carId);
    await prefs.setString('user_type', type);

    // --- [تعديل جوهري] تشغيل المستمع فور الضغط على أي زر (أدمن أو جهاز) ---
    _service.startListeningForCommands(carId);

    FirebaseDatabase.instance.ref().child('devices/$carId/sensitivity').get().then((snapshot) {
      if (!snapshot.exists) {
        FirebaseDatabase.instance.ref().child('devices/$carId/sensitivity').set(20);
      }
    });

    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => target));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 100),
              const Icon(Icons.security, size: 80, color: Colors.blue),
              const Text("HASBA TRKAR", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              TextField(
                controller: _idController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: "أدخل رقم هاتف السيارة (المعرف)",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
              const SizedBox(height: 20),
              _btn("أنا الأدمن (تتبع وتحكم)", Icons.admin_panel_settings, Colors.blue.shade700, () => _saveIDAndGo('admin', const AdminPage())),
              const SizedBox(height: 10),
              _btn("جهاز السيارة (مراقب وحساس)", Icons.vibration, Colors.grey.shade800, () => _saveIDAndGo('device', const CarAppDevice())),
            ],
          ),
        ),
      ),
    );
  }

  Widget _btn(String t, IconData i, Color c, VoidCallback onPress) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60), backgroundColor: c),
      onPressed: onPress,
      icon: Icon(i, color: Colors.white),
      label: Text(t, style: const TextStyle(color: Colors.white)),
    );
  }
}