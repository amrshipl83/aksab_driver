import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sizer/sizer.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// استيراد الشاشات التي صممناها
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تهيئة الفايربيز
  await Firebase.initializeApp();
  
  runApp(AksabDriverApp());
}

class AksabDriverApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // استخدام Sizer لضبط استجابة الشاشات
    return Sizer(
      builder: (context, orientation, deviceType) {
        return MaterialApp(
          title: 'أكساب المندوب',
          debugShowCheckedModeBanner: false,
          
          // 🎯 تفعيل وضع اللغة العربية والاتجاه من اليمين لليسار
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [
            Locale('ar', 'EG'), // اللغة العربية
          ],
          locale: Locale('ar', 'EG'),

          // إعدادات الثيم (الألوان التي استخدمناها في HTML)
          theme: ThemeData(
            primarySwatch: Colors.orange,
            fontFamily: 'Tajawal', // تأكد من إضافة الخط في pubspec
            scaffoldBackgroundColor: Colors.white,
          ),

          // فحص حالة المصادقة عند التشغيل
          home: AuthWrapper(),
          
          // تعريف المسارات لسهولة التنقل
          routes: {
            '/login': (context) => LoginScreen(),
            '/register': (context) => RegisterScreen(),
          },
        );
      },
    );
  }
}

// كود فحص حالة المستخدم (Auth Wrapper)
class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // إذا كان مسجل دخول، سنوجهه للرئيسية (سنصممها لاحقاً)
        if (snapshot.hasData) {
          return Center(child: Text("مرحباً بك.. جارٍ التحقق من الحساب")); 
        }
        // إذا لم يكن مسجل دخول، يفتح صفحة الدخول
        return LoginScreen();
      },
    );
  }
}
