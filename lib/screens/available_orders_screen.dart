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

  // 1. تجهيز البيانات: الموقع ونوع المركبة المحفوظ
  Future<void> _prepareData() async {
    final prefs = await SharedPreferences.getInstance();
    _myVehicle = prefs.getString('user_vehicle_config') ?? 'motorcycleConfig';

    try {
      // سحب الموقع مرة واحدة للفلترة
      Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
          _myCurrentLocation = pos;
          _isGettingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isGettingLocation = false);
      print("خطأ في جلب الموقع: $e");
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
        // 2. الفلترة: حالة الطلب + نوع المركبة
        stream: FirebaseFirestore.instance
            .collection('specialRequests')
            .where('status', isEqualTo: 'pending')
            .where('vehicleTypeNeeded', isEqualTo: _myVehicle) // الفلترة بالمركبة
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final allOrders = snapshot.data!.docs;

          // 3. فلترة المسافة (اختياري: عرض الطلبات في محيط 10 كم مثلاً)
          final nearbyOrders = allOrders.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            if (data['pickupLat'] == null || _myCurrentLocation == null) return true;
            
            double distanceInMeters = Geolocator.distanceBetween(
              _myCurrentLocation!.latitude, _myCurrentLocation!.longitude,
              data['pickupLat'], data['pickupLng']
            );
            return distanceInMeters <= 10000; // 10 كيلومتر
          }).toList();

          if (nearbyOrders.isEmpty) {
            return Center(child: Text("لا توجد طلبات تناسب مركبتك حالياً", style: TextStyle(fontSize: 14.sp)));
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

  // 4. المعاملة الذرية (Transaction) لقبول الطلب
  Future<void> _acceptOrder(BuildContext context, String orderId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // إظهار مؤشر تحميل
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));

    final orderRef = FirebaseFirestore.instance.collection('specialRequests').doc(orderId);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(orderRef);

        if (!snapshot.exists) throw "الطلب غير موجود!";
        
        String status = snapshot.get('status');
        if (status != 'pending') throw "عذراً، هذا الطلب سبقه إليك مندوب آخر!";

        // تحديث الطلب ليصبح محجوزاً لهذا المندوب
        transaction.update(orderRef, {
          'status': 'accepted',
          'driverId': uid,
          'acceptedAt': FieldValue.serverTimestamp(),
        });
      });

      Navigator.pop(context); // إغلاق التحميل
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text("مبروك! تم حجز الطلب لك")));
      
      // هنا نقوم بتوجيه المندوب لشاشة تتبع الطلب النشط
      // Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => ActiveOrderMapScreen(orderId: orderId)));

    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(e.toString())));
    }
  }

  Widget _buildOrderCard(BuildContext context, String id, Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
            _infoRow(Icons.store, "المحل: ${data['supermarketName'] ?? 'غير محدد'}"),
            _infoRow(Icons.location_on, "من: ${data['pickupAddress']}"),
            _infoRow(Icons.flag, "إلى: ${data['dropoffAddress']}"),
            const SizedBox(height: 15),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
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
    if (data['pickupLat'] == null || _myCurrentLocation == null) return "??";
    double dist = Geolocator.distanceBetween(
      _myCurrentLocation!.latitude, _myCurrentLocation!.longitude,
      data['pickupLat'], data['pickupLng']
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
          Expanded(child: Text(text, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
