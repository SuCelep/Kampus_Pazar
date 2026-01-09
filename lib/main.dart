import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'pages/register_page.dart'; // Bu satır önemli, sayfayı buradan buluyor
import 'pages/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kampüs Pazar',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple, // Renk fark etmez, sayfa kendi rengini kullanıyor
      ),
      // <-- İşte burası! Burası değişmediği için sorun yok.
        home: const LoginPage(),
    );
  }
}