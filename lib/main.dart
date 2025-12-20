import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sizer/sizer.dart';
import 'firebase_options.dart'; // الملف اللي إنت لسه مولده
import 'screens/available_orders_screen.dart'; // الشاشة اللي هنعملها دلوقتي

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تهيئة الفايربيز باستخدام الخيارات اللي اتولدت تلقائياً
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const AksabDriverApp());
}

class AksabDriverApp extends StatelessWidget {
  const AksabDriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation, deviceType) {
        return MaterialApp(
          title: 'أكساب مندوب',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primarySwatch: Colors.green,
            fontFamily: 'Cairo', // تأكد من إضافة الخط لاحقاً أو حذفه الآن
            useMaterial3: true,
          ),
          home: const AvailableOrdersScreen(),
        );
      },
    );
  }
}
