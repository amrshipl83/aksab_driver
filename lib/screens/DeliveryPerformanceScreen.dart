import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sizer/sizer.dart';
import 'package:fl_chart/fl_chart.dart';
import 'FinancialSettlementScreen.dart'; // تأكد من وجود هذا الملف في نفس المجلد

class DeliveryPerformanceScreen extends StatefulWidget {
  final String repId;    
  final String repCode;  
  final String repName;  

  const DeliveryPerformanceScreen({
    super.key,
    required this.repId,
    required this.repCode,
    required this.repName,
  });

  @override
  State<DeliveryPerformanceScreen> createState() => _DeliveryPerformanceScreenState();
}

class _DeliveryPerformanceScreenState extends State<DeliveryPerformanceScreen> {
  DateTime startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime endDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: Text("أداء: ${widget.repName}"),
        centerTitle: true,
        backgroundColor: const Color(0xFF007BFF),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet, color: Colors.white),
            onPressed: () => _navigateToSettlement(),
            tooltip: "تسوية مالية",
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(12.sp),
        child: Column(
          children: [
            _buildDateFilter(),
            SizedBox(height: 15.sp),
            _buildCurrentLiveStatus(), // حالة waitingdelivery
            SizedBox(height: 15.sp),
            _buildHistoricalPerformance(), // إحصائيات delivered & false orders
            SizedBox(height: 20.sp),
            _buildSettlementButton(),
          ],
        ),
      ),
    );
  }

  // فلتر اختيار الفترة الزمنية
  Widget _buildDateFilter() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 10.sp, horizontal: 15.sp),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _dateColumn("من", startDate, (date) => setState(() => startDate = date)),
            Container(width: 1, height: 30, color: Colors.grey[300]),
            _dateColumn("إلى", endDate, (date) => setState(() => endDate = date)),
            Icon(Icons.calendar_month, color: Colors.blue[800]),
          ],
        ),
      ),
    );
  }

  Widget _dateColumn(String label, DateTime date, Function(DateTime) onSelect) {
    return InkWell(
      onTap: () async {
        DateTime? picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2024),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) onSelect(picked);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 9.sp)),
          Text("${date.day}-${date.month}-${date.year}",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.sp)),
        ],
      ),
    );
  }

  // حالة المهام الحالية من كولكشن waitingdelivery
  Widget _buildCurrentLiveStatus() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('waitingdelivery')
          .where('repCode', isEqualTo: widget.repCode)
          .snapshots(),
      builder: (context, snapshot) {
        int remaining = snapshot.hasData ? snapshot.data!.docs.length : 0;
        bool isDone = remaining == 0;
        return Container(
          padding: EdgeInsets.all(12.sp),
          decoration: BoxDecoration(
            color: isDone ? Colors.green[50] : Colors.orange[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDone ? Colors.green : Colors.orange),
          ),
          child: Row(
            children: [
              Icon(isDone ? Icons.check_circle : Icons.pending_actions,
                  color: isDone ? Colors.green : Colors.orange[800]),
              SizedBox(width: 10.sp),
              Expanded(
                child: Text(
                  isDone ? "أنهى جميع مهام اليوم ✅" : "متبقي $remaining مهام قيد التنفيذ حالياً",
                  style: TextStyle(fontWeight: FontWeight.bold, color: isDone ? Colors.green[800] : Colors.orange[900]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // الأداء التاريخي بدمج كولكشن الناجح والفاشل
  Widget _buildHistoricalPerformance() {
    return Column(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('deliveredorders')
              .where('repCode', isEqualTo: widget.repCode)
              .where('timestamp', isGreaterThanOrEqualTo: startDate)
              .where('timestamp', isLessThanOrEqualTo: endDate.add(const Duration(days: 1)))
              .snapshots(),
          builder: (context, delSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('falseorder')
                  .where('repCode', isEqualTo: widget.repCode)
                  .where('timestamp', isGreaterThanOrEqualTo: startDate)
                  .where('timestamp', isLessThanOrEqualTo: endDate.add(const Duration(days: 1)))
                  .snapshots(),
              builder: (context, failSnap) {
                if (delSnap.connectionState == ConnectionState.waiting || failSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                int success = delSnap.data?.docs.length ?? 0;
                int failed = failSnap.data?.docs.length ?? 0;
                double totalCash = 0;

                for (var d in delSnap.data?.docs ?? []) {
                  totalCash += (d['total'] ?? 0);
                }

                if (success == 0 && failed == 0) {
                  return Padding(
                    padding: EdgeInsets.only(top: 20.sp),
                    child: const Text("لا توجد بيانات مسجلة لهذه الفترة"),
                  );
                }

                return Column(
                  children: [
                    Row(
                      children: [
                        _kpiCard("تسليم ناجح", "$success", Icons.done_all, Colors.green),
                        _kpiCard("تسليم فاشل", "$failed", Icons.close, Colors.red),
                      ],
                    ),
                    SizedBox(height: 10.sp),
                    _wideKpiCard("إجمالي التحصيل المالي", "${totalCash.toStringAsFixed(2)} ج.م", Icons.payments, Colors.blue[900]!),
                    SizedBox(height: 20.sp),
                    Text("تحليل نسبة النجاح", style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold)),
                    SizedBox(height: 10.sp),
                    _buildPieChart(success, failed),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _kpiCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 3,
        child: Padding(
          padding: EdgeInsets.all(12.sp),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22.sp),
              SizedBox(height: 8.sp),
              Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 10.sp)),
              Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _wideKpiCard(String title, String value, IconData icon, Color color) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        color: color,
        elevation: 4,
        child: Padding(
          padding: EdgeInsets.all(15.sp),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 25.sp),
              SizedBox(height: 5.sp),
              Text(title, style: const TextStyle(color: Colors.white70)),
              Text(value, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18.sp)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPieChart(int success, int failed) {
    int total = success + failed;
    if (total == 0) return const SizedBox();
    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 40,
          sections: [
            PieChartSectionData(
              value: success.toDouble(),
              title: '${((success / total) * 100).toStringAsFixed(0)}%',
              color: Colors.green,
              radius: 50,
              titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            PieChartSectionData(
              value: failed.toDouble(),
              title: '${((failed / total) * 100).toStringAsFixed(0)}%',
              color: Colors.red,
              radius: 50,
              titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettlementButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[700],
          padding: EdgeInsets.symmetric(vertical: 12.sp),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () => _navigateToSettlement(),
        icon: const Icon(Icons.account_balance_wallet, color: Colors.white),
        label: const Text("تصفية الحساب (توريد كاش)", 
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      ),
    );
  }

  void _navigateToSettlement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FinancialSettlementScreen(
          repCode: widget.repCode,
          repName: widget.repName,
        ),
      ),
    );
  }
}

