import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  // Firebase'in yetkili ve veritabanı birimlerini çağırdık
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Kayıt Olma Fonksiyonu
  Future<String> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      // 1. Adım: Kullanıcıyı Auth sistemine (Giriş Kısmına) kaydet
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Adım: Kullanıcının detaylarını (Ad, Soyad vb.) Firestore Veritabanına yaz
      // Kullanıcının ID'sini (uid) alıp doküman adı yapıyoruz
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'name': name,
        'email': email,
        'campus': 'İstanbul Beykent Üniversitesi', // Varsayılan olarak ekledik
        'uid': userCredential.user!.uid,
        'created_at': FieldValue.serverTimestamp(), // Kayıt tarihi
      });

      return "success"; // İşlem başarılı
    } on FirebaseAuthException catch (e) {
      // Firebase'den gelen özel hataları yakala (Örn: Bu mail zaten kayıtlı)
      return e.message ?? "Bir hata oluştu";
    } catch (e) {
      return "Bilinmeyen bir hata: $e";
    }
  }

  Future<String> signIn({
    required String email,
    required String password,
  }) async {
    try {
      // Firebase'e sor: Bu mail ve şifre doğru mu?
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return "success";
    } on FirebaseAuthException catch (e) {
      // Hata varsa (Şifre yanlış, kullanıcı yok vs.)
      return e.message ?? "Bir hata oluştu";
    } catch (e) {
      return "Bilinmeyen bir hata: $e";
    }
  }

  Future<String> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return "success";
    } on FirebaseAuthException catch (e) {
      return e.message ?? "Bir hata oluştu";
    } catch (e) {
      return "Bilinmeyen hata: $e";
    }
  }

}