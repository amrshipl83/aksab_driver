import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sizer/sizer.dart';

class TodayTasksScreen extends StatefulWidget {
  final String repCode; // كود المندوب المستخرج من بيانات المستخدم

  const TodayTasksScreen({super.key, required this.repCode});

  @override
  State<TodayTasksScreen> createState() => _TodayTasksScreenState();
}

class _TodayTasksScreenState extends State<TodayTasksScreen> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text("مهام اليوم"),
        centerTitle: true,
        backgroundColor: const Color(0xFF007BFF),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // نفس الـ Query المستخدم في الـ HTML
        stream: FirebaseFirestore.instance
            .collection('waitingdelivery')
            .where('repCode', isEqualTo: widget.repCode)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: EdgeInsets.all(12.sp),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var order = doc.data() as Map<String, dynamic>;
              return _buildTaskCard(doc.id, order);
            },
          );
        },
      ),
    );
  }

  Widget _buildTaskCard(String docId, Map<String, dynamic> order) {
    final buyer = order['buyer'] ?? {};
    final total = (order['total'] ?? 0.0).toDouble();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.only(bottom: 15.sp),
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(15.sp),
        child: Column(
          children: [
            _rowInfo("العميل:", buyer['name'] ?? "-"),
            _rowInfo("الهاتف:", buyer['phone'] ?? "-"),
            _rowInfo("العنوان:", buyer['address'] ?? "غير محدد"),
            _rowInfo("الإجمالي:", "${total.toStringAsFixed(2)} ج.م", isTotal: true),
            SizedBox(height: 15.sp),
            
            _isProcessing 
            ? const LinearProgressIndicator()
            : Row(
              children: [
                _actionBtn("تم التسليم", Colors.green, Icons.check_circle, 
                   () => _updateStatus(docId, order, 'delivered')),
                SizedBox(width: 8.sp),
                _actionBtn("فشل", Colors.red, Icons.cancel, 
                   () => _updateStatus(docId, order, 'failed')),
              ],
            )
          ],
        ),
      ),
    );
  }

  // الدالة الأساسية: مطابقة لمنطق الـ HTML (Add + Delete)
  Future<void> _updateStatus(String docId, Map<String, dynamic> orderData, String status) async {
    setState(() => _isProcessing = true);

    try {
      // 1. تحديد المجموعة المستهدفة كما في الـ HTML
      String targetCollection = (status == 'delivered') ? "deliveredorders" : "falseorder";

      WriteBatch batch = FirebaseFirestore.instance.batch();

      // مرجع المكان القديم (waitingdelivery)
      DocumentReference oldRef = FirebaseFirestore.instance.collection('waitingdelivery').doc(docId);
      
      // مرجع المكان الجديد
      DocumentReference newRef = FirebaseFirestore.instance.collection(targetCollection).doc(docId);

      // 2. تجهيز البيانات مع إضافة حقول التسوية (التي سنحتاجها في كود المشرف)
      Map<String, dynamic> finalData = Map.from(orderData);
      finalData['status'] = status;
      finalData['timestamp'] = FieldValue.serverTimestamp();
      finalData['handledByRepId'] = widget.repCode;
      
      // الحقل السحري لربط التسوية المالية
      finalData['isSettled'] = false; 

      // 3. تنفيذ النقل (إضافة ثم حذف)
      batch.set(newRef, finalData);
      batch.delete(oldRef);

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(status == 'delivered' ? "تم التسليم بنجاح ✅" : "تم تسجيل فشل الطلب ❌"))
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Widget _rowInfo(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.sp),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700])),
          Expanded(child: Text(value, textAlign: TextAlign.end, 
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.blue[800] : Colors.black,
              fontSize: isTotal ? 12.sp : 10.sp
            ))),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, Color color, IconData icon, VoidCallback onPressed) {
    return Expanded(
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
        onPressed: onPressed,
        icon: Icon(icon, size: 14.sp),
        label: Text(label, style: TextStyle(fontSize: 9.sp)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.task_alt, size: 50.sp, color: Colors.grey),
          SizedBox(height: 10.sp),
          const Text("لا توجد مهام حالياً", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

