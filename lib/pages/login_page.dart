import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // FirebaseAuth erişimi için gerekli
import '../services/auth_service.dart';
import 'register_page.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Tasarımdaki Renkler
  final Color anaRenk = const Color(0xFF4A148C); // Koyu Mor
  final Color ikincilRenk = const Color(0xFFFFA000); // Turuncu/Hardal

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. LOGO ve BAŞLIKLAR
                Icon(Icons.shopping_bag_outlined, size: 80, color: anaRenk),
                const SizedBox(height: 16),
                Text(
                  "Kampüs Pazar",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: anaRenk,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Kampüs ilanlarına göz atmak için giriş yap.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 40),

                // 2. E-POSTA KUTUSU
                _buildTextField(
                  controller: _emailController,
                  icon: Icons.email_outlined,
                  hintText: "Okul E-posta@kampus.edu.tr",
                ),
                const SizedBox(height: 16),

                // 3. ŞİFRE KUTUSU
                _buildTextField(
                  controller: _passwordController,
                  icon: Icons.lock_outline,
                  hintText: "Şifre",
                  isPassword: true,
                ),
                const SizedBox(height: 24),

                // 4. GİRİŞ YAP BUTONU (Dolu Turuncu)
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Lütfen alanları doldur.")),
                        );
                        return;
                      }

                      // 1. Giriş İşlemi (Email/Şifre Kontrolü)
                      final result = await AuthService().signIn(
                        email: _emailController.text.trim(),
                        password: _passwordController.text.trim(),
                      );

                      if (result == "success") {
                        // --- YENİ: MAİL DOĞRULAMA KONTROLÜ BAŞLANGIÇ ---
                        User? user = FirebaseAuth.instance.currentUser;

                        if (user != null && !user.emailVerified) {
                          // Eğer mail onaylı DEĞİLSE:
                          await FirebaseAuth.instance.signOut(); // Hemen çıkış yap (İçeri alma)

                          if (mounted) {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text("Mail Doğrulanmadı ⚠️"),
                                content: const Text("Giriş yapabilmek için lütfen mail adresinize gönderilen doğrulama linkine tıklayın."),
                                actions: [
                                  TextButton(
                                      onPressed: () async {
                                        // Linki tekrar gönder
                                        try {
                                          await user.sendEmailVerification();
                                          if (mounted) {
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Link tekrar gönderildi! Mailinizi kontrol edin."), backgroundColor: Colors.green));
                                          }
                                        } catch (e) {
                                          // Çok sık basarsa hata verebilir
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Biraz bekleyip tekrar deneyin."), backgroundColor: Colors.orange));
                                        }
                                      },
                                      child: const Text("Linki Tekrar Gönder")
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text("Tamam"),
                                  ),
                                ],
                              ),
                            );
                          }
                          return; // Fonksiyondan çık (HomePage'e gitme)
                        }
                        // --- MAİL DOĞRULAMA KONTROLÜ BİTİŞ ---

                        // Mail onaylıysa Ana Sayfaya git
                        if (mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const HomePage()),
                          );
                        }
                      } else {
                        // Giriş hatalıysa (Şifre yanlış vs.)
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(result), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ikincilRenk,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      "Giriş Yap",
                      style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 5. HESAP OLUŞTUR BUTONU (Mor Çizgili)
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const RegisterPage()),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: anaRenk, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      "Hesap Oluştur",
                      style: TextStyle(
                          fontSize: 18,
                          color: anaRenk,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 6. ŞİFREMİ UNUTTUM
                TextButton(
                  onPressed: () {
                    _sifreSifirlamaPenceresiAc();
                  },
                  child: const Text(
                    "Şifremi Unuttum?",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // TextField Tasarım Fonksiyonu
  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String hintText,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? !_isPasswordVisible : false,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: anaRenk),
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(
            _isPasswordVisible
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: Colors.grey,
          ),
          onPressed: () {
            setState(() {
              _isPasswordVisible = !_isPasswordVisible;
            });
          },
        )
            : null,
        hintText: hintText,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: anaRenk, width: 2),
        ),
      ),
    );
  }

  // Şifre Sıfırlama Penceresi (Pop-up)
  void _sifreSifirlamaPenceresiAc() {
    final resetEmailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Şifre Sıfırlama"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Mail adresinizi girin, size sıfırlama bağlantısı gönderelim."),
              const SizedBox(height: 10),
              TextField(
                controller: resetEmailController,
                decoration: const InputDecoration(
                  hintText: "E-posta Adresiniz",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("İptal", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                if (resetEmailController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen mail adresinizi yazın")));
                  return;
                }

                Navigator.pop(context);

                final result = await AuthService().resetPassword(resetEmailController.text);

                if (result == "success") {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Sıfırlama maili gönderildi! Spam kutunuzu kontrol edin."), backgroundColor: Colors.green),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result), backgroundColor: Colors.red),
                  );
                }
              },
              child: Text("Gönder", style: TextStyle(color: anaRenk, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}