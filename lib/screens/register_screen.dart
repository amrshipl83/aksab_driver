import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  String _selectedRole = 'free_driver'; // المندوب الحر هو الافتراضي الآن
  bool _isLoading = false;

  // المتحكمات
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController(); // سنستخدمه للميل الذكي
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // 💡 تطبيق "الميل الذكي": تحويل رقم الهاتف لبريد إلكتروني مقبول في Firebase
      String smartEmail = "${_phoneController.text.trim()}@aksab.com";

      // 1. إنشاء الحساب في Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: smartEmail,
        password: _passwordController.text,
      );

      // 2. منطق توزيع المجموعات (نفس سلوك الـ HTML القديم + المندوب الحر)
      String collectionName;
      if (_selectedRole == 'free_driver') {
        collectionName = 'pendingFreeDrivers'; // المندوب الحر له مجموعته الخاصة
      } else if (_selectedRole == 'delivery_rep') {
        collectionName = 'pendingReps'; // الموظف العادي
      } else {
        collectionName = 'pendingManagers'; // مشرف أو مدير (كلاهما في المانجر)
      }

      // 3. حفظ البيانات (نفس الحقول القديمة لضمان توافق صفحة الإدارة)
      await FirebaseFirestore.instance.collection(collectionName).doc(userCredential.user!.uid).set({
        'fullname': _nameController.text.trim(),
        'email': smartEmail, // الميل الذكي
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'role': _selectedRole, // القيمة الفعلية (delivery_manager, delivery_supervisor.. إلخ)
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'uid': userCredential.user!.uid,
      });

      _showSuccessDialog();
    } on FirebaseAuthException catch (e) {
      _showMsg("خطأ: ${e.message}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // دالة لاختيار الأدوار تفرق بين المشرف والمدير داخلياً
  Widget _roleOption(String title, String value) {
    return RadioListTile(
      title: Text(title, style: TextStyle(fontSize: 10.sp)),
      value: value,
      groupValue: _selectedRole,
      onChanged: (v) => setState(() => _selectedRole = v.toString()),
      activeColor: Color(0xFF43B97F),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: Color(0xFF43B97F)))
        : SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 8.h),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Text("تسجيل حساب جديد", style: TextStyle(fontSize: 18.sp, color: Color(0xFF43B97F), fontWeight: FontWeight.bold)),
                  SizedBox(height: 4.h),
                  _buildInput(_nameController, "الاسم الكامل", Icons.person),
                  _buildInput(_phoneController, "رقم الهاتف (سيستخدم للدخول)", Icons.phone, type: TextInputType.phone),
                  _buildInput(_addressController, "العنوان بالتفصيل", Icons.map),
                  _buildInput(_passwordController, "كلمة المرور", Icons.lock, isPass: true),
                  
                  Divider(height: 4.h),
                  Align(alignment: Alignment.centerRight, child: Text("اختار نوع الحساب:", style: TextStyle(fontWeight: FontWeight.bold))),
                  
                  // الأدوار الأربعة المتاحة
                  _roleOption("مندوب توصيل حر", "free_driver"),
                  _roleOption("مندوب تحصيل (موظف)", "delivery_rep"),
                  _roleOption("مشرف تحصيل", "delivery_supervisor"),
                  _roleOption("مدير تحصيل", "delivery_manager"),

                  SizedBox(height: 3.h),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF43B97F),
                      minimumSize: Size(100.w, 7.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _handleRegister,
                    child: Text("تسجيل", style: TextStyle(color: Colors.white, fontSize: 13.sp)),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // --- دوال مساعدة للواجهة ---
  Widget _buildInput(TextEditingController ctrl, String label, IconData icon, {bool isPass = false, TextInputType type = TextInputType.text}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 2.h),
      child: TextFormField(
        controller: ctrl,
        obscureText: isPass,
        keyboardType: type,
        textAlign: TextAlign.right,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: Icon(icon, color: Color(0xFF43B97F)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: (v) => v!.isEmpty ? "مطلوب" : null,
      ),
    );
  }

  void _showMsg(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text("تم بنجاح"),
        content: Text("تم إرسال طلبك للإدارة. يمكنك الدخول برقم هاتفك بعد الموافقة."),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text("حسناً"))],
      ),
    ).then((_) => Navigator.pop(context));
  }
}
