import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong2.dart'; // مكتبتك الحالية
import 'package:sizer/sizer.dart'; // مكتبتك الحالية للتنسيق

class DeliveryManagementScreen extends StatefulWidget {
  const DeliveryManagementScreen({super.key});

  @override
  State<DeliveryManagementScreen> createState() => _DeliveryManagementScreenState();
}

class _DeliveryManagementScreenState extends State<DeliveryManagementScreen> {
  String? role;
  List<String> myAreas = [];
  Map<String, dynamic>? geoJsonData;
  List<Map<String, dynamic>> myReps = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      await _loadGeoJson();
      await _getUserData();
    } catch (e) {
      debugPrint("Error initializing: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // تحميل ملف الـ GeoJSON (يجب أن يكون في مجلد assets بنفس الاسم)
  Future<void> _loadGeoJson() async {
    final String response = await rootBundle.loadString(
        'assets/OSMB-bc319d822a17aa9ad1089fc05e7d4e752460f877.geojson');
    geoJsonData = json.decode(response);
  }

  Future<void> _getUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('managers')
        .where('uid', '==', user.uid)
        .get();

    if (snap.docs.isNotEmpty) {
      var data = snap.docs.first.data();
      role = data['role']; // 'delivery_manager' أو 'delivery_supervisor'
      myAreas = List<String>.from(data['geographicArea'] ?? []);
      
      // جلب المناديب التابعين للمشرف فقط
      if (data['reps'] != null) {
        for (String repId in data['reps']) {
          var repDoc = await FirebaseFirestore.instance.collection('deliveryReps').doc(repId).get();
          if (repDoc.exists) {
            myReps.add({
              'id': repDoc.id, 
              'fullname': repDoc['fullname'], 
              'repCode': repDoc['repCode']
            });
          }
        }
      }
    }
  }

  // خوارزمية التحقق الجغرافي (نفس منطق الـ HTML)
  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    var lat = point.latitude;
    var lng = point.longitude;
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      var xi = polygon[i].latitude, yi = polygon[i].longitude;
      var xj = polygon[j].latitude, yj = polygon[j].longitude;
      var intersect = ((yi > lng) != (yj > lng)) &&
          (lat < (xj - xi) * (lng - yi) / (yj - yi) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  bool _isOrderInMyArea(Map<String, dynamic> locationData) {
    if (role == 'delivery_manager') return true; // المدير يرى الكل
    if (geoJsonData == null || myAreas.isEmpty) return false;

    LatLng orderPoint = LatLng(locationData['lat'].toDouble(), locationData['lng'].toDouble());

    for (var areaName in myAreas) {
      var feature = geoJsonData!['features'].firstWhere(
          (f) => f['properties']['name'] == areaName, orElse: () => null);

      if (feature != null) {
        List coords = feature['geometry']['coordinates'][0];
        List<LatLng> polygon = coords.map<LatLng>((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
        if (_isPointInPolygon(orderPoint, polygon)) return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(role == 'delivery_manager' ? "إدارة طلبات المدير" : "طلبات المشرف - جغرافياً"),
        centerTitle: true,
      ),
      body: isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('orders').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                // فلترة الطلبات بناءً على الدور والمنطقة الجغرافية والحالة
                var filteredOrders = snapshot.data!.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  if (role == 'delivery_manager') {
                    return data['status'] == 'new-order';
                  } else if (role == 'delivery_supervisor') {
                    return data['status'] == 'awaiting-delivery-assignment' && 
                           _isOrderInMyArea(data['buyer']['location']);
                  }
                  return false;
                }).toList();

                if (filteredOrders.isEmpty) {
                  return const Center(child: Text("لا توجد طلبات حالياً"));
                }

                return ListView.builder(
                  itemCount: filteredOrders.length,
                  itemBuilder: (context, index) {
                    var order = filteredOrders[index].data() as Map<String, dynamic>;
                    var orderId = filteredOrders[index].id;

                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: Padding(
                        padding: EdgeInsets.all(15.sp),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("طلب رقم: ${orderId.substring(0, 5)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp)),
                                Text("${order['total']} ج.م", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12.sp)),
                              ],
                            ),
                            const Divider(),
                            Text("العميل: ${order['buyer']['name']}"),
                            Text("العنوان: ${order['buyer']['address']}"),
                            SizedBox(height: 2.h),
                            
                            if (role == 'delivery_manager')
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.send),
                                  label: const Text("نقل للتوصيل"),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                                  onPressed: () => _managerMoveToDelivery(orderId),
                                ),
                              ),

                            if (role == 'delivery_supervisor')
                              _buildSupervisorAction(orderId, order),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  // زر المدير: نقل الطلب للمشرفين
  Future<void> _managerMoveToDelivery(String id) async {
    await FirebaseFirestore.instance.collection('orders').doc(id).update({
      'deliveryManagerAssigned': true,
      'status': 'awaiting-delivery-assignment'
    });
  }

  // واجهة المشرف: اختيار المندوب
  Widget _buildSupervisorAction(String orderId, Map<String, dynamic> orderData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("إسناد لمندوب تحصيل:", style: TextStyle(fontWeight: FontWeight.bold)),
        DropdownButton<String>(
          isExpanded: true,
          hint: const Text("اختر مندوب من فريقك"),
          items: myReps.map((rep) {
            return DropdownMenuItem(value: rep['repCode'], child: Text(rep['fullname']));
          }).toList(),
          onChanged: (val) async {
            var selectedRep = myReps.firstWhere((r) => r['repCode'] == val);
            await _assignToRep(orderId, orderData, selectedRep);
          },
        ),
      ],
    );
  }

  Future<void> _assignToRep(String id, Map<String, dynamic> data, Map rep) async {
    await FirebaseFirestore.instance.collection('orders').doc(id).update({
      'deliveryRepId': rep['repCode'],
      'repName': rep['fullname'],
      'status': 'assigned-to-rep'
    });
    // رفعه لمجموعة الانتظار ليظهر فوراً في تطبيق المندوب المختارة
    await FirebaseFirestore.instance.collection('waitingdelivery').doc(id).set(data);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("تم الإسناد للمندوب ${rep['fullname']}")));
    }
  }
}

