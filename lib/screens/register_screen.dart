import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  String _selectedRole = 'free_driver';
  String _vehicleConfig = 'motorcycleConfig';
  bool _isLoading = false;
  bool _obscurePassword = true;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      String smartEmail = "${_phoneController.text.trim()}@aksab.com";
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: smartEmail,
        password: _passwordController.text,
      );

      String collectionName;
      // الحفاظ على نفس منطق توزيع الكولكشنز دون تغيير في القديم
      if (_selectedRole == 'free_driver') {
        collectionName = 'pendingFreeDrivers';
      } else if (_selectedRole == 'delivery_rep') {
        collectionName = 'pendingReps';
      } else {
        // الأدوار الإدارية (مدير ومشرف) تذهب لكولكشن pendingManagers
        collectionName = 'pendingManagers';
      }

      await FirebaseFirestore.instance.collection(collectionName).doc(userCredential.user!.uid).set({
        'fullname': _nameController.text.trim(),
        'email': smartEmail,
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'role': _selectedRole, // سيحفظ delivery_manager أو delivery_supervisor بدقة
        'vehicleConfig': _selectedRole == 'free_driver' ? _vehicleConfig : 'none',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'uid': userCredential.user!.uid,
      });

      _showSuccessDialog();
    } on FirebaseAuthException catch (e) {
      _showMsg("خطأ: ${e.message}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Text(
                        "انضم لعائلة أكسب",
                        style: TextStyle(
                          fontSize: 24.sp,
                          color: Colors.orange[900],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 1.h),
                      Text(
                        "سجل بياناتك وسيتم مراجعتها خلال 24 ساعة",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
                      ),
                      SizedBox(height: 4.h),
                      _buildInput(_nameController, "الاسم الكامل كما في البطاقة", Icons.person),
                      _buildInput(_phoneController, "رقم الهاتف", Icons.phone, type: TextInputType.phone),
                      _buildInput(_addressController, "محل الإقامة الحالي", Icons.map),
                      _buildInput(_passwordController, "كلمة مرور قوية", Icons.lock, isPass: true),
                      const Divider(height: 50, thickness: 1.2),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          "نوع الانضمام:",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, color: Colors.black87),
                        ),
                      ),
                      SizedBox(height: 2.h),
                      
                      // خيارات المناديب (كما هي)
                      _roleOption("مندوب توصيل حر (امتلك مركبة)", "free_driver"),
                      if (_selectedRole == 'free_driver') _buildVehiclePicker(),
                      _roleOption("مندوب تحصيل (موظف بشركة)", "delivery_rep"),
                      
                      // إضافة التفرقة بين المشرف والمدير (نفس استايل الـ HTML)
                      _roleOption("مشرف تحصيل (إشراف ميداني)", "delivery_supervisor"),
                      _roleOption("مدير تحصيل (إدارة النظام)", "delivery_manager"),

                      SizedBox(height: 5.h),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87,
                          minimumSize: Size(100.w, 8.h),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: _handleRegister,
                        child: Text(
                          "إرسال طلب الانضمام",
                          style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold),
                        ),
                      ),
                      SizedBox(height: 4.h),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildVehiclePicker() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 2.h),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange[100]!, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "اختر نوع مركبتك:",
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: Colors.orange[900]),
          ),
          SizedBox(height: 1.h),
          DropdownButtonFormField<String>(
            value: _vehicleConfig,
            isExpanded: true,
            dropdownColor: Colors.orange[50],
            style: TextStyle(fontSize: 14.sp, color: Colors.black, fontWeight: FontWeight.w500),
            decoration: const InputDecoration(border: InputBorder.none),
            items: [
              DropdownMenuItem(value: 'motorcycleConfig', child: Text("موتوسيكل (Motorcycle)")),
              DropdownMenuItem(value: 'pickupConfig', child: Text("سيارة ربع نقل (Pickup)")),
              DropdownMenuItem(value: 'jumboConfig', child: Text("جامبو / نقل ثقيل (Jumbo)")),
            ],
            onChanged: (val) => setState(() => _vehicleConfig = val!),
          ),
        ],
      ),
    );
  }

  Widget _roleOption(String title, String value) {
    return Theme(
      data: Theme.of(context).copyWith(unselectedWidgetColor: Colors.grey),
      child: RadioListTile(
        title: Text(title, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
        value: value,
        groupValue: _selectedRole,
        onChanged: (v) => setState(() => _selectedRole = v.toString()),
        activeColor: Colors.orange[900],
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildInput(TextEditingController ctrl, String label, IconData icon, {bool isPass = false, TextInputType type = TextInputType.text}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 2.5.h),
      child: TextFormField(
        controller: ctrl,
        obscureText: isPass ? _obscurePassword : false,
        keyboardType: type,
        textAlign: TextAlign.right,
        style: TextStyle(fontSize: 15.sp),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 13.sp, color: Colors.grey[700]),
          contentPadding: EdgeInsets.symmetric(vertical: 2.h, horizontal: 5.w),
          prefixIcon: Icon(icon, color: Colors.orange[900], size: 20.sp),
          suffixIcon: isPass
              ? IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20.sp),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                )
              : null,
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.orange[900]!, width: 2),
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        validator: (v) => v!.isEmpty ? "هذا الحقل مطلوب" : null,
      ),
    );
  }

  void _showMsg(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m, style: TextStyle(fontSize: 13.sp)),
        backgroundColor: Colors.redAccent,
      ));

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: const Icon(Icons.check_circle, color: Colors.green, size: 70),
        content: Text(
          "تم استلام طلبك بنجاح!\nسيتم مراجعة البيانات وتفعيل الحساب قريباً.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[900],
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 1.5.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: Text("فهمت", style: TextStyle(color: Colors.white, fontSize: 14.sp)),
              ),
            ),
          )
        ],
      ),
    );
  }
}

