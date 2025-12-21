import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sizer/sizer.dart';

class AvailableOrdersScreen extends StatefulWidget {
  const AvailableOrdersScreen({super.key});

  @override
  State<AvailableOrdersScreen> createState() => _AvailableOrdersScreenState();
}

class _AvailableOrdersScreenState extends State<AvailableOrdersScreen> {
  String? _myVehicle;
  Position? _myCurrentLocation;
  bool _isGettingLocation = true;

  @override
  void initState() {
    super.initState();
    _prepareData();
  }

  Future<void> _prepareData() async {
    final prefs = await SharedPreferences.getInstance();
    // جلب القيمة المخزنة: motorcycleConfig أو jumboConfig
    String savedConfig = prefs.getString('user_vehicle_config') ?? 'motorcycleConfig';
    
    // تحويل القيمة لتطابق الموجود في Firestore (motorcycle أو jumbo)
    setState(() {
      _myVehicle = savedConfig == 'motorcycleConfig' ? 'motorcycle' : 'jumbo';
    });

    try {
      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
          _myCurrentLocation = pos;
          _isGettingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isGettingLocation) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text("الرادار - طلبات تناسبك", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // الفلترة بناءً على الحقول الفعلية في الـ Database الخاصة بك
        stream: FirebaseFirestore.instance
            .collection('specialRequests')
            .where('status', isEqualTo: 'pending')
            .where('vehicleType', isEqualTo: _myVehicle) 
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;

          // فلترة المسافة باستخدام GeoPoint
          final nearbyOrders = docs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            GeoPoint? pickupLocation = data['pickupLocation']; // الحقل كما في صورتك
            
            if (pickupLocation == null || _myCurrentLocation == null) return true;

            double distanceInMeters = Geolocator.distanceBetween(
              _myCurrentLocation!.latitude, _myCurrentLocation!.longitude,
              pickupLocation.latitude, pickupLocation.longitude
            );
            return distanceInMeters <= 15000; // نطاق 15 كم
          }).toList();

          if (nearbyOrders.isEmpty) {
            return Center(child: Text("لا توجد طلبات تناسبك حالياً", style: TextStyle(fontSize: 14.sp)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: nearbyOrders.length,
            itemBuilder: (context, index) => _buildOrderCard(
                context, nearbyOrders[index].id, nearbyOrders[index].data() as Map<String, dynamic>),
          );
        },
      ),
    );
  }

  // المعاملة الذرية لقبول الطلب
  Future<void> _acceptOrder(BuildContext context, String orderId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));

    final orderRef = FirebaseFirestore.instance.collection('specialRequests').doc(orderId);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(orderRef);
        if (!snapshot.exists) throw "الطلب غير موجود!";
        if (snapshot.get('status') != 'pending') throw "سبقك مندوب آخر لهذا الطلب!";

        transaction.update(orderRef, {
          'status': 'accepted',
          'driverId': uid,
          'acceptedAt': FieldValue.serverTimestamp(),
        });
      });

      Navigator.pop(context); // إغلاق التحميل
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text("تم قبول الطلب! اذهب للاستلام")));

    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(e.toString())));
    }
  }

  Widget _buildOrderCard(BuildContext context, String id, Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("المسافة: ${_calculateDistance(data)} كم", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                Text("${data['price']} ج.م", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, color: Colors.orange[900])),
              ],
            ),
            const Divider(),
            _infoRow(Icons.shopping_bag, "التفاصيل: ${data['details'] ?? 'بدون وصف'}"),
            _infoRow(Icons.location_on, "من: ${data['pickupAddress'] ?? 'عنوان الاستلام'}"),
            _infoRow(Icons.flag, "إلى: ${data['dropoffAddress'] ?? 'عنوان التوصيل'}"),
            const SizedBox(height: 15),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[800],
                minimumSize: Size(100.w, 7.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              onPressed: () => _acceptOrder(context, id),
              child: Text("قبول وتوصيل الطلب", style: TextStyle(fontSize: 14.sp, color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  String _calculateDistance(Map<String, dynamic> data) {
    GeoPoint? pickup = data['pickupLocation'];
    if (pickup == null || _myCurrentLocation == null) return "??";
    double dist = Geolocator.distanceBetween(
      _myCurrentLocation!.latitude, _myCurrentLocation!.longitude,
      pickup.latitude, pickup.longitude
    );
    return (dist / 1000).toStringAsFixed(1);
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18.sp, color: Colors.orange[800]),
          const SizedBox(width: 10),
          Expanded(child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
