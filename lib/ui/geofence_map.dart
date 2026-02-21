import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';

class GeofencePage extends StatefulWidget {
  final String carID;
  const GeofencePage({super.key, required this.carID});

  @override
  _GeofencePageState createState() => _GeofencePageState();
}

class _GeofencePageState extends State<GeofencePage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  GoogleMapController? _mapController;
  LatLng _center = const LatLng(0, 0);
  double _radius = 500.0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentGeofence();
  }

  void _loadCurrentGeofence() async {
    final snap = await _dbRef.child('devices/${widget.carID}/geofence').get();
    if (snap.exists) {
      var data = snap.value as Map;
      setState(() {
        _center = LatLng(double.parse(data['lat'].toString()), double.parse(data['lng'].toString()));
        _radius = double.parse(data['radius'].toString());
        _loading = false;
      });
    } else {
      // إذا لم يوجد سياج، جلب آخر موقع للسيارة كمركز افتراضي
      final locSnap = await _dbRef.child('devices/${widget.carID}/responses').get();
      if (locSnap.exists) {
        var d = locSnap.value as Map;
        _center = LatLng(double.parse(d['lat'].toString()), double.parse(d['lng'].toString()));
      }
      setState(() => _loading = false);
    }
  }

  void _save() {
    _dbRef.child('devices/${widget.carID}/geofence').set({
      'lat': _center.latitude,
      'lng': _center.longitude,
      'radius': _radius.toInt(),
    });
    _dbRef.child('devices/${widget.carID}/geofence_radius').set(_radius.toInt());
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم حفظ نطاق الأمان بنجاح")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("تحديد دائرة الحماية"), backgroundColor: Colors.blue.shade900),
      body: _loading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Expanded(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(target: _center, zoom: 12),
                  onMapCreated: (c) => _mapController = c,
                  onTap: (pos) => setState(() => _center = pos),
                  markers: {Marker(markerId: const MarkerId("center"), position: _center)},
                  circles: {
                    Circle(
                      circleId: const CircleId("zone"),
                      center: _center,
                      radius: _radius,
                      fillColor: Colors.blue.withOpacity(0.2),
                      strokeColor: Colors.blue,
                      strokeWidth: 2,
                    )
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      "المسافة المسموحة: ${(_radius / 1000).toStringAsFixed(1)} كم",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Slider(
                      value: _radius,
                      min: 100,
                      max: 100000, // تم التعديل إلى 100 كيلومتر
                      divisions: 200,
                      onChanged: (v) => setState(() => _radius = v),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade900,
                        minimumSize: const Size(double.infinity, 50)
                      ),
                      onPressed: _save,
                      child: const Text("حفظ الإعدادات", style: TextStyle(color: Colors.white)),
                    )
                  ],
                ),
              )
            ],
          ),
    );
  }
}