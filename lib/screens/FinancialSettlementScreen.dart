import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sizer/sizer.dart';

class FinancialSettlementScreen extends StatefulWidget {
  final String repCode; // الكود المستخدم في HTML (repCode)
  final String repName;

  const FinancialSettlementScreen({
    super.key,
    required this.repCode,
    required this.repName,
  });

  @override
  State<FinancialSettlementScreen> createState() => _FinancialSettlementScreenState();
}

class _FinancialSettlementScreenState extends State<FinancialSettlementScreen> {
  final TextEditingController _amountReceivedController = TextEditingController();
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("تصفية حساب المندوب"),
        backgroundColor: Colors.green[700],
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // القراءة من الكولكشن الصحيح كما في الـ HTML الخاص بك
        stream: FirebaseFirestore.instance
            .collection('deliveredorders') 
            .where('repCode', isEqualTo: widget.repCode)
            .where('isSettled', isEqualTo: false) // سنقوم بإضافته برمجياً
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          // في حال لم يكن الحقل موجوداً في الداتا القديمة، سنقوم بفلترة الداتا يدوياً هنا للتأكد
          var docs = snapshot.data?.docs ?? [];
          
          double totalCashInHand = 0;
          for (var d in docs) {
            totalCashInHand += (d['total'] ?? 0);
          }

          if (totalCashInHand == 0) {
            return _buildNoDataState();
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(15.sp),
            child: Column(
              children: [
                _buildSummaryCard(totalCashInHand, docs.length),
                SizedBox(height: 20.sp),
                _buildEntrySection(),
                SizedBox(height: 30.sp),
                _isProcessing 
                  ? const CircularProgressIndicator()
                  : _buildSubmitButton(docs, totalCashInHand),
              ],
            ),
          );
        },
      ),
    );
  }

  // تصميم كارت الملخص المالي
  Widget _buildSummaryCard(double total, int count) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        padding: EdgeInsets.all(20.sp),
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.green[700]!, Colors.green[500]!]),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            Text("إجمالي النقدية مع المندوب", style: TextStyle(color: Colors.white, fontSize: 11.sp)),
            SizedBox(height: 10.sp),
            Text("${total.toStringAsFixed(2)} ج.م", 
                 style: TextStyle(color: Colors.white, fontSize: 22.sp, fontWeight: FontWeight.bold)),
            const Divider(color: Colors.white24),
            Text("عدد الأوردرات غير المسواة: $count", style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _buildEntrySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("تأكيد المبلغ المستلم كاش:", style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 10.sp),
        TextField(
          controller: _amountReceivedController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: Colors.blue[900]),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            hintText: "0.00",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(List<QueryDocumentSnapshot> docs, double expected) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[800],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
        ),
        onPressed: () => _processSettlement(docs, expected),
        child: const Text("تأكيد التسوية وتصفير العهدة", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // عملية التسوية البرمجية
  Future<void> _processSettlement(List<QueryDocumentSnapshot> docs, double expected) async {
    if (_amountReceivedController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى إدخال المبلغ المستلم")));
      return;
    }

    setState(() => _isProcessing = true);
    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();

      // 1. تحديث الأوردرات في كولكشن deliveredorders
      for (var doc in docs) {
        batch.update(doc.reference, {
          'isSettled': true,
          'settledDate': FieldValue.serverTimestamp(),
        });
      }

      // 2. تسجيل العملية في كولكشن التسويات settlements
      DocumentReference settlementRef = FirebaseFirestore.instance.collection('settlements').doc();
      batch.set(settlementRef, {
        'repCode': widget.repCode,
        'repName': widget.repName,
        'amountExpected': expected,
        'amountReceived': double.tryParse(_amountReceivedController.text) ?? 0,
        'settlementDate': FieldValue.serverTimestamp(),
        'orderIds': docs.map((d) => d.id).toList(),
      });

      await batch.commit();
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تمت التسوية بنجاح وتم تصفير العهدة ✅")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("حدث خطأ: $e")));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Widget _buildNoDataState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 60.sp, color: Colors.grey),
          SizedBox(height: 10.sp),
          const Text("لا توجد مبالغ معلقة للمندوب (الرصيد صفر)"),
        ],
      ),
    );
  }
}

