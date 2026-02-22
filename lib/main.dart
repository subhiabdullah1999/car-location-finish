import 'package:car_location/ui/admin_page.dart';
import 'package:car_location/ui/car_device_page.dart';
import 'package:car_location/ui/splash_page.dart';
import 'package:car_location/ui/type_selctor_page.dart'; // تأكد من المسار الصحيح
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'services/car_security_service.dart';

// معرف عالمي للتحكم في الثيم من أي مكان في التطبيق
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  // 1. التأكد من تهيئة الإطارات البرمجية
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. تهيئة فايربيز
  await Firebase.initializeApp();
  FirebaseDatabase.instance.databaseURL = "https://car-location-67e15-default-rtdb.firebaseio.com/";

  // 3. جلب البيانات المخزنة (المعرف، نوع المستخدم، وحالة الوضع الداكن)
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? savedID = prefs.getString('car_id');
  String? userType = prefs.getString('user_type');
  bool isDark = prefs.getBool('dark_mode') ?? false;
  
  // ضبط الثيم الأولي بناءً على الإعدادات المحفوظة
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

  // 4. تشغيل التطبيق مع مراقب الثيم
  runApp(HasbaApp(savedID: savedID, userType: userType));
}

class HasbaApp extends StatelessWidget {
  final String? savedID;
  final String? userType;

  const HasbaApp({super.key, this.savedID, this.userType});

  @override
  Widget build(BuildContext context) {
    // ValueListenableBuilder يجعل التطبيق يعيد بناء نفسه فور تغيير قيمة themeNotifier
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Hasba Tracker',
          
          // إعدادات الثيم الفاتح
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorSchemeSeed: Colors.blue.shade900,
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.blue.shade900,
              foregroundColor: Colors.white,
            ),
          ),
          
          // إعدادات الثيم الداكن (Dark Mode)
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF121212),
            colorSchemeSeed: Colors.blue,
            cardTheme: const CardTheme(color: Color(0xFF1E1E1E)),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1F1F1F),
              foregroundColor: Colors.white,
            ),
          ),
          
          themeMode: currentMode,
          home: SplashScreen(savedID: savedID, userType: userType),
        );
      },
    );
  }
}

// دالة طلب الصلاحيات (تم الحفاظ عليها كما هي)
Future<void> requestPermissions() async {
  // طلب صلاحية الإشعارات أولاً لأندرويد 13+
  await Permission.notification.request();
  
  // طلب بقية الصلاحيات
  Map<Permission, PermissionStatus> statuses = await [
    Permission.location,
    Permission.phone,
    Permission.sensors,
    Permission.ignoreBatteryOptimizations,
    Permission.systemAlertWindow,
  ].request();
  
  print("Permissions status: $statuses");
}