import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'home_page.dart'; // Artık direkt Home'a gitmediğimiz için buna gerek kalmayabilir ama dursun.

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Controllerlar
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool isLoading = false;

  // KAYIT OL FONKSİYONU
  Future<void> _register() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    String confirmPassword = _confirmPasswordController.text.trim();
    String name = _nameController.text.trim();

    // 1. Boş Alan Kontrolü
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen tüm alanları doldurun!"), backgroundColor: Colors.orange));
      return;
    }

    // --- YENİ: EDU MAİL KONTROLÜ 🎓 ---
    // Eğer mail adresi .edu veya .edu.tr ile bitmiyorsa işlemi durdur.
    if (!email.endsWith('.edu.tr') && !email.endsWith('.edu')) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Sadece öğrenci maili (.edu veya .edu.tr) ile kayıt olabilirsiniz!"),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          )
      );
      return;
    }
    // ----------------------------------

    // 2. Şifre Eşleşme Kontrolü
    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Şifreler eşleşmiyor!"), backgroundColor: Colors.red));
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // 3. Kullanıcıyı Firebase Auth'da oluştur
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // --- YENİ: DOĞRULAMA MAİLİ GÖNDER 📨 ---
      User? user = userCredential.user;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }

      // 4. Kullanıcı Bilgilerini Firestore'a Kaydet
      String uid = user!.uid;

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'name': name,
        'email': email,
        'created_at': FieldValue.serverTimestamp(),
        'products_bought_count': 0,
        'gender': 'Erkek', // Varsayılan
        'profile_image': '',
        'collage_name': '',
        'campüs': '',
      });

      // 5. Başarılı İşlem Sonrası Diyalog
      if (mounted) {
        // Otomatik girişi engellemek için çıkış yapıyoruz
        await FirebaseAuth.instance.signOut();

        showDialog(
          context: context,
          barrierDismissible: false, // Boşluğa basınca kapanmasın
          builder: (context) => AlertDialog(
            title: const Text("Doğrulama Maili Gönderildi 📨"),
            content: const Text(
              "Kayıt işlemi başarılı! 🎉\n\nGüvenlik nedeniyle, lütfen mail kutunuzu (Spam klasörü dahil) kontrol edin ve gönderdiğimiz linke tıklayarak hesabınızı doğrulayın.\n\nDoğruladıktan sonra giriş yapabilirsiniz.",
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Dialogu kapat
                  Navigator.pop(context); // Register sayfasını kapat (Login'e dön)
                },
                child: const Text("Tamam, Anladım", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A148C))),
              ),
            ],
          ),
        );
      }

    } on FirebaseAuthException catch (e) {
      String message = "Kayıt başarısız";
      if (e.code == 'email-already-in-use') {
        message = "Bu email zaten kullanımda.";
      } else if (e.code == 'weak-password') {
        message = "Şifre çok zayıf (en az 6 karakter).";
      } else if (e.code == 'invalid-email') {
        message = "Geçersiz email formatı.";
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Kayıt Ol"),
        backgroundColor: const Color(0xFF4A148C),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.school, size: 80, color: Color(0xFF4A148C)), // İkonu okul yaptık :)
              const SizedBox(height: 20),

              const Text(
                "Sadece .edu ve .edu.tr mailleri kabul edilir.",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 10),

              // İsim Alanı
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: "Ad Soyad",
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 15),

              // Email Alanı
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "Öğrenci Email",
                  hintText: "ornek@beykent.edu.tr",
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 15),

              // Şifre Alanı
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Şifre",
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 15),

              // Şifre Tekrar Alanı
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Şifre Tekrar",
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 25),

              // Kayıt Ol Butonu
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A148C),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Kayıt Ol", style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}