import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sizer/sizer.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart'; // يحتاج إضافة geolocator للمشروع
import 'package:url_launcher/url_launcher.dart'; // يحتاج إضافة url_launcher

class TodayTasksScreen extends StatefulWidget {
  const TodayTasksScreen({super.key});

  @override
  State<TodayTasksScreen> createState() => _TodayTasksScreenState();
}

class _TodayTasksScreenState extends State<TodayTasksScreen> {
  final String _mapboxToken = 'pk.eyJ1IjoiYW1yc2hpcGwiLCJhIjoiY21lajRweGdjMDB0eDJsczdiemdzdXV6biJ9.E--si9vOB93NGcAq7uVgGw';
  final String _lambdaUrl = 'https://2soi345n94.execute-api.us-east-1.amazonaws.com/Prode/';

  String? _repCode;
  bool _isLoadingRep = true;
  LatLng? _currentPosition; // لتخزين موقع المندوب الحي

  @override
  void initState() {
    super.initState();
    _loadRepCode();
    _determinePosition(); // جلب الموقع عند الفتح
  }

  // دالة جلب الموقع الحي للمندوب
  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    
    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });
  }

  Future<void> _loadRepCode() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('deliveryReps').doc(uid).get();
    if (doc.exists) {
      setState(() {
        _repCode = doc.data()?['repCode'];
        _isLoadingRep = false;
      });
    }
  }

  // دالة لجلب إحداثيات المسار من Mapbox ورسمها
  Future<List<LatLng>> _getRoutePolyline(LatLng start, LatLng end) async {
    final url = 'https://api.mapbox.com/directions/v5/mapbox/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?geometries=geojson&access_token=$_mapboxToken';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List coords = data['routes'][0]['geometry']['coordinates'];
      return coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
    }
    return [];
  }

  void _showRouteMap(Map customerLoc, String address) async {
    LatLng customerPos = LatLng(customerLoc['lat'], customerLoc['lng']);
    LatLng startPos = _currentPosition ?? const LatLng(31.2001, 29.9187); // افتراضي لو تعطل الـ GPS

    List<LatLng> routePoints = await _getRoutePolyline(startPos, customerPos);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        height: 85.h,
        padding: EdgeInsets.all(10.sp),
        child: Column(
          children: [
            Text("مسار التوصيل المباشر", style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
            SizedBox(height: 10.sp),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: FlutterMap(
                  options: MapOptions(initialCenter: startPos, initialZoom: 13),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/{z}/{x}/{y}?access_token=$_mapboxToken',
                    ),
                    if (routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(points: routePoints, color: Colors.blue, strokeWidth: 4),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        Marker(point: startPos, child: const Icon(Icons.my_location, color: Colors.blue, size: 30)),
                        Marker(point: customerPos, child: const Icon(Icons.location_on, color: Colors.red, size: 35)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            _buildRouteDetails(customerPos, address),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteDetails(LatLng dest, String address) {
    return Container(
      padding: EdgeInsets.all(12.sp),
      child: Column(
        children: [
          Text("العنوان: $address", style: TextStyle(fontSize: 11.sp), textAlign: TextAlign.center),
          SizedBox(height: 10.sp),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final url = 'https://www.google.com/maps/dir/?api=1&destination=${dest.latitude},${dest.longitude}';
                    if (await canLaunchUrl(Uri.parse(url))) await launchUrl(Uri.parse(url));
                  },
                  icon: const Icon(Icons.navigation, color: Colors.white),
                  label: const Text("توجيه (Google Maps)", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
                ),
              ),
              SizedBox(width: 5.w),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800]),
                  child: const Text("إغلاق", style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text("مهام اليوم"),
        centerTitle: true,
        backgroundColor: const Color(0xFF007BFF),
      ),
      body: _isLoadingRep
          ? const Center(child: CircularProgressIndicator())
          : _repCode == null
              ? const Center(child: Text("لم يتم العثور على بيانات المندوب"))
              : StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('waitingdelivery')
                      .where('deliveryRepId', isEqualTo: _repCode)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("لا توجد مهام حالياً"));

                    return ListView.builder(
                      padding: EdgeInsets.all(10.sp),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                        var docId = snapshot.data!.docs[index].id;
                        return _buildTaskCard(docId, data);
                      },
                    );
                  },
                ),
    );
  }

  Widget _buildTaskCard(String docId, Map<String, dynamic> data) {
    var buyer = data['buyer'] ?? {};
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.only(bottom: 12.sp),
      child: Padding(
        padding: EdgeInsets.all(12.sp),
        child: Column(
          children: [
            _rowInfo("العميل", buyer['name'] ?? "-"),
            _rowInfo("الإجمالي", "${(data['total'] ?? 0).toStringAsFixed(2)} ج.م", isTotal: true),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _actionBtn(Icons.map, "المسار", Colors.blue[900]!, () => _showRouteMap(buyer['location'], buyer['address'] ?? "")),
                _actionBtn(Icons.check_circle, "تسليم", Colors.green, () => _handleStatus(docId, data, 'delivered')),
                _actionBtn(Icons.cancel, "فشل", Colors.red, () => _handleStatus(docId, data, 'failed')),
              ],
            )
          ],
        ),
      ),
    );
  }

  // دوال _rowInfo و _actionBtn و _handleStatus و _sendNotification تظل كما هي في كودك السابق لضمان استقرار الباك إند
  Widget _rowInfo(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.sp),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600])),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: isTotal ? Colors.blue : Colors.black87)),
        ],
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: color, size: 16.sp),
      label: Text(label, style: TextStyle(color: color, fontSize: 10.sp, fontWeight: FontWeight.bold)),
    );
  }

  Future<void> _handleStatus(String docId, Map<String, dynamic> data, String status) async {
    String targetColl = (status == 'delivered') ? 'deliveredorders' : 'falseorder';
    try {
      await FirebaseFirestore.instance.collection(targetColl).doc(docId).set({
        ...data,
        'status': status,
        'finishedAt': FieldValue.serverTimestamp(),
        'handledByRepId': _repCode
      });
      await FirebaseFirestore.instance.collection('orders').doc(docId).update({
        'status': status,
        'deliveryFinishedAt': FieldValue.serverTimestamp(),
      });
      await FirebaseFirestore.instance.collection('waitingdelivery').doc(docId).delete();
      _sendNotification(status, data['buyer']?['name'] ?? "عميل");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم التحديث بنجاح ✅")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
    }
  }

  Future<void> _sendNotification(String status, String customerName) async {
    try {
      await http.post(
        Uri.parse(_lambdaUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "targetArn": "arn:aws:sns:us-east-1:32660558108:AksabNotification",
          "title": status == 'delivered' ? "تم التسليم بنجاح! ✅" : "فشل في التسليم ❌",
          "message": "المندوب قام بتحديث حالة طلب $customerName"
        }),
      );
    } catch (e) {
      debugPrint("Notification Error: $e");
    }
  }
}

