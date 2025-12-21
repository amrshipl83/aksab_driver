import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sizer/sizer.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// استيراد الشاشات
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/free_driver_home_screen.dart'; // الشاشة الجديدة

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(AksabDriverApp());
}

class AksabDriverApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation, deviceType) {
        return MaterialApp(
          title: 'أكساب المندوب',
          debugShowCheckedModeBanner: false,
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('ar', 'EG')],
          locale: Locale('ar', 'EG'),
          theme: ThemeData(
            primarySwatch: Colors.orange,
            fontFamily: 'Tajawal',
            scaffoldBackgroundColor: Colors.white,
          ),
          home: AuthWrapper(),
          routes: {
            '/login': (context) => LoginScreen(),
            '/register': (context) => RegisterScreen(),
            '/home': (context) => const FreeDriverHomeScreen(),
          },
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // حالة التحقق من وجود مستخدم مسجل
        if (snapshot.hasData) {
          final uid = snapshot.data!.uid;

          // فحص بيانات المستخدم في الفايربيز للتوجيه الصحيح
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('freeDrivers').doc(uid).get(),
            builder: (context, userSnap) {
              if (userSnap.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }

              // إذا وجدنا بياناته في المندوب الحر وحالته "مقبول"
              if (userSnap.hasData && userSnap.data!.exists) {
                var data = userSnap.data!.data() as Map<String, dynamic>;
                if (data['status'] == 'approved') {
                  return const FreeDriverHomeScreen();
                }
              }

              // إذا لم يكن مقبولاً أو بياناته لسه في الـ Pending
              // نسجل الخروج ونعيده للـ Login مع رسالة توضيحية
              FirebaseAuth.instance.signOut();
              return LoginScreen();
            },
          );
        }
        
        // إذا لم يكن هناك مستخدم مسجل أصلاً
        return LoginScreen();
      },
    );
  }
}
