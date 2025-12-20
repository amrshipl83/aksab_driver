import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sizer/sizer.dart';

class AvailableOrdersScreen extends StatelessWidget {
  const AvailableOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text("الطلبات المتاحة للوصيل", 
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // الرادار: بنراقب أي طلب جديد في الـ collection اللي اتفقنا عليها
        stream: FirebaseFirestore.instance
            .collection('specialRequests')
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text("لا توجد طلبات جديدة حالياً", 
                style: TextStyle(fontSize: 14.sp, color: Colors.grey)),
            );
          }

          final orders = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final orderData = orders[index].data() as Map<String, dynamic>;
              final orderId = orders[index].id;

              return _buildOrderCard(context, orderId, orderData);
            },
          );
        },
      ),
    );
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("طلب توصيل جديد", 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp, color: Colors.green[800])),
                Text("${data['price']} ج.م", 
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15.sp, color: Colors.orange[900])),
              ],
            ),
            const Divider(height: 25),
            _infoRow(Icons.location_on, "من: ${data['pickupAddress']}"),
            _infoRow(Icons.flag, "إلى: ${data['dropoffAddress']}"),
            _infoRow(Icons.shopping_bag, "الوصف: ${data['details']}"),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _acceptOrder(context, id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[800],
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: Text("قبول الطلب وتغيير الحالة", 
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.sp)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 16.sp, color: Colors.grey[600]),
          const SizedBox(width: 10),
          Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, 
            style: TextStyle(fontSize: 11.sp))),
        ],
      ),
    );
  }

  void _acceptOrder(BuildContext context, String orderId) {
    // تحديث الحالة في قاعدة البيانات
    FirebaseFirestore.instance.collection('specialRequests').doc(orderId).update({
      'status': 'accepted',
      'driverId': 'current_driver_id', // سنضيف نظام الدخول لاحقاً
    }).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم قبول الطلب بنجاح!")));
    });
  }
}
