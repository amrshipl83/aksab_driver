import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sizer/sizer.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/login_screen.dart';
import 'screens/register_screen.dart';

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
        // إذا وجد مستخدم (وهذا ما يحدث فور الضغط على "تسجيل" بنجاح)
        if (snapshot.hasData) {
          // نقوم بعمل تسجيل خروج فوري لضمان عدم بقاء المستخدم عالقاً 
          // ولإجباره على تسجيل الدخول مرة أخرى بعد موافقة الإدارة
          FirebaseAuth.instance.signOut();
          return LoginScreen();
        }
        // في الحالة الطبيعية (عدم وجود مستخدم) يفتح صفحة الدخول
        return LoginScreen();
      },
    );
  }
}
