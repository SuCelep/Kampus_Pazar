import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // SOHBET BAŞLAT (Mevcut kod)
  Future<String> startChat(String receiverId, String productId, String productName) async {
    String currentUserId = _auth.currentUser!.uid;
    List<String> ids = [currentUserId, receiverId];
    ids.sort();
    String chatId = ids.join("_") + "_$productId";

    var chatDoc = await _firestore.collection('chats').doc(chatId).get();

    if (!chatDoc.exists) {
      await _firestore.collection('chats').doc(chatId).set({
        'users': ids,
        'product_id': productId,
        'product_name': productName,
        'last_message': '',
        'last_sender_id': '',
        'is_read': true,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
    return chatId;
  }

  // NORMAL MESAJ GÖNDER (Mevcut kod)
  Future<void> sendMessage(String chatId, String message) async {
    String currentUserId = _auth.currentUser!.uid;
    Timestamp timestamp = Timestamp.now();

    await _firestore.collection('chats').doc(chatId).collection('messages').add({
      'sender_id': currentUserId,
      'message': message,
      'type': 'text', // Normal mesaj tipi
      'timestamp': timestamp,
    });

    await _firestore.collection('chats').doc(chatId).update({
      'last_message': message,
      'last_sender_id': currentUserId,
      'is_read': false,
      'timestamp': timestamp,
    });
  }

  // --- YENİ: TEKLİF MESAJI GÖNDER ---
  Future<void> sendOfferMessage(String chatId, String message, String amount, String productId) async {
    String currentUserId = _auth.currentUser!.uid;
    Timestamp timestamp = Timestamp.now();

    await _firestore.collection('chats').doc(chatId).collection('messages').add({
      'sender_id': currentUserId,
      'message': message,
      'type': 'offer', // ÖZEL TİP: TEKLİF
      'offer_amount': amount,
      'offer_status': 'pending', // pending, accepted, rejected
      'product_id': productId,
      'timestamp': timestamp,
    });

    await _firestore.collection('chats').doc(chatId).update({
      'last_message': "Teklif: $amount ₺",
      'last_sender_id': currentUserId,
      'is_read': false,
      'timestamp': timestamp,
    });
  }

  // --- YENİ: TEKLİFE CEVAP VER ---
  Future<void> respondToOffer(String chatId, String messageId, String action, String productId, String buyerId) async {
    // action: 'accepted' veya 'rejected'

    // 1. Mesajın durumunu güncelle
    await _firestore.collection('chats').doc(chatId).collection('messages').doc(messageId).update({
      'offer_status': action,
    });

    // 2. Eğer KABUL EDİLDİYSE -> Ürünü satıldı işaretle (Sil)
    if (action == 'accepted') {
      try {
        // Ürünü sil (Satıldı olarak kaldırıyoruz)
        await _firestore.collection('products').doc(productId).delete();

        // Alıcının satın alma sayısını arttır
        await _firestore.collection('users').doc(buyerId).update({
          'products_bought_count': FieldValue.increment(1),
        });

        // Bilgilendirme mesajı at (Otomatik)
        await sendMessage(chatId, "✅ Teklif kabul edildi ve ürün satıldı!");

      } catch (e) {
        print("Satış işlem hatası: $e");
      }
    } else {
      // Reddedildiyse bilgi mesajı at
      await sendMessage(chatId, "❌ Teklif reddedildi.");
    }
  }

  // MESAJLARI GETİR
  Stream<QuerySnapshot> getMessages(String chatId) {
    return _firestore.collection('chats').doc(chatId).collection('messages').orderBy('timestamp', descending: false).snapshots();
  }

  // KULLANICININ SOHBETLERİNİ GETİR
  Stream<QuerySnapshot> getUserChats() {
    String uid = _auth.currentUser!.uid;
    return _firestore.collection('chats').where('users', arrayContains: uid).orderBy('timestamp', descending: true).snapshots();
  }

  // OKUNDU İŞARETLE
  Future<void> markAsRead(String chatId) async {
    await _firestore.collection('chats').doc(chatId).update({'is_read': true});
  }
}