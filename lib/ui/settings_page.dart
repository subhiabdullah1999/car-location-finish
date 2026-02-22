import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// استيراد ملف main للوصول إلى themeNotifier
import 'package:car_location/main.dart'; 

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentTheme();
  }

  // تحميل الحالة الحالية من التفضيلات
  void _loadCurrentTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('dark_mode') ?? false;
    });
  }

  // دالة تغيير الثيم وحفظه
  void _toggleTheme(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', value);
    
    setState(() {
      _isDarkMode = value;
    });

    // تحديث التطبيق بالكامل لحظياً عبر الـ Notifier الموجود في main.dart
    themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
  }

  @override
  Widget build(BuildContext context) {
    // تحديد الألوان بناءً على الوضع الحالي لتناسق الواجهة
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("الإعدادات"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          // كرت خيار الوضع الداكن
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: SwitchListTile(
              secondary: Icon(
                _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                color: _isDarkMode ? Colors.amber : Colors.blue,
              ),
              title: const Text("الوضع الداكن", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(_isDarkMode ? "تفعيل المظهر الأسود" : "تفعيل المظهر الفاتح"),
              value: _isDarkMode,
              onChanged: _toggleTheme,
            ),
          ),

          const SizedBox(height: 10),

          // كرت معلومات التطبيق
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: const ListTile(
              leading: Icon(Icons.info_outline, color: Colors.grey),
              title: Text("إصدار التطبيق"),
              trailing: Text("v2.5.0", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
          ),

          const Spacer(),
          
          // تذييل الصفحة
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              "HASBA TRACKER SECURITY SYSTEM",
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12, letterSpacing: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}