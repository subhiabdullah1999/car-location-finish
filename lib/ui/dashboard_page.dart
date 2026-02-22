import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart'; // إضافة مكتبة الرسم البياني

class DashboardPage extends StatefulWidget {
  final String carID;
  const DashboardPage({super.key, required this.carID});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  double _currentSpeed = 0.0;
  double _totalDistance = 0.0;
  double _avgSpeed = 0.0;
  double _maxSpeed = 0.0;

  // --- متغيرات الرسم البياني الجديدة ---
  List<FlSpot> _speedDataPoints = []; 
  int _timerCounter = 0;
  // ----------------------------------

  @override
  void initState() {
    super.initState();
    _listenToTripData();
  }

  void _listenToTripData() {
    _dbRef.child('devices/${widget.carID}/trip_data').onValue.listen((event) {
      if (event.snapshot.value != null && mounted) {
        var data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        setState(() {
          _currentSpeed = double.tryParse(data['current_speed'].toString()) ?? 0.0;
          _totalDistance = double.tryParse(data['total_distance'].toString()) ?? 0.0;
          _avgSpeed = double.tryParse(data['avg_speed'].toString()) ?? 0.0;
          _maxSpeed = double.tryParse(data['max_speed'].toString()) ?? 0.0;

          // تحديث بيانات الرسم البياني لحظياً
          _timerCounter++;
          _speedDataPoints.add(FlSpot(_timerCounter.toDouble(), _currentSpeed));
          // الاحتفاظ بآخر 30 نقطة فقط لضمان سلاسة العرض
          if (_speedDataPoints.length > 30) {
            _speedDataPoints.removeAt(0);
          }
        });
      }
    });
  }

  void _resetDistance() {
    _dbRef.child('devices/${widget.carID}/trip_data').update({
      'total_distance': 0.0,
      'avg_speed': 0.0,
      'max_speed': 0.0,
      'reset_timestamp': ServerValue.timestamp,
    });
    // تصفير الرسم البياني أيضاً عند تصفير العداد
    setState(() {
      _speedDataPoints.clear();
      _timerCounter = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Colors.greenAccent.shade400;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("مراقبة السرعة والمسافة"),
        backgroundColor: isDark ? const Color(0xFF1F1F1F) : Colors.blue.shade900,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // 1. عداد السرعة مع المؤشر (الكود الأصلي)
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _buildGaugeBackground(isDark),
                    _buildNeedle(_currentSpeed),
                    Positioned(
                      bottom: 40,
                      child: Column(
                        children: [
                          Text("${_currentSpeed.toInt()}", 
                            style: TextStyle(fontSize: 45, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                          Text("km/h", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),

              // 2. الرسم البياني المضاف حديثاً
              const Text("تحليل السرعة اللحظي", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _buildSpeedChart(isDark),
              const SizedBox(height: 25),

              // 3. بطاقات المعلومات (الكود الأصلي)
              _infoCard("المسافة المقطوعة الكلية", "${_totalDistance.toStringAsFixed(2)} كم", Icons.route, isDark),
              const SizedBox(height: 12),
              _infoCard("أقصى سرعة مسجلة", "${_maxSpeed.toStringAsFixed(1)} كم/ساعة", Icons.trending_up, isDark),
              const SizedBox(height: 12),
              _infoCard("متوسط سرعة الرحلة", "${_avgSpeed.toStringAsFixed(1)} كم/ساعة", Icons.speed, isDark),
              const SizedBox(height: 30),

              // 4. زر التصفير (الكود الأصلي)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: _resetDistance,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text("تصفير كافة بيانات الرحلة", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ويدجت الرسم البياني الجديد
  Widget _buildSpeedChart(bool isDark) {
    return Container(
      height: 150,
      width: double.infinity,
      padding: const EdgeInsets.only(top: 10, right: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isDark ? Colors.white10 : Colors.transparent),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: _speedDataPoints.isEmpty ? [const FlSpot(0, 0)] : _speedDataPoints,
              isCurved: true,
              color: Colors.greenAccent,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.greenAccent.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGaugeBackground(bool isDark) {
    return Container(
      width: 250, height: 250,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? Colors.black26 : Colors.white,
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12, width: 8),
        boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black.withOpacity(0.1))],
      ),
      child: CustomPaint(painter: GaugeTicksPainter(isDark)),
    );
  }

  Widget _buildNeedle(double speed) {
    double angle = (speed / 220) * 240 - 120; 
    return Transform.rotate(
      angle: angle * (math.pi / 180),
      child: Container(
        height: 180,
        alignment: Alignment.topCenter,
        child: Container(
          width: 4, height: 90,
          decoration: BoxDecoration(
            color: Colors.redAccent,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.5), blurRadius: 5)],
          ),
        ),
      ),
    );
  }

  Widget _infoCard(String title, String value, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isDark ? Colors.white10 : Colors.transparent),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue, size: 30),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 13)),
              Text(value, style: TextStyle(color: isDark ? Colors.greenAccent : Colors.blue.shade900, fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}

class GaugeTicksPainter extends CustomPainter {
  final bool isDark;
  GaugeTicksPainter(this.isDark);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = isDark ? Colors.white24 : Colors.black26..strokeWidth = 2;
    for (int i = 0; i <= 220; i += 20) {
      double angle = (i / 220) * 240 - 120;
      double rad = angle * (math.pi / 180);
      Offset p1 = Offset(size.width/2 + (size.width/2 - 10) * math.sin(rad + math.pi), size.height/2 + (size.height/2 - 10) * math.cos(rad + math.pi));
      Offset p2 = Offset(size.width/2 + (size.width/2 - 25) * math.sin(rad + math.pi), size.height/2 + (size.height/2 - 25) * math.cos(rad + math.pi));
      canvas.drawLine(p1, p2, paint);
    }
  }
  @override bool shouldRepaint(CustomPainter old) => false;
}