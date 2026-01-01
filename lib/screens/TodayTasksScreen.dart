import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sizer/sizer.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

  @override
  void initState() {
    super.initState();
    _loadRepCode();
  }

  Future<void> _loadRepCode() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // البحث عن المندوب باستخدام الـ UID الخاص به لجلب الـ repCode
    final doc = await FirebaseFirestore.instance.collection('deliveryReps').doc(uid).get();
    if (doc.exists) {
      if (mounted) {
        setState(() {
          _repCode = doc.data()?['repCode'];
          _isLoadingRep = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoadingRep = false);
    }
  }

  void _showRouteMap(Map customerLoc, String address) {
    // إحداثيات افتراضية للمندوب (يمكنك جلبها لاحقاً من الـ GPS اللحظي)
    LatLng agentPos = const LatLng(31.2001, 29.9187); // إحداثيات في الإسكندرية كمثال
    LatLng customerPos = LatLng(customerLoc['lat'], customerLoc['lng']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        height: 85.h,
        padding: EdgeInsets.all(10.sp),
        child: Column(
          children: [
            Text("مسار التوصيل", style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
            SizedBox(height: 10.sp),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: agentPos,
                    initialZoom: 13,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/{z}/{x}/{y}?access_token=$_mapboxToken',
                      additionalOptions: {'accessToken': _mapboxToken},
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(point: agentPos, child: const Icon(Icons.my_location, color: Colors.blue, size: 30)),
                        Marker(point: customerPos, child: const Icon(Icons.location_on, color: Colors.red, size: 35)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            _buildRouteDetails(address),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteDetails(String address) {
    return Container(
      padding: EdgeInsets.all(15.sp),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.directions_car, color: Colors.green),
              SizedBox(width: 10.sp),
              Expanded(child: Text("العنوان: $address", style: TextStyle(fontSize: 12.sp))),
            ],
          ),
          SizedBox(height: 15.sp),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], minimumSize: Size(100.w, 6.h)),
            child: const Text("إغلاق الخريطة", style: TextStyle(color: Colors.white)),
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
                  // تم التعديل هنا: البحث بـ deliveryRepId ليتطابق مع ما يرفعه المشرف
                  stream: FirebaseFirestore.instance
                      .collection('waitingdelivery')
                      .where('deliveryRepId', isEqualTo: _repCode)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text("لا توجد مهام مسندة إليك اليوم"));
                    }

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
      margin: EdgeInsets.only(bottom: 15.sp),
      child: Padding(
        padding: EdgeInsets.all(12.sp),
        child: Column(
          children: [
            _rowInfo("العميل", buyer['name'] ?? "-"),
            _rowInfo("العنوان", buyer['address'] ?? "-"),
            _rowInfo("الإجمالي", "${(data['total'] ?? 0).toStringAsFixed(2)} ج.م", isTotal: true),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _actionBtn(Icons.map, "المسار", Colors.grey[800]!, () => _showRouteMap(buyer['location'], buyer['address'] ?? "بدون عنوان")),
                _actionBtn(Icons.check_circle, "تم التسليم", Colors.green, () => _handleStatus(docId, data, 'delivered')),
                _actionBtn(Icons.cancel, "فشل", Colors.red, () => _handleStatus(docId, data, 'failed')),
              ],
            )
          ],
        ),
      ),
    );
  }

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
      icon: Icon(icon, color: color, size: 18.sp),
      label: Text(label, style: TextStyle(color: color, fontSize: 11.sp, fontWeight: FontWeight.bold)),
    );
  }

  Future<void> _handleStatus(String docId, Map<String, dynamic> data, String status) async {
    String targetColl = (status == 'delivered') ? 'deliveredorders' : 'falseorder';
    try {
      // 1. رفع الطلب للمجموعة النهائية (تم التسليم أو فشل)
      await FirebaseFirestore.instance.collection(targetColl).doc(docId).set({
        ...data,
        'status': status,
        'finishedAt': FieldValue.serverTimestamp(),
        'handledByRepId': _repCode
      });

      // 2. تحديث الطلب الأصلي في مجموعة orders لمتابعة الحالة من قبل المدير
      await FirebaseFirestore.instance.collection('orders').doc(docId).update({
        'status': status,
        'deliveryFinishedAt': FieldValue.serverTimestamp(),
      });

      // 3. مسح الطلب من المهام اليومية (waitingdelivery)
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

