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
  bool _isCallingNow = false; // لمنع تداخل العمليات
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
  // 1. منع التشغيل المكرر إذا كان النظام يعمل بالفعل
  if (isSystemActive) return;

  try {
    // 2. تفعيل المهمة في الخلفية فوراً (Foreground Service)
    initForegroundTask();
    await FlutterForegroundTask.startService(
      notificationTitle: '🛡️ نظام حماية HASBA نشط',
      notificationText: 'جاري مراقبة السيارة وحمايتها الآن...',
    );

    // 3. تحديث الهوية وجلب الموقع المرجعي للسيارة (أهم خطوة للأمان)
    SharedPreferences prefs = await SharedPreferences.getInstance();
    myCarID = prefs.getString('car_id');

    // محاولة جلب آخر موقع معروف لسرعة الاستجابة، ثم جلب الموقع الدقيق
    Position? p = await Geolocator.getLastKnownPosition();
    p ??= await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

    sLat = p.latitude; 
    sLng = p.longitude;

    // 4. رفع "راية" أن النظام أصبح نشطاً داخلياً وفي قاعدة البيانات
    isSystemActive = true;
    if (myCarID != null) {
      await _dbRef.child('devices/$myCarID/system_active_status').set(true);
      // حفظ الحالة محلياً ليتم تذكرها عند إعادة تشغيل التطبيق
      await prefs.setBool('was_system_active', true);
    }

    // 5. تشغيل "محركات" المراقبة (الحساسات والمستمعات الفرعية)
    _startSensors();          // بدء مراقبة الاهتزاز والموقع
    _listenToNumbers();       // تحديث أرقام الطوارئ في حال تغييرها
    _listenToVibrationToggle(); // مراقبة هل الأدمن سمح بالاهتزاز أم لا

    // 6. إرسال تأكيد للأدمن بأن المهمة تمت بنجاح
    _send('status', '🛡️ تم تفعيل نظام الحماية بنجاح والموقع المرجعي مؤمن');
    
    print("✅ [Security System] تم التفعيل بنجاح للمعرف: $myCarID");

  } catch (e) {
    print("❌ [Security System] فشل في التفعيل: $e");
    isSystemActive = false; // إعادة الحالة في حال الفشل
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
          print("✅ الأرقام المحدثة: $_emergencyNumbers");
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

  void _listenToCommands() {
    _cmdSub = _dbRef.child('devices/$myCarID/commands').onValue.listen((e) async {
      if (e.snapshot.value != null) {
        int id = (e.snapshot.value as Map)['id'] ?? 0;
        
        switch (id) {
          case 1: await sendLocation(); break;
          case 2: await sendBattery(); break;
          case 3: _startDirectCalling(); break; 
          case 4: _send('status', '🔄 جاري إعادة ضبط النظام...'); break; 
          case 5:
            _send('status', '📞 طلب اتصال مباشر بالرقم الأول...');
            if (_emergencyNumbers.isNotEmpty) {
               await FlutterPhoneDirectCaller.callNumber(_emergencyNumbers[0]);
            } else {
               _send('status', '❌ لا توجد أرقام مسجلة للاتصال');
            }
            break;
          case 6: // الميزة الجديدة: إيقاف الحماية عن بعد
            await stopSecuritySystem();
            break;
          case 7: // الميزة الجديدة: تشغيل الحماية عن بعد
            await initSecuritySystem();
            break;
          case 8:
            _send('status', '🔄 جاري إعادة التشغيل...');
            await stopSecuritySystem();
            Future.delayed(const Duration(seconds: 2), () async {
              await initSecuritySystem();
            });
            try { Process.run('reboot', []); } catch (e) { print("Reboot error: $e"); }
            break;
        }
      }
    });
  }


void startListeningForCommands(String carID) {
  myCarID = carID;
  _cmdSub?.cancel(); // منع التكرار
  
  _cmdSub = _dbRef.child('devices/$myCarID/commands').onValue.listen((e) async {
    if (e.snapshot.value != null) {
      var data = e.snapshot.value as Map;
      int id = data['id'] ?? 0;
      
      // طباعة للتأكد من وصول الأمر
      print("📥 أمر مستلم: $id | الحالة الحالية للنظام: $isSystemActive");

      switch (id) {
        case 7: // تشغيل الحماية عن بعد
          if (!isSystemActive) {
            print("🚀 جاري تفعيل النظام عن بعد...");
            await initSecuritySystem();
          } else {
            _send('status', '🛡️ النظام نشط بالفعل');
          }
          break;

        case 6: // إيقاف الحماية عن بعد
          if (isSystemActive) {
            print("🛑 جاري إيقاف النظام عن بعد...");
            await stopSecuritySystem();
          } else {
            _send('status', '🔓 النظام متوقف بالفعل');
          }
          break;

        case 1: // طلب الموقع
          if (isSystemActive) {
            await sendLocation();
          } else {
            _send('status', '❌ النظام متوقف، تعذر جلب الموقع');
          }
          break;

        case 2: // حالة البطارية
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

        case 8: // إعادة التشغيل
          _send('status', '🔄 إعادة تشغيل كاملة...');
          await stopSecuritySystem();
          Future.delayed(const Duration(seconds: 2), () => initSecuritySystem());
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
    _vibeSub?.cancel(); _locSub?.cancel(); 
    // _cmdSub?.cancel(); 
    _trackSub?.cancel(); _sensSub?.cancel(); _numsSub?.cancel(); _vibeToggleSub?.cancel();
    isSystemActive = false;
    _isCallingNow = false;
    await FlutterForegroundTask.stopService();
    _send('status', '🔓 الحماية متوقفة');
    
    // الميزة الجديدة: تحديث الحالة للأدمن ليعرف أن النظام توقف
    if (myCarID != null) {
      _dbRef.child('devices/$myCarID/system_active_status').set(false);
    }
  }

  Future<void> sendLocation() async {
    Position p = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    _send('location', '📍 تم تحديث الموقع بنجاح', lat: p.latitude, lng: p.longitude);
  }

  Future<void> sendBattery() async {
    _send('battery', '🔋 تحديث حالة الطاقة');
  }
}