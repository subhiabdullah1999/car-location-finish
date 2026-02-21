import 'package:car_location/ui/admin_page.dart';
import 'package:car_location/ui/car_device_page.dart';
import 'package:car_location/ui/splash_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'services/car_security_service.dart';

void main() async {
  // 1. التأكد من تهيئة الإطارات البرمجية
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. تهيئة فايربيز أولاً
  await Firebase.initializeApp();
  FirebaseDatabase.instance.databaseURL = "https://car-location-67e15-default-rtdb.firebaseio.com/";

  // 3. جلب البيانات المخزنة
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? savedID = prefs.getString('car_id');
  String? userType = prefs.getString('user_type');

  // 4. تشغيل التطبيق (بدون طلب صلاحيات هنا لتجنب الانهيار المفاجئ)
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: SplashScreen(savedID: savedID, userType: userType),
  ));
}

// دالة طلب الصلاحيات منظمة بشكل أفضل
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




