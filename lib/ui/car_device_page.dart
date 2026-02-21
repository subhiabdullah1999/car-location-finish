import 'package:car_location/main.dart';
import 'package:car_location/services/car_security_service.dart';
import 'package:car_location/ui/type_selctor_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CarAppDevice extends StatefulWidget {
  const CarAppDevice({super.key});
  @override
  State<CarAppDevice> createState() => _CarAppDeviceState();
}

class _CarAppDeviceState extends State<CarAppDevice> {
  final CarSecurityService _service = CarSecurityService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // لم نعد بحاجة لاستدعاء المستمع هنا لأنه يعمل عالمياً من النقاط السابقة
  }

  Future<void> _handleSystemToggle() async {
    setState(() => _isLoading = true);
    try {
      if (_service.isSystemActive) {
        await _service.stopSecuritySystem();
      } else {
        await _service.initSecuritySystem();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool active = _service.isSystemActive;
    return Scaffold(
      appBar: AppBar(
        title: const Text("جهاز تتبع السيارة"),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.remove('user_type');
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AppTypeSelector()));
          },
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(active ? Icons.security : Icons.security_outlined, size: 120, color: active ? Colors.green : Colors.red),
            const SizedBox(height: 20),
            Text(active ? "نظام الحماية: نشط" : "نظام الحماية: متوقف", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 50),
            SizedBox(
              width: 260, height: 65,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isLoading ? Colors.grey : (active ? Colors.red : Colors.green),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(35)),
                ),
                onPressed: _isLoading ? null : _handleSystemToggle,
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(active ? "إيقاف نظام الحماية" : "تفعيل نظام الحماية", style: const TextStyle(color: Colors.white, fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}