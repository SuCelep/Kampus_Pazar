import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/chat_service.dart';
import 'chat_page.dart';

class ProductDetailPage extends StatefulWidget {
  final Map<String, dynamic> productData;
  final String docId;

  const ProductDetailPage({
    super.key,
    required this.productData,
    required this.docId,
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final Color anaRenk = const Color(0xFF4A148C);
  final Color ikincilRenk = const Color(0xFFFFA000); // Turuncu tonu

  bool isFavorite = false;
  bool isLoadingFavorite = true;
  bool isBuying = false;

  // DİNAMİK SATICI BİLGİLERİ
  String currentSellerName = "Yükleniyor...";
  String currentUni = "Üniversite Yükleniyor...";
  String currentCampus = "Kampüs Yükleniyor...";

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _favoriDurumunuKontrolEt();
    _saticiBilgileriniGetir();
  }

  Future<void> _saticiBilgileriniGetir() async {
    if (!widget.productData.containsKey('seller_id') || widget.productData['seller_id'] == null) {
      if (mounted) setState(() { currentSellerName = "Bilinmeyen Satıcı"; currentUni = ""; currentCampus = ""; });
      return;
    }
    String sellerId = widget.productData['seller_id'];
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(sellerId).get();
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            currentSellerName = userData['name'] ?? "İsimsiz Üye";
            currentUni = userData['collage_name'] ?? userData['university'] ?? "Üniversite Belirtilmemiş";
            currentCampus = userData['campus'] ?? userData['campüs'] ?? "Kampüs Belirtilmemiş";
          });
        }
      }
    } catch (e) { print("Hata: $e"); }
  }

  // --- İLANI SİLME ---
  Future<void> _ilaniSil() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("İlanı Sil"),
        content: const Text("Bu ilanı yayından kaldırmak istediğine emin misin?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Vazgeç", style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Evet, Sil", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => isBuying = true);
    try {
      await _firestore.collection('products').doc(widget.docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("İlan silindi."), backgroundColor: Colors.grey));
        Navigator.pop(context);
      }
    } catch (e) { setState(() => isBuying = false); }
  }

  // --- SATIN ALMA ---
  Future<void> _satinAl() async {
    if (_auth.currentUser == null) return;
    if (widget.productData['seller_id'] == _auth.currentUser!.uid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kendi ilanınızı satın alamazsınız!"), backgroundColor: Colors.orange));
      return;
    }
    setState(() => isBuying = true);
    try {
      String uid = _auth.currentUser!.uid;
      await _firestore.collection('users').doc(uid).update({'products_bought_count': FieldValue.increment(1)});
      await _firestore.collection('products').doc(widget.docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ürün başarıyla satın alındı! 🎉"), backgroundColor: Colors.green, duration: Duration(seconds: 3)));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red));
        setState(() => isBuying = false);
      }
    }
  }


  // --- TEKLİF VERME DİYALOĞU ---
  Future<void> _teklifVerDialog() async {
    final TextEditingController offerController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Teklif Ver 🏷️"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Bu ürün için ne kadar teklif etmek istersiniz?"),
              const SizedBox(height: 10),
              TextField(
                controller: offerController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: "Örn: 2500",
                  suffixText: "₺",
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
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: anaRenk),
              onPressed: () async {
                String price = offerController.text.trim();
                if (price.isEmpty) return;

                Navigator.pop(context); // Pencereyi kapat

                String productName = widget.productData['name'] ?? "Ürün";
                String offerMessage = "Merhaba, '$productName' için $price ₺ teklif veriyorum.";
                String sellerId = widget.productData['seller_id'];

                try {
                  // Sohbeti başlat (Yoksa oluşturur)
                  String chatId = await ChatService().startChat(sellerId, widget.docId, productName);

                  // --- YENİ FONKSİYONU KULLANIYORUZ ---
                  await ChatService().sendOfferMessage(chatId, offerMessage, price, widget.docId);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Teklifiniz özel butonlarla iletildi! 📨"), backgroundColor: Colors.green)
                    );
                  }
                } catch (e) {
                  print("Teklif gönderme hatası: $e");
                }
              },
              child: const Text("Teklifi Gönder", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // --- FAVORİ ---
  Future<void> _favoriIslemi() async {
    setState(() => isFavorite = !isFavorite);
    try {
      String uid = _auth.currentUser!.uid;
      var favoritesRef = _firestore.collection('users').doc(uid).collection('favorites').doc(widget.docId);
      if (isFavorite) {
        String resimUrl = (widget.productData['image_urls'] != null && (widget.productData['image_urls'] as List).isNotEmpty) ? (widget.productData['image_urls'] as List)[0] : "";
        await favoritesRef.set({
          'product_id': widget.docId, 'name': widget.productData['name'], 'price': widget.productData['price'], 'image': resimUrl, 'added_at': FieldValue.serverTimestamp()
        });
      } else {
        await favoritesRef.delete();
      }
    } catch (e) { setState(() => isFavorite = !isFavorite); }
  }

  Future<void> _favoriDurumunuKontrolEt() async {
    if (_auth.currentUser == null) return;
    try {
      var doc = await _firestore.collection('users').doc(_auth.currentUser!.uid).collection('favorites').doc(widget.docId).get();
      if (mounted) setState(() { isFavorite = doc.exists; isLoadingFavorite = false; });
    } catch (e) { if (mounted) setState(() => isLoadingFavorite = false); }
  }

  @override
  Widget build(BuildContext context) {
    var data = widget.productData;
    String image = (data['image_urls'] != null && (data['image_urls'] as List).isNotEmpty) ? (data['image_urls'] as List)[0] : "";
    bool isOwner = (_auth.currentUser != null && data['seller_id'] == _auth.currentUser!.uid);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0, foregroundColor: anaRenk,
        actions: [
          if (isOwner) IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 28), onPressed: isBuying ? null : _ilaniSil),
          IconButton(icon: isLoadingFavorite ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: Colors.red, size: 28), onPressed: isLoadingFavorite ? null : _favoriIslemi),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 300, width: double.infinity, color: Colors.grey[100],
                    child: image.isNotEmpty ? Image.network(image, fit: BoxFit.cover) : Icon(Icons.shopping_bag, size: 100, color: Colors.grey[300]),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                          child: Text(data['category_id'] ?? "Genel", style: TextStyle(color: ikincilRenk, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 10),
                        Text(data['name'] ?? "İsimsiz", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        Text("${data['price']} ₺", style: TextStyle(fontSize: 24, color: anaRenk, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),

                        // Konum
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.withOpacity(0.2))),
                          child: Row(children: [Icon(Icons.location_on, color: anaRenk), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Konum", style: TextStyle(fontSize: 12, color: Colors.grey)), Text("$currentUni\n$currentCampus", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))]))]),
                        ),
                        const SizedBox(height: 15),

                        // Satıcı
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.withOpacity(0.2))),
                          child: Row(children: [CircleAvatar(backgroundColor: anaRenk.withOpacity(0.2), child: Icon(Icons.person, color: anaRenk)), const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("İlan Sahibi", style: TextStyle(fontSize: 12, color: Colors.grey)), Text(currentSellerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))])]),
                        ),
                        const SizedBox(height: 20),

                        // Açıklama
                        const Text("Açıklama", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(data['description'] ?? "Açıklama yok.", style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- BUTONLAR ALANI (GÜNCELLENDİ) ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))]),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ÜST SIRA: Mesaj At ve Teklif Ver (YAN YANA)
                  Row(
                    children: [
                      // MESAJ AT
                      Expanded(
                        child: SizedBox(
                          height: 45,
                          child: OutlinedButton(
                            onPressed: isOwner
                                ? null
                                : () async {
                              if (!widget.productData.containsKey('seller_id')) return;
                              String sellerId = widget.productData['seller_id'];
                              String chatId = await ChatService().startChat(sellerId, widget.docId, widget.productData['name']);
                              if (context.mounted) Navigator.push(context, MaterialPageRoute(builder: (context) => ChatPage(chatId: chatId, title: widget.productData['name'], otherUserId: sellerId)));
                            },
                            style: OutlinedButton.styleFrom(
                                side: BorderSide(color: anaRenk),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                            ),
                            child: Icon(Icons.chat_bubble_outline, color: anaRenk),
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      // TEKLİF VER (YENİ)
                      Expanded(
                        flex: 2, // Biraz daha geniş olsun
                        child: SizedBox(
                          height: 45,
                          child: ElevatedButton.icon(
                            onPressed: isOwner ? null : _teklifVerDialog,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00897B), // Teal rengi (Teklif için uygun)
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                            ),
                            icon: const Icon(Icons.local_offer, color: Colors.white, size: 18),
                            label: const Text("Teklif Ver", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // SATIN AL (EN ALTTA BÜYÜK)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: (isBuying || isOwner) ? null : _satinAl,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isOwner ? Colors.grey[400] : Colors.orange,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: isBuying
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Icon(isOwner ? Icons.person : Icons.shopping_cart, color: Colors.white),
                      label: Text(
                        isBuying ? "İşleniyor..." : (isOwner ? "Sizin İlanınız" : "Satın Al"),
                        style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}