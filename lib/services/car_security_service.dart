import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'dart:async';
import 'dart:io';

class CarSecurityService {
  static final CarSecurityService _instance = CarSecurityService._internal();
  factory CarSecurityService() => _instance;
  CarSecurityService._internal();

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  StreamSubscription? _vibeSub, _locSub, _cmdSub, _trackSub, _sensSub, _numsSub, _vibeToggleSub;
  bool isSystemActive = false;
  bool _vibrationEnabled = true;
  bool _isCallingNow = false; 
  String? myCarID;
  double? sLat, sLng;
  double _threshold = 20.0;
  
  List<String> _emergencyNumbers = [];

  void initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'car_security_channel',
        channelName: 'Hasba Security Service',
        channelDescription: 'نظام حماية السيارة يعمل في الخلفية',
        channelImportance: NotificationChannelImportance.MAX,
        priority: NotificationPriority.MAX,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: true, playSound: true),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 5000,
        isOnceEvent: false,
        autoRunOnBoot: true,
        allowWakeLock: true,
      ),
    );
  }

  Future<void> initSecuritySystem() async {
    if (isSystemActive) return;

    try {
      initForegroundTask();
      await FlutterForegroundTask.startService(
        notificationTitle: '🛡️ نظام حماية HASBA نشط',
        notificationText: 'جاري مراقبة السيارة وحمايتها الآن...',
      );

      SharedPreferences prefs = await SharedPreferences.getInstance();
      myCarID = prefs.getString('car_id');

      Position? p = await Geolocator.getLastKnownPosition();
      p ??= await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      sLat = p.latitude; 
      sLng = p.longitude;

      isSystemActive = true;
      
      if (myCarID != null) {
        // تحديث الحالة فوراً ليتمكن الأدمن من رؤية اللون البرتقالي
        await _dbRef.child('devices/$myCarID/system_active_status').set(true);
        await prefs.setBool('was_system_active', true);
      }

      _startSensors();          
      _listenToNumbers();       
      _listenToVibrationToggle(); 

      _send('status', '🛡️ تم تفعيل نظام الحماية بنجاح والموقع المرجعي مؤمن');
      print("✅ [Security System] تم التفعيل بنجاح للمعرف: $myCarID");

    } catch (e) {
      print("❌ [Security System] فشل في التفعيل: $e");
      isSystemActive = false; 
      if (myCarID != null) {
        await _dbRef.child('devices/$myCarID/system_active_status').set(false);
      }
      _send('status', '⚠️ فشل في تفعيل النظام تلقائياً');
    }
  }

  void _listenToVibrationToggle() {
    if (myCarID == null) return;
    _vibeToggleSub = _dbRef.child('devices/$myCarID/vibration_enabled').onValue.listen((event) {
      if (event.snapshot.value != null) {
        _vibrationEnabled = event.snapshot.value as bool;
      }
    });
  }

  void _listenToNumbers() {
    if (myCarID == null) return;
    _numsSub = _dbRef.child('devices/$myCarID/numbers').onValue.listen((event) {
      if (event.snapshot.value != null) {
        try {
          List<String> tempNumbers = [];
          var data = event.snapshot.value;

          if (data is Map) {
            tempNumbers.add(data['1']?.toString() ?? "");
            tempNumbers.add(data['2']?.toString() ?? "");
            tempNumbers.add(data['3']?.toString() ?? "");
          } else if (data is List) {
            for (var item in data) {
              if (item != null) tempNumbers.add(item.toString());
            }
          }
          _emergencyNumbers = tempNumbers.where((e) => e.isNotEmpty).toList();
        } catch (e) {
          print("❌ خطأ في تنسيق الأرقام: $e");
        }
      }
    });
  }

  void _listenToSensitivity() {
    _sensSub = _dbRef.child('devices/$myCarID/sensitivity').onValue.listen((event) {
      if (event.snapshot.value != null) {
        _threshold = double.parse(event.snapshot.value.toString());
      }
    });
  }

  void _startSensors() {
    _listenToSensitivity();
    _vibeSub = accelerometerEvents.listen((e) {
      if (isSystemActive && _vibrationEnabled && !_isCallingNow) {
        if (e.x.abs() > _threshold || e.y.abs() > _threshold || e.z.abs() > _threshold) {
          _send('alert', '⚠️ تحذير: اهتزاز قوي مكتشف!');
          _startDirectCalling(); 
        }
      }
    });

    _locSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10)
    ).listen((pos) {
      if (sLat != null && sLat != 0 && isSystemActive) {
        double dist = Geolocator.distanceBetween(sLat!, sLng!, pos.latitude, pos.longitude);
        if (dist > 50) {
          _startEmergencyProtocol(dist);
          _locSub?.cancel(); 
        }
      }
    });
  }

  // تم دمج المنطق المحدث هنا لضمان استجابة الأوامر وتغيير الألوان
  void startListeningForCommands(String carID) {
    myCarID = carID;
    _cmdSub?.cancel(); 
    
    _cmdSub = _dbRef.child('devices/$myCarID/commands').onValue.listen((e) async {
      if (e.snapshot.value != null) {
        var data = e.snapshot.value as Map;
        int id = data['id'] ?? 0;
        
        print("📥 أمر مستلم: $id | الحالة: $isSystemActive");

        switch (id) {
          case 7: // تشغيل الحماية
            if (!isSystemActive) {
              await initSecuritySystem();
            } else {
              _send('status', '🛡️ النظام نشط بالفعل');
            }
            break;

          case 6: // إيقاف الحماية
            if (isSystemActive) {
              await stopSecuritySystem();
            } else {
              _send('status', '🔓 النظام متوقف بالفعل');
            }
            break;

          case 1: // الموقع
            if (isSystemActive) {
              await sendLocation();
            } else {
              _send('status', '❌ النظام متوقف، تعذر جلب الموقع');
            }
            break;

          case 2: // البطارية
            await sendBattery();
            break;

          case 3: 
          case 5: // اتصال
            if (isSystemActive) {
              _startDirectCalling();
            } else {
              _send('status', '❌ النظام متوقف، تعذر الاتصال');
            }
            break;

          case 8: // إعادة التشغيل البرمجية (الحل الاحترافي)
            _send('status', '🔄 جاري تصفير الحساسات وإعادة التشغيل...');
            await stopSecuritySystem();
            await Future.delayed(const Duration(seconds: 3));
            await initSecuritySystem();
            _send('status', '✅ تمت إعادة التشغيل بنجاح؛ النظام الآن نشط');
            break;
        }
      }
    });
  }

  Future<void> _startDirectCalling() async {
    if (_isCallingNow) return; 
    _isCallingNow = true;

    if (_emergencyNumbers.isEmpty) {
      _send('status', '❌ فشل: لا توجد أرقام طوارئ مخزنة');
      _isCallingNow = false;
      return;
    }

    for (int i = 0; i < _emergencyNumbers.length; i++) {
      if (!isSystemActive || !_vibrationEnabled) break;
      String phone = _emergencyNumbers[i].trim();
      if (phone.isNotEmpty) {
        _send('status', '🚨 جاري الاتصال بالرقم (${i + 1}): $phone');
        try {
          await FlutterPhoneDirectCaller.callNumber(phone);
        } catch (e) {
          print("❌ خطأ اتصال: $e");
        }
        await Future.delayed(const Duration(seconds: 30));
      }
    }
    _isCallingNow = false;
    _send('status', 'ℹ️ اكتملت دورة الاتصال.');
  }

  void _send(String t, String m, {double? lat, double? lng}) async {
    if (myCarID == null) return;
    int batteryLevel = await Battery().batteryLevel;
    DateTime now = DateTime.now();
    String formattedTime = "${now.hour}:${now.minute.toString().padLeft(2, '0')}";
    String formattedDate = "${now.year}/${now.month}/${now.day}";
    String finalMessage = "$m\n🔋 $batteryLevel% | 🕒 $formattedTime | 📅 $formattedDate";

    _dbRef.child('devices/$myCarID/responses').set({
      'type': t, 
      'message': finalMessage, 
      'lat': lat, 
      'lng': lng, 
      'timestamp': ServerValue.timestamp
    });
  }

  void _startEmergencyProtocol(double dist) {
    _send('alert', '🚨 اختراق! تحركت السيارة ${dist.toInt()} متر');
    _trackSub = Stream.periodic(const Duration(seconds: 10)).listen((_) async {
      if (!isSystemActive) {
        _trackSub?.cancel();
        return;
      }
    });
  }

  Future<void> stopSecuritySystem() async {
    _vibeSub?.cancel(); 
    _locSub?.cancel(); 
    _trackSub?.cancel(); 
    _sensSub?.cancel(); 
    _numsSub?.cancel(); 
    _vibeToggleSub?.cancel();
    
    isSystemActive = false;
    _isCallingNow = false;
    sLat = null; 
    sLng = null;

    await FlutterForegroundTask.stopService();
    
    if (myCarID != null) {
      // تحديث الحالة فوراً ليتمكن الأدمن من رؤية اللون الأزرق
      await _dbRef.child('devices/$myCarID/system_active_status').set(false);
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('was_system_active', false);
    }
    
    _send('status', '🔓 تم إيقاف النظام وتنظيف الذاكرة');
  }

  Future<void> sendLocation() async {
    Position p = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    _send('location', '📍 تم تحديث الموقع بنجاح', lat: p.latitude, lng: p.longitude);
  }

  Future<void> sendBattery() async {
    _send('battery', '🔋 تحديث حالة الطاقة');
  }
}