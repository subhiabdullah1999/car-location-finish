import 'dart:async';

import 'package:car_location/main.dart';
import 'package:car_location/services/car_security_service.dart';
import 'package:car_location/ui/admin_page.dart';
import 'package:car_location/ui/car_device_page.dart';
import 'package:car_location/ui/type_selctor_page.dart';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final String? savedID;
  final String? userType;
  const SplashScreen({super.key, this.savedID, this.userType});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  // دالة تهيئة داخلية لضمان الترتيب
  void _initializeApp() async {
    // أ: طلب الصلاحيات داخل شاشة التحميل وليس قبلها
    await requestPermissions();

    // ب: تشغيل الخدمة إذا وجد المعرف
    if (widget.savedID != null) {
       CarSecurityService().startListeningForCommands(widget.savedID!);
    }

    // ج: الانتقال بعد تأخير بسيط
    Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      if (widget.savedID != null && widget.userType != null) {
        if (widget.userType == 'admin') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AdminPage()));
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const CarAppDevice()));
        }
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AppTypeSelector()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/logohasba.png', width: 250),
            const SizedBox(height: 20),
            const CircularProgressIndicator(color: Colors.blue), // لإشعار المستخدم بالتحميل
          ],
        ),
      ),
    );
  }
}
