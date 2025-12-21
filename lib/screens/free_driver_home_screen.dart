import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sizer/sizer.dart';

class FreeDriverHomeScreen extends StatefulWidget {
  const FreeDriverHomeScreen({super.key});

  @override
  State<FreeDriverHomeScreen> createState() => _FreeDriverHomeScreenState();
}

class _FreeDriverHomeScreenState extends State<FreeDriverHomeScreen> {
  bool isOnline = false; // حالة المندوب (فاتح أو قافل)
  int _selectedIndex = 0; // التنقل بين الأيقونات في الشريط السفلي

  // تحديث حالة الاتصال في الفايربيز
  void _toggleOnlineStatus(bool value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('freeDrivers').doc(uid).update({
        'isOnline': value,
        'lastSeen': FieldValue.serverTimestamp(),
      });
      setState(() => isOnline = value);
      
      String msg = value ? "أنت الآن متصل وتستقبل الطلبات" : "تم تسجيل الخروج من وضع العمل";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      // 1. الشريط الجانبي (Drawer)
      drawer: _buildSidebar(context),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text("لوحة التحكم", style: TextStyle(color: Colors.black, fontSize: 15.sp)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          // زر الـ Online/Offline في الـ AppBar ليكون واضحاً
          Switch(
            value: isOnline,
            activeColor: Colors.green,
            onChanged: _toggleOnlineStatus,
          ),
        ],
      ),
      // 2. محتوى الشاشة (يتغير حسب الحالة)
      body: _buildDashboardContent(),
      // 3. شريط التنقل السفلي (Bottom Navigation Bar)
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Colors.orange[900],
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "الرئيسية"),
          BottomNavigationBarItem(icon: Icon(Icons.radar), label: "الرادار"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "طلباتي"),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: "المحفظة"),
        ],
      ),
    );
  }

  Widget _buildDashboardContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // كارت الحالة الحالي
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isOnline ? Colors.green[50] : Colors.red[50],
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: isOnline ? Colors.green : Colors.red),
            ),
            child: Row(
              children: [
                Icon(isOnline ? Icons.check_circle : Icons.do_not_disturb_on, 
                     color: isOnline ? Colors.green : Colors.red),
                const SizedBox(width: 15),
                Text(
                  isOnline ? "أنت متاح لاستلام الطلبات" : "أنت حالياً غير متصل بالخدمة",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // إحصائيات سريعة
          _buildQuickStats(),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      children: [
        _statCard("إجمالي الأرباح", "0.00 ج.م", Icons.monetization_on, Colors.blue),
        _statCard("طلبات اليوم", "0", Icons.shopping_basket, Colors.orange),
        _statCard("التقييم", "5.0", Icons.star, Colors.amber),
        _statCard("ساعات العمل", "0h", Icons.timer, Colors.purple),
      ],
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 25.sp),
          const SizedBox(height: 10),
          Text(title, style: TextStyle(color: Colors.grey, fontSize: 10.sp)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp)),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: Colors.orange[800]),
            accountName: const Text("المندوب الحر"),
            accountEmail: Text(FirebaseAuth.instance.currentUser?.email ?? ""),
            currentAccountPicture: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person)),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text("الملف الشخصي"),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text("إعدادات المركبة"),
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("تسجيل الخروج"),
            onTap: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
    );
  }
}

