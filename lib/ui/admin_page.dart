import 'package:car_location/main.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert'; // ضروري لتحويل البيانات JSON

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});
  @override
  _AdminPageState createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterLocalNotificationsPlugin _notif = FlutterLocalNotificationsPlugin();
  
  final TextEditingController _n1 = TextEditingController();
  final TextEditingController _n2 = TextEditingController();
  final TextEditingController _n3 = TextEditingController();
  
  StreamSubscription? _statusSub;
  String _lastStatus = "انتظار التحديثات...";
  String? _carID;
  bool _isDialogShowing = false;
  bool _isExpanded = true; 

  // قائمة تخزين الإشعارات (الميزة الجديدة)
  List<Map<String, String>> _allNotifications = [];

  @override
  void initState() {
    super.initState();
    _setupNotifs();
    _loadSavedNumbers();
  }

  // تحميل الأرقام والإشعارات المحفوظة
  void _loadSavedNumbers() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _carID = prefs.getString('car_id');
    
    if (_carID != null) {
      _listenToStatus();
      _loadNotificationsFromDisk(); // تحميل الإشعارات القديمة
      
      setState(() {
        _n1.text = prefs.getString('num1_$_carID') ?? "";
        _n2.text = prefs.getString('num2_$_carID') ?? "";
        _n3.text = prefs.getString('num3_$_carID') ?? "";
        if (_n1.text.isNotEmpty) _isExpanded = false;
      });

      _dbRef.child('devices/$_carID/numbers').get().then((snapshot) {
        if (snapshot.exists && snapshot.value != null) {
          var data = snapshot.value;
          setState(() {
            if (data is Map) {
              _n1.text = data['1']?.toString() ?? _n1.text;
              _n2.text = data['2']?.toString() ?? _n2.text;
              _n3.text = data['3']?.toString() ?? _n3.text;
            } else if (data is List) {
              if (data.length > 0) _n1.text = data[0]?.toString() ?? _n1.text;
              if (data.length > 1) _n2.text = data[1]?.toString() ?? _n2.text;
              if (data.length > 2) _n3.text = data[2]?.toString() ?? _n3.text;
            }
          });
        }
      });
    }
  }

  // منطق حفظ الإشعارات في الذاكرة
  void _saveNotificationsToDisk() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String encodedData = json.encode(_allNotifications);
    await prefs.setString('saved_notifs_$_carID', encodedData);
  }

  // منطق تحميل الإشعارات من الذاكرة
  void _loadNotificationsFromDisk() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedData = prefs.getString('saved_notifs_$_carID');
    if (savedData != null) {
      setState(() {
        _allNotifications = List<Map<String, String>>.from(
          json.decode(savedData).map((item) => Map<String, String>.from(item))
        );
      });
    }
  }

  void _setupNotifs() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notif.initialize(const InitializationSettings(android: androidInit));
  }

  void _listenToStatus() {
    _statusSub = _dbRef.child('devices/$_carID/responses').onValue.listen((event) {
      if (!mounted || event.snapshot.value == null) return;
      try {
        var data = event.snapshot.value;
        if (data is Map) {
          Map d = Map<dynamic, dynamic>.from(data);
          setState(() { _lastStatus = d['message'] ?? ""; });
          _handleResponse(d);
        }
      } catch (e) {
        print("❌ Error listening to status: $e");
      }
    });
  }

  void _handleResponse(Map d) async {
    String type = d['type'] ?? '';
    String msg = d['message'] ?? '';
    
    // إضافة الإشعار للقائمة وحفظه في الذاكرة
    setState(() {
      _allNotifications.insert(0, {
        'type': type,
        'message': msg,
        'time': "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
        'lat': d['lat']?.toString() ?? "",
        'lng': d['lng']?.toString() ?? "",
      });
      _saveNotificationsToDisk();
    });

    await _audioPlayer.stop();
    await _audioPlayer.play(AssetSource(type == 'alert' ? 'sounds/alarm.mp3' : 'sounds/notification.mp3'));
    
    await _notif.show(1, type == 'alert' ? "🚨 تنبيه أمني" : "ℹ️ تحديث HASBA", msg, const NotificationDetails(android: AndroidNotificationDetails('high_channel', 'تنبيهات', importance: Importance.max, priority: Priority.high)));
    
    if (mounted && !_isDialogShowing) _showSimpleDialog(type, msg, d);
  }

  void _showSimpleDialog(String type, String msg, Map d) {
    _isDialogShowing = true;
    showDialog(context: context, barrierDismissible: false, builder: (c) => AlertDialog(
      title: Text(type == 'alert' ? "🚨 تحذير" : "ℹ️ إشعار"),
      content: Text(msg),
      actions: [
        if (d['lat'] != null) ElevatedButton(onPressed: () => launchUrl(Uri.parse("https://www.google.com/maps/search/?api=1&query=${d['lat']},${d['lng']}")), child: const Text("فتح الخريطة")),
        TextButton(onPressed: () { _isDialogShowing = false; Navigator.pop(c); }, child: const Text("موافق")),
      ],
    )).then((_) => _isDialogShowing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("تحكم السيارة (${_carID ?? ''})"),
        backgroundColor: Colors.blue.shade900,
        leading: IconButton(icon: const Icon(Icons.exit_to_app), onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AppTypeSelector()))),
        actions: [
          // أيقونة الجرس مع عداد الإشعارات
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_active, color: Colors.white),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => NotificationInboxPage(
                    notifications: _allNotifications,
                    onDelete: (index) {
                      setState(() { _allNotifications.removeAt(index); _saveNotificationsToDisk(); });
                    },
                    onClearAll: () {
                      setState(() { _allNotifications.clear(); _saveNotificationsToDisk(); });
                    },
                  )));
                },
              ),
              if (_allNotifications.isNotEmpty)
                Positioned(
                  right: 8, top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text('${_allNotifications.length}', style: const TextStyle(color: Colors.white, fontSize: 10), textAlign: TextAlign.center),
                  ),
                )
            ],
          )
        ],
      ),
      body: _carID == null 
          ? const Center(child: CircularProgressIndicator()) 
          : SingleChildScrollView(
              child: Column(
                children: [
                  _statusWidget(),
                  _sensitivityStreamWidget(),
                  _numbersWidget(),
                  _actionsWidget(),
                ],
              ),
            ),
    );
  }

  Widget _statusWidget() => InkWell(
    onTap: () {
      Navigator.push(context, MaterialPageRoute(builder: (context) => NotificationInboxPage(
        notifications: _allNotifications,
        onDelete: (index) { setState(() { _allNotifications.removeAt(index); _saveNotificationsToDisk(); }); },
        onClearAll: () { setState(() { _allNotifications.clear(); _saveNotificationsToDisk(); }); },
      )));
    },
    child: Container(
      padding: const EdgeInsets.all(20), margin: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 10)]),
      child: Row(children: [
        const Icon(Icons.history, color: Colors.blue), 
        const SizedBox(width: 15), 
        Expanded(child: Text(_lastStatus, style: const TextStyle(fontWeight: FontWeight.bold))),
        const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      ]),
    ),
  );

  // --- الحفاظ على باقي الودجت كما هي في كودك الأصلي ---
  Widget _sensitivityStreamWidget() => StreamBuilder(
    stream: _dbRef.child('devices/$_carID/sensitivity').onValue,
    builder: (context, snapshot) {
      const List<int> sensitivityLevels = [5, 6, 7, 8, 9, 10, 15, 20, 25, 30, 35, 40, 45, 50, 60, 70, 80, 90, 100];
      int currentVal = 20;
      if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
        currentVal = int.parse(snapshot.data!.snapshot.value.toString());
      }
      void updateSensitivity(bool increase) {
        int currentIndex = sensitivityLevels.indexOf(currentVal);
        if (increase && currentIndex < sensitivityLevels.length - 1) {
          _dbRef.child('devices/$_carID/sensitivity').set(sensitivityLevels[currentIndex + 1]);
        } else if (!increase && currentIndex > 0) {
          _dbRef.child('devices/$_carID/sensitivity').set(sensitivityLevels[currentIndex - 1]);
        }
      }
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 15),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(children: [
            const Text("🎚️ حساسية الاهتزاز", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red, size: 35), onPressed: () => updateSensitivity(false)),
              Text("$currentVal", style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.add_circle, color: Colors.green, size: 35), onPressed: () => updateSensitivity(true)),
            ])
          ]),
        ),
      );
    }
  );

  Widget _numbersWidget() {
    return Card(
      margin: const EdgeInsets.all(15),
      child: ExpansionTile(
        key: GlobalKey(),
        initiallyExpanded: _isExpanded,
        onExpansionChanged: (val) => setState(() => _isExpanded = val),
        title: const Text("📞 أرقام الطوارئ المحفوظة"),
        children: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(children: [
              TextField(controller: _n1, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "رقم 1", prefixIcon: Icon(Icons.phone))),
              TextField(controller: _n2, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "رقم 2", prefixIcon: Icon(Icons.phone))),
              TextField(controller: _n3, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "رقم 3", prefixIcon: Icon(Icons.phone))),
              const SizedBox(height: 15),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, minimumSize: const Size(double.infinity, 50)),
                icon: const Icon(Icons.save, color: Colors.white),
                onPressed: () async {
                  await _dbRef.child('devices/$_carID/numbers').set({'1': _n1.text, '2': _n2.text, '3': _n3.text});
                  SharedPreferences prefs = await SharedPreferences.getInstance();
                  await prefs.setString('num1_$_carID', _n1.text);
                  await prefs.setString('num2_$_carID', _n2.text);
                  await prefs.setString('num3_$_carID', _n3.text);
                  setState(() { _isExpanded = false; });
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ تم الحفظ بنجاح")));
                }, 
                label: const Text("حفظ وتعديل", style: TextStyle(color: Colors.white)),
              ),
            ]),
          )
        ],
      ),
    );
  }

  Widget _actionsWidget() => Column(
    children: [
      StreamBuilder(
        stream: _dbRef.child('devices/$_carID/vibration_enabled').onValue,
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
          bool isVibeOn = true;
          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            isVibeOn = snapshot.data!.snapshot.value as bool;
          }
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: isVibeOn ? Colors.redAccent : Colors.green, minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              icon: Icon(isVibeOn ? Icons.vibration_outlined : Icons.vibration, color: Colors.white),
              label: Text(isVibeOn ? "إيقاف نظام الاهتزاز" : "تشغيل نظام الاهتزاز", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              onPressed: () => _dbRef.child('devices/$_carID/vibration_enabled').set(!isVibeOn),
            ),
          );
        },
      ),
      StreamBuilder(
        stream: _dbRef.child('devices/$_carID/system_active_status').onValue,
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
          bool isSystemOn = false;
          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            isSystemOn = snapshot.data!.snapshot.value as bool;
          }
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: isSystemOn ? Colors.orange.shade800 : Colors.blue.shade600, minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              icon: Icon(isSystemOn ? Icons.shield_outlined : Icons.shield, color: Colors.white),
              label: Text(isSystemOn ? "إيقاف نظام الحماية" : "تشغيل نظام الحماية", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              onPressed: () {
                int commandId = isSystemOn ? 6 : 7;
                _dbRef.child('devices/$_carID/commands').set({'id': commandId, 'timestamp': ServerValue.timestamp});
              },
            ),
          );
        },
      ),
      GridView.count(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, padding: const EdgeInsets.all(15), mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.2,
        children: [
          _actionBtn(1, "تتبع الموقع", Icons.map, Colors.blue),
          _actionBtn(2, "حالة البطارية", Icons.battery_charging_full, Colors.green),
          _actionBtn(5, "اتصال بالسيارة", Icons.phone_forwarded, Colors.teal),
          _actionBtn(8, "إعادة تشغيل", Icons.power_settings_new, Colors.redAccent),
        ],
      ),
    ],
  );

  Widget _actionBtn(int id, String l, IconData i, Color c) => Card(
    child: InkWell(
      onTap: () => _dbRef.child('devices/$_carID/commands').set({'id': id, 'timestamp': ServerValue.timestamp}),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(i, color: c, size: 40), const SizedBox(height: 5), Text(l, textAlign: TextAlign.center)]),
    ),
  );

  @override
  void dispose() { 
    _statusSub?.cancel(); 
    _n1.dispose(); _n2.dispose(); _n3.dispose();
    _audioPlayer.dispose(); 
    super.dispose(); 
  }
}

// ############################################################
// صفحة صندوق الإشعارات المطورة (البحث والفلترة)
// ############################################################
class NotificationInboxPage extends StatefulWidget {
  final List<Map<String, String>> notifications;
  final VoidCallback onClearAll;
  final Function(int) onDelete;

  const NotificationInboxPage({
    super.key,
    required this.notifications,
    required this.onClearAll,
    required this.onDelete,
  });

  @override
  State<NotificationInboxPage> createState() => _NotificationInboxPageState();
}

class _NotificationInboxPageState extends State<NotificationInboxPage> {
  String _searchQuery = "";
  String _filterType = "الكل";

  @override
  Widget build(BuildContext context) {
    final filteredList = widget.notifications.where((notif) {
      final matchesSearch = notif['message']!.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesFilter = _filterType == "الكل" || notif['type'] == _filterType;
      return matchesSearch && matchesFilter;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("صندوق الإشعارات"),
        backgroundColor: Colors.blue.shade900,
        actions: [
          IconButton(icon: const Icon(Icons.delete_sweep), onPressed: widget.onClearAll),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              decoration: InputDecoration(
                hintText: "بحث في التنبيهات...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                filled: true, fillColor: Colors.grey.shade100,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip("الكل"),
                _filterChip("alert", label: "تنبيهات خطيرة"),
                _filterChip("status", label: "حالات النظام"),
                _filterChip("location", label: "مواقع"),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: filteredList.isEmpty
                ? const Center(child: Text("لا توجد إشعارات تطابق بحثك"))
                : ListView.builder(
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final item = filteredList[index];
                      bool isAlert = item['type'] == 'alert';
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        shape: RoundedRectangleBorder(
                          side: isAlert ? const BorderSide(color: Colors.red, width: 1) : BorderSide.none,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isAlert ? Colors.red.shade100 : Colors.blue.shade100,
                            child: Icon(isAlert ? Icons.warning : Icons.info, color: isAlert ? Colors.red : Colors.blue),
                          ),
                          title: Text(item['message'] ?? "", style: TextStyle(fontWeight: isAlert ? FontWeight.bold : FontWeight.normal)),
                          subtitle: Text(item['time'] ?? ""),
                          onTap: () {
                            if (item['lat'] != "" && item['lat'] != "null") {
                              launchUrl(Uri.parse("https://www.google.com/maps/search/?api=1&query=${item['lat']},${item['lng']}"));
                            }
                          },
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () {
                              int originalIndex = widget.notifications.indexOf(item);
                              widget.onDelete(originalIndex);
                              setState(() {});
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String type, {String? label}) {
    bool isSelected = _filterType == type;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: ChoiceChip(
        label: Text(label ?? type),
        selected: isSelected,
        onSelected: (s) => setState(() => _filterType = s ? type : "الكل"),
        selectedColor: Colors.blue.shade900,
        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
      ),
    );
  }
}