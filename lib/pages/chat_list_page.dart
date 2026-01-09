import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/chat_service.dart';
import 'chat_page.dart';

class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  final String defaultMaleImage = "https://cdn-icons-png.flaticon.com/512/3135/3135715.png";
  final String defaultFemaleImage = "https://cdn-icons-png.flaticon.com/512/4140/4140047.png";

  @override
  Widget build(BuildContext context) {
    // Kullanıcı giriş yapmamışsa hata vermesin, boş dönsün
    if (FirebaseAuth.instance.currentUser == null) {
      return const Scaffold(body: Center(child: Text("Lütfen giriş yapın.")));
    }

    String currentUserId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mesajlarım"),
        backgroundColor: const Color(0xFF4A148C),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: ChatService().getUserChats(),
        builder: (context, snapshot) {
          // --- HATA YAKALAMA KISMI ---
          if (snapshot.hasError) {
            // Konsola hatayı yazdıralım ki görebilesin
            print("Mesaj Listesi Hatası: ${snapshot.error}");
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 50),
                    const SizedBox(height: 10),
                    const Text("Bir hata oluştu.", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    // Hatanın sebebini ekrana yazalım
                    Text(snapshot.error.toString(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          var chats = snapshot.data!.docs;

          if (chats.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey),
                  SizedBox(height: 10),
                  Text("Henüz hiç mesajınız yok.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              // Veri güvenliği (Null check)
              var chatData = chats[index].data() as Map<String, dynamic>?;

              if (chatData == null) return const SizedBox(); // Boş veri varsa atla

              String chatId = chats[index].id;

              // Users listesi kontrolü
              List users = chatData['users'] ?? [];
              String otherUserId = "";
              if (users.isNotEmpty) {
                // Eğer users listesi varsa diğer ID'yi bul, yoksa boş bırak
                otherUserId = users.firstWhere((id) => id != currentUserId, orElse: () => "");
              }

              // Okunmamış mesaj kontrolü (Güvenli şekilde)
              bool isUnread = false;
              if (chatData.containsKey('is_read') && chatData.containsKey('last_sender_id')) {
                isUnread = (chatData['is_read'] == false) && (chatData['last_sender_id'] != currentUserId);
              }

              return FutureBuilder<DocumentSnapshot>(
                future: otherUserId.isNotEmpty
                    ? FirebaseFirestore.instance.collection('users').doc(otherUserId).get()
                    : null, // ID yoksa boşuna sorgu atma
                builder: (context, userSnapshot) {
                  String displayName = "Kullanıcı";
                  String displayImage = defaultMaleImage;

                  // Kullanıcı verisi geldiyse doldur
                  if (userSnapshot.hasData && userSnapshot.data != null && userSnapshot.data!.exists) {
                    var userData = userSnapshot.data!.data() as Map<String, dynamic>;
                    displayName = userData['name'] ?? "İsimsiz";

                    if (userData['profile_image'] != null && userData['profile_image'] != "") {
                      displayImage = userData['profile_image'];
                    } else {
                      String gender = userData['gender'] ?? "Erkek";
                      displayImage = (gender == "Kadın") ? defaultFemaleImage : defaultMaleImage;
                    }
                  }

                  return Container(
                    color: isUnread ? Colors.blue.withOpacity(0.05) : Colors.transparent,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey[200],
                        backgroundImage: NetworkImage(displayImage),
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              displayName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: isUnread ? FontWeight.bold : FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Ürün etiketi
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.withOpacity(0.5)),
                            ),
                            child: Text(
                              chatData!['product_name'] ?? "Ürün",
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        chatData['last_message'] ?? "",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isUnread ? Colors.black87 : Colors.grey[600],
                          fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      trailing: isUnread
                          ? const Icon(Icons.circle, color: Colors.red, size: 12)
                          : const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                      onTap: () {
                        ChatService().markAsRead(chatId);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatPage(
                              chatId: chatId,
                              title: displayName,
                              otherUserId: otherUserId,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}