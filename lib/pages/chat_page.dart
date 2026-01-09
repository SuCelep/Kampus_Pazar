import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/chat_service.dart';

class ChatPage extends StatefulWidget {
  final String chatId;
  final String title;
  final String? otherUserId;

  const ChatPage({
    super.key,
    required this.chatId,
    required this.title,
    this.otherUserId,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();

  String otherUserImage = "https://cdn-icons-png.flaticon.com/512/3135/3135715.png";

  @override
  void initState() {
    super.initState();
    _chatService.markAsRead(widget.chatId);
    _getOtherUserProfile();
  }

  void _getOtherUserProfile() async {
    if (widget.otherUserId == null || widget.otherUserId!.isEmpty) return;
    try {
      var doc = await FirebaseFirestore.instance.collection('users').doc(widget.otherUserId).get();
      if (doc.exists) {
        var data = doc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            if (data['profile_image'] != null && data['profile_image'] != "") {
              otherUserImage = data['profile_image'];
            } else {
              String gender = data['gender'] ?? "Erkek";
              otherUserImage = (gender == "Kadın")
                  ? "https://cdn-icons-png.flaticon.com/512/4140/4140047.png"
                  : "https://cdn-icons-png.flaticon.com/512/3135/3135715.png";
            }
          });
        }
      }
    } catch (e) { print("Profil resmi hatası: $e"); }
  }

  void sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      await _chatService.sendMessage(widget.chatId, _messageController.text);
      _messageController.clear();
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    }
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return "";
    DateTime date = timestamp.toDate();
    return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }

  // --- ÖZEL TEKLİF BALONCUĞU TASARIMI ---
  Widget _buildOfferBubble(Map<String, dynamic> data, bool isMe, String messageId) {
    String status = data['offer_status'] ?? 'pending';
    String amount = data['offer_amount'] ?? '0';

    Color statusColor = Colors.orange;
    String statusText = "Bekliyor";
    if (status == 'accepted') { statusColor = Colors.green; statusText = "Kabul Edildi"; }
    if (status == 'rejected') { statusColor = Colors.red; statusText = "Reddedildi"; }

    return Container(
      width: 250,
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: statusColor, width: 2),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("TEKLİF", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 12, color: Colors.grey)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                child: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10)),
              )
            ],
          ),
          const Divider(),

          // Fiyat ve Mesaj
          Text("$amount ₺", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 5),
          Text(data['message'], style: const TextStyle(color: Colors.black54, fontSize: 13)),

          const SizedBox(height: 10),

          // BUTONLAR (Sadece ALICI tarafı görebilir ve durum 'pending' ise)
          if (!isMe && status == 'pending') ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _chatService.respondToOffer(widget.chatId, messageId, 'rejected', data['product_id'], data['sender_id']),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red[50], foregroundColor: Colors.red, elevation: 0),
                    child: const Text("Reddet"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _chatService.respondToOffer(widget.chatId, messageId, 'accepted', data['product_id'], data['sender_id']),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, elevation: 0),
                    child: const Text("Kabul Et"),
                  ),
                ),
              ],
            ),
          ] else if (status != 'pending') ...[
            // İşlem yapıldıysa bilgilendirme
            Center(
              child: Text(
                status == 'accepted' ? "Ürün satıldı ✅" : "Teklif kapatıldı ❌",
                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
              ),
            )
          ]
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFEFEF),
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(radius: 18, backgroundImage: NetworkImage(otherUserImage)),
            const SizedBox(width: 10),
            Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 16), overflow: TextOverflow.ellipsis)),
          ],
        ),
        backgroundColor: const Color(0xFF4A148C),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: _chatService.getMessages(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Text("Hata oluştu");
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                var messages = snapshot.data!.docs;

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  padding: const EdgeInsets.all(10),
                  itemBuilder: (context, index) {
                    var data = messages[index].data() as Map<String, dynamic>;
                    String messageId = messages[index].id;
                    bool isMe = data['sender_id'] == _auth.currentUser!.uid;
                    String type = data['type'] ?? 'text'; // 'text' veya 'offer'

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!isMe) ...[
                            CircleAvatar(radius: 14, backgroundImage: NetworkImage(otherUserImage)),
                            const SizedBox(width: 6),
                          ],

                          // --- MESAJIN TİPİNE GÖRE GÖRÜNÜM SEÇİMİ ---
                          if (type == 'offer')
                            _buildOfferBubble(data, isMe, messageId)
                          else
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                    color: isMe ? const Color(0xFF4A148C) : Colors.white,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
                                      bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(0),
                                      bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
                                    ),
                                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2, offset: const Offset(0, 1))]
                                ),
                                child: Column(
                                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: [
                                    Text(data['message'], style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 15)),
                                    const SizedBox(height: 4),
                                    Text(_formatTime(data['timestamp']), style: TextStyle(color: isMe ? Colors.white70 : Colors.grey, fontSize: 10)),
                                  ],
                                ),
                              ),
                            ),

                          if (isMe) const SizedBox(width: 30),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: "Mesaj yaz...",
                      filled: true, fillColor: Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFF4A148C),
                  child: IconButton(onPressed: sendMessage, icon: const Icon(Icons.send, color: Colors.white, size: 20)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}