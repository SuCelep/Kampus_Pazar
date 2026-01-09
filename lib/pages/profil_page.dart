import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';
import 'product_detail_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Renkler
  final Color anaRenk = const Color(0xFF4A148C);
  final Color turuncuRenk = Colors.orange;

  // Varsayılan Avatar Linkleri
  final String defaultMaleImage = "https://cdn-icons-png.flaticon.com/512/3135/3135715.png";
  final String defaultFemaleImage = "https://cdn-icons-png.flaticon.com/512/4140/4140047.png";

  // Durum Kontrolü
  bool isEditing = false;

  // Controllerlar
  final TextEditingController _uniController = TextEditingController();
  final TextEditingController _campusController = TextEditingController();

  // Anlık Seçim Değişkeni
  String selectedGender = "Erkek";

  // İstatistikler
  int soldProductCount = 0;
  int boughtProductCount = 0;

  @override
  void initState() {
    super.initState();
    _getSoldProductCount();
  }

  // Satıştaki Ürün Sayısı (Canlı dinlemek için Stream kullanmak daha mantıklı ama şimdilik böyle kalsın)
  Future<void> _getSoldProductCount() async {
    if (_auth.currentUser == null) return;
    String uid = _auth.currentUser!.uid;
    try {
      var snapshot = await _firestore.collection('products').where('seller_id', isEqualTo: uid).get();
      if (mounted) setState(() => soldProductCount = snapshot.docs.length);
    } catch (e) { print("İstatistik hatası: $e"); }
  }

  // --- İLAN SİLME FONKSİYONU ---
  Future<void> _deleteProduct(String docId) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("İlanı Sil"),
        content: const Text("Bu ürünü satıştan kaldırmak istediğine emin misin?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Vazgeç", style: TextStyle(color: Colors.grey))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Sil", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestore.collection('products').doc(docId).delete();
      _getSoldProductCount(); // Sayacı güncelle
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("İlan silindi."), backgroundColor: Colors.grey));
    }
  }

  // --- PROFİLİ GÜNCELLEME FONKSİYONU ---
  Future<void> _saveProfile() async {
    String uid = _auth.currentUser!.uid;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kaydediliyor...")));

    try {
      await _firestore.collection('users').doc(uid).update({
        'collage_name': _uniController.text.trim(),
        'campus': _campusController.text.trim(),
        'gender': selectedGender,
      });

      if (mounted) {
        setState(() { isEditing = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profil Güncellendi ✅"), backgroundColor: Colors.green));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    if (_auth.currentUser == null) return const SizedBox();
    String uid = _auth.currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Profilim", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: anaRenk,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _signOut, tooltip: "Çıkış Yap"),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError || !snapshot.data!.exists) return const Center(child: Text("Bilgi yüklenemedi."));

          var userData = snapshot.data!.data() as Map<String, dynamic>;

          if (!isEditing) {
            _uniController.text = userData['collage_name'] ?? "";
            _campusController.text = userData['campus'] ?? "";
            if (userData['gender'] != null) selectedGender = userData['gender'];
          }

          boughtProductCount = userData['products_bought_count'] ?? 0;

          // Resim Mantığı
          String displayImage;
          if (userData['profile_image'] != null && userData['profile_image'] != "") {
            displayImage = userData['profile_image'];
          } else {
            displayImage = (selectedGender == "Kadın") ? defaultFemaleImage : defaultMaleImage;
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                // --- ÜST TASARIM ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  decoration: BoxDecoration(
                    color: anaRenk,
                    borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
                  ),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                            child: CircleAvatar(radius: 50, backgroundColor: Colors.white, backgroundImage: NetworkImage(displayImage)),
                          ),
                          Positioned(
                            bottom: 0, right: 0,
                            child: CircleAvatar(
                              radius: 18, backgroundColor: turuncuRenk,
                              child: IconButton(
                                icon: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Resim yükleme yakında!"))),
                              ),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 15),
                      Text(userData['name'] ?? "İsimsiz", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text(userData['email'] ?? "", style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8))),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // --- İSTATİSTİKLER ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _buildStatCard("Satıştaki İlan", soldProductCount.toString(), Icons.sell),
                      const SizedBox(width: 15),
                      _buildStatCard("Satın Alınan", boughtProductCount.toString(), Icons.shopping_bag),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // --- KİŞİSEL BİLGİLER ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Kişisel Bilgiler", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          TextButton.icon(
                            onPressed: () {
                              if (isEditing) _saveProfile();
                              else setState(() => isEditing = true);
                            },
                            icon: Icon(isEditing ? Icons.save : Icons.edit, color: turuncuRenk),
                            label: Text(isEditing ? "Kaydet" : "Düzenle", style: TextStyle(color: turuncuRenk)),
                          )
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildGenderTile(isEditing),
                      const SizedBox(height: 10),
                      _buildInfoTile("Üniversite", Icons.school, _uniController, isEditing),
                      const SizedBox(height: 10),
                      _buildInfoTile("Kampüs", Icons.location_on, _campusController, isEditing),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                // --- YENİ BÖLÜM: SATIŞTAKİ ÜRÜNLERİM ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Align(alignment: Alignment.centerLeft, child: Text("Satıştaki Ürünlerim", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4A148C)))),
                ),
                const SizedBox(height: 10),

                StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('products').where('seller_id', isEqualTo: uid).snapshots(),
                  builder: (context, productSnapshot) {
                    if (productSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                    if (!productSnapshot.hasData || productSnapshot.data!.docs.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Center(child: Text("Satışta hiç ürününüz yok.", style: TextStyle(color: Colors.grey[500]))),
                      );
                    }

                    var myProducts = productSnapshot.data!.docs;

                    return ListView.builder(
                      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                      itemCount: myProducts.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, index) {
                        var pData = myProducts[index].data() as Map<String, dynamic>;
                        String pId = myProducts[index].id;
                        String imgUrl = (pData['image_urls'] != null && (pData['image_urls'] as List).isNotEmpty) ? (pData['image_urls'] as List)[0] : "";

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: anaRenk.withOpacity(0.2))),
                          elevation: 2,
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(10),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: 60, height: 60, color: Colors.grey[200],
                                child: imgUrl.isNotEmpty ? Image.network(imgUrl, fit: BoxFit.cover) : const Icon(Icons.shopping_bag, color: Colors.grey),
                              ),
                            ),
                            title: Text(pData['name'] ?? "İsimsiz", style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("${pData['price']} ₺", style: TextStyle(color: turuncuRenk, fontWeight: FontWeight.bold)),
                            // SİLME İKONU
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _deleteProduct(pId),
                              tooltip: "İlanı Kaldır",
                            ),
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailPage(productData: pData, docId: pId)));
                            },
                          ),
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 25),

                // --- FAVORİ ÜRÜNLER ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Align(alignment: Alignment.centerLeft, child: Text("Favori Ürünlerim", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                ),
                const SizedBox(height: 10),

                StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('users').doc(uid).collection('favorites').orderBy('added_at', descending: true).snapshots(),
                  builder: (context, favSnapshot) {
                    if (favSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    if (!favSnapshot.hasData || favSnapshot.data!.docs.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Center(child: Column(children: [Icon(Icons.favorite_border, size: 40, color: Colors.grey[300]), const SizedBox(height: 10), Text("Henüz favorin yok.", style: TextStyle(color: Colors.grey[500]))])),
                      );
                    }
                    var favorites = favSnapshot.data!.docs;
                    return ListView.builder(
                      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                      itemCount: favorites.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, index) {
                        var favData = favorites[index].data() as Map<String, dynamic>;
                        String favDocId = favorites[index].id;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 2,
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(10),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: 60, height: 60, color: Colors.grey[200],
                                child: (favData['image'] != null && favData['image'] != "") ? Image.network(favData['image'], fit: BoxFit.cover) : const Icon(Icons.shopping_bag, color: Colors.grey),
                              ),
                            ),
                            title: Text(favData['name'] ?? "Ürün Adı", style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("${favData['price']} ₺", style: TextStyle(color: anaRenk, fontWeight: FontWeight.bold)),
                            trailing: IconButton(
                              icon: const Icon(Icons.favorite, color: Colors.red), // Dolu kalp (favoriden çıkarma)
                              onPressed: () async {
                                await _firestore.collection('users').doc(uid).collection('favorites').doc(favDocId).delete();
                              },
                            ),
                            onTap: () {
                              Map<String, dynamic> pData = {'name': favData['name'], 'price': favData['price'], 'image_urls': [favData['image']], 'seller_id': ""};
                              Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailPage(productData: pData, docId: favData['product_id'] ?? favDocId)));
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 50),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- WIDGETLAR ---
  Widget _buildGenderTile(bool editable) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.withOpacity(0.2)), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 5)]),
      child: ListTile(
        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: anaRenk.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.people, color: anaRenk)),
        title: const Text("Cinsiyet", style: TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: editable
            ? DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selectedGender, isDense: true,
            items: ["Erkek", "Kadın"].map((String value) => DropdownMenuItem(value: value, child: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))).toList(),
            onChanged: (newValue) => setState(() => selectedGender = newValue!),
          ),
        )
            : Text(selectedGender, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildInfoTile(String label, IconData icon, TextEditingController controller, bool editable) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.withOpacity(0.2)), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 5)]),
      child: ListTile(
        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: anaRenk.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: anaRenk)),
        title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: editable
            ? TextField(controller: controller, decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
            : Text(controller.text.isNotEmpty ? controller.text : "Belirtilmemiş", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))]),
        child: Column(children: [Icon(icon, color: turuncuRenk, size: 30), const SizedBox(height: 10), Text(count, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(height: 5), Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12))]),
      ),
    );
  }
}