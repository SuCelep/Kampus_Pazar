import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';
import 'product_detail_page.dart';
import 'chat_list_page.dart';
import 'profil_page.dart';
import 'add_product_page.dart';
import '../services/chat_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Color anaRenk = const Color(0xFF4A148C);

  // Hangi sayfadayız? (0: Ana Sayfa, 1: İlan Ver, 2: Profil)
  int _selectedIndex = 0;

  // Kategori Seçimi
  String secilenKategoriId = "all";
  String secilenKategoriAdi = "Tümü";

  // Sayfa Değiştirme Fonksiyonu
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Profil sayfasının kendi AppBar'ı var, o yüzden Ana Sayfa haricinde AppBar'ı gizliyoruz.
    return Scaffold(
      backgroundColor: Colors.grey[50],

      // Sadece Ana Sayfa'dayken (Index 0) bu AppBar'ı göster
      appBar: _selectedIndex == 0 ? _buildHomeAppBar() : null,

      body: _buildBody(),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex, // Seçili olan index
        onTap: _onItemTapped,       // Tıklama fonksiyonu
        selectedItemColor: anaRenk,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Ana Sayfa"),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle, size: 40), label: "İlan Ver"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profilim"),
        ],
      ),
    );
  }

  // --- GÖVDE YÖNETİMİ ---
  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeContent(); // Mevcut Ana Sayfa İçeriği
      case 1:
        return const AddProductPage();
      case 2:
        return const ProfilePage(); // <-- PROFİL SAYFASI BURADA ÇAĞRILIYOR
      default:
        return _buildHomeContent();
    }
  }

  // --- ANA SAYFA APP BAR (ÖZEL METOT) ---
  PreferredSizeWidget _buildHomeAppBar() {
    return AppBar(
      title: const Text("Kampüs Pazar", style: TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: anaRenk,
      foregroundColor: Colors.white,
      centerTitle: true,
      actions: [
        // Bildirimli Mesaj Butonu
        StreamBuilder<QuerySnapshot>(
          stream: ChatService().getUserChats(),
          builder: (context, snapshot) {
            bool hasUnread = false;
            if (snapshot.hasData) {
              String currentUid = FirebaseAuth.instance.currentUser!.uid;
              for (var doc in snapshot.data!.docs) {
                var data = doc.data() as Map<String, dynamic>;
                if (data['is_read'] == false && data['last_sender_id'] != currentUid) {
                  hasUnread = true;
                  break;
                }
              }
            }
            return Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const ChatListPage()));
                  },
                ),
                if (hasUnread)
                  Positioned(
                    right: 8, top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                      constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                    ),
                  ),
              ],
            );
          },
        ),
        // Çıkış Yap
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            if (mounted) {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
            }
          },
        ),
      ],
    );
  }

  // --- ANA SAYFA İÇERİĞİ (ESKİ BODY KODLARI BURAYA TAŞINDI) ---
  Widget _buildHomeContent() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Arama
          TextField(
            decoration: InputDecoration(
              hintText: "Ders notu, kitap veya eşya ara...",
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true, fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
          const SizedBox(height: 20),

          // Kategoriler
          const Text("Kategoriler", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          SizedBox(
            height: 50,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('categories').orderBy('name').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return const Text("Hata");
                var categoryDocs = snapshot.data!.docs;
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: categoryDocs.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) return _kategoriKarti(id: "all", ad: "Tümü", ikon: Icons.all_inclusive);
                    var doc = categoryDocs[index - 1];
                    var data = doc.data() as Map<String, dynamic>;
                    return _kategoriKarti(id: doc.id, ad: data['name'], ikon: _ikonBul(data['name']));
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // Vitrin Başlığı
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("İlanlar", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (secilenKategoriId != "all")
                Text("$secilenKategoriAdi gösteriliyor", style: TextStyle(color: anaRenk, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),

          // Ürün Listesi
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: secilenKategoriId == "all"
                  ? FirebaseFirestore.instance.collection('products').snapshots()
                  : FirebaseFirestore.instance.collection('products').where('category_id', isEqualTo: secilenKategoriId).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text("Bu kategoride ilan yok.", style: TextStyle(color: Colors.grey[600])));
                }
                final urunler = snapshot.data!.docs;
                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, childAspectRatio: 0.70, crossAxisSpacing: 10, mainAxisSpacing: 10,
                  ),
                  itemCount: urunler.length,
                  itemBuilder: (context, index) {
                    var urunData = urunler[index].data() as Map<String, dynamic>;
                    String docId = urunler[index].id;
                    return ProductCard(data: urunData, docId: docId);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Yardımcı Widgetlar
  Widget _kategoriKarti({required String id, required String ad, required IconData ikon}) {
    bool isSelected = secilenKategoriId == id;
    return GestureDetector(
      onTap: () { setState(() { secilenKategoriId = id; secilenKategoriAdi = ad; }); },
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? anaRenk : anaRenk.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? null : Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Row(children: [Icon(ikon, color: isSelected ? Colors.white : anaRenk, size: 20), const SizedBox(width: 8), Text(ad, style: TextStyle(color: isSelected ? Colors.white : anaRenk, fontWeight: FontWeight.bold))]),
      ),
    );
  }

  IconData _ikonBul(String kategoriAdi) {
    switch (kategoriAdi.toLowerCase()) {
      case 'kitaplar': return Icons.menu_book;
      case 'elektronik': return Icons.computer;
      case 'ev eşyası': return Icons.chair;
      case 'giyim': return Icons.checkroom;
      case 'ders notu': return Icons.note_alt;
      case 'spor': return Icons.sports_basketball;
      default: return Icons.category;
    }
  }
}

// --- PRODUCT CARD (AYNI KALDI) ---
class ProductCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final String docId;
  const ProductCard({super.key, required this.data, required this.docId});
  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Color anaRenk = const Color(0xFF4A148C);
  bool isFavorite = false;

  @override
  void initState() {
    super.initState();
    _checkFavoriteStatus();
  }

  @override
  void didUpdateWidget(covariant ProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.docId != widget.docId) _checkFavoriteStatus();
  }

  void _checkFavoriteStatus() async {
    if (_auth.currentUser == null) return;
    try {
      var doc = await _firestore.collection('users').doc(_auth.currentUser!.uid).collection('favorites').doc(widget.docId).get();
      if (mounted) setState(() => isFavorite = doc.exists);
    } catch (e) { print("Favori hatası: $e"); }
  }

  void _toggleFavorite() async {
    setState(() => isFavorite = !isFavorite);
    try {
      String uid = _auth.currentUser!.uid;
      var ref = _firestore.collection('users').doc(uid).collection('favorites').doc(widget.docId);
      if (isFavorite) {
        String resimUrl = "";
        if (widget.data.containsKey('image_urls') && (widget.data['image_urls'] is List) && (widget.data['image_urls'] as List).isNotEmpty) {
          resimUrl = (widget.data['image_urls'] as List)[0];
        }
        await ref.set({
          'product_id': widget.docId,
          'name': widget.data['name'] ?? "",
          'price': widget.data['price'] ?? 0,
          'image': resimUrl,
          'added_at': FieldValue.serverTimestamp(),
        });
      } else { await ref.delete(); }
    } catch (e) { print("Favori işlem hatası: $e"); }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailPage(productData: widget.data, docId: widget.docId)));
        _checkFavoriteStatus();
      },
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5, spreadRadius: 2)]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: const BorderRadius.vertical(top: Radius.circular(15))),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                        child: widget.data.containsKey('image_urls') && (widget.data['image_urls'] as List).isNotEmpty
                            ? Image.network((widget.data['image_urls'] as List)[0], fit: BoxFit.cover, errorBuilder: (c, e, s) => Icon(Icons.broken_image, size: 50, color: Colors.grey[400]))
                            : Icon(Icons.shopping_bag, size: 50, color: Colors.grey[400]),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
                      child: GestureDetector(
                        onTap: _toggleFavorite,
                        child: Padding(padding: const EdgeInsets.all(6.0), child: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: Colors.red, size: 20)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.data['name'] ?? "İsimsiz", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text("${widget.data['price']} ₺", style: TextStyle(color: anaRenk, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                    child: Text(widget.data['category_id'] ?? "Genel", style: TextStyle(fontSize: 10, color: Colors.orange[800], fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}