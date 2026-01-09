import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_page.dart'; // Başarılı olunca ana sayfaya dönmek için

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  // Renkler
  final Color anaRenk = const Color(0xFF4A148C);
  final Color turuncuRenk = Colors.orange;

  // Form Kontrolü
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;

  // Controllerlar
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _imageController = TextEditingController(); // Resim Linki için

  // Kategori Seçimi
  String? selectedCategoryId;
  String? selectedCategoryName;
  List<QueryDocumentSnapshot> categories = [];

  @override
  void initState() {
    super.initState();
    _getCategories();
  }

  // Kategorileri Çek
  Future<void> _getCategories() async {
    var snapshot = await FirebaseFirestore.instance.collection('categories').orderBy('name').get();
    setState(() {
      categories = snapshot.docs;
    });
  }

  // Kategoriye Göre Varsayılan Resim Bul (Eğer resim yüklemezse)
  String _getDefaultImageForCategory(String catName) {
    switch (catName.toLowerCase()) {
      case 'kitaplar': return "https://cdn-icons-png.flaticon.com/512/2232/2232688.png";
      case 'elektronik': return "https://cdn-icons-png.flaticon.com/512/3659/3659899.png";
      case 'ev eşyası': return "https://cdn-icons-png.flaticon.com/512/2558/2558066.png"; // Koltuk ikonu
      case 'giyim': return "https://cdn-icons-png.flaticon.com/512/3050/3050253.png";
      case 'ders notu': return "https://cdn-icons-png.flaticon.com/512/2965/2965335.png";
      case 'spor': return "https://cdn-icons-png.flaticon.com/512/2964/2964514.png";
      default: return "https://cdn-icons-png.flaticon.com/512/1170/1170576.png"; // Genel alışveriş ikonu
    }
  }

  // İLAN YAYINLA
  Future<void> _publishProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen bir kategori seçin!"), backgroundColor: Colors.red));
      return;
    }

    setState(() => isLoading = true);

    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;

      // Kullanıcının okul bilgilerini çekelim (İlana eklemek için)
      var userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      var userData = userDoc.data() as Map<String, dynamic>;

      // Resim URL Belirleme
      String finalImage = _imageController.text.trim();
      if (finalImage.isEmpty) {
        // Resim yoksa kategoriye uygun default resmi koy
        finalImage = _getDefaultImageForCategory(selectedCategoryName ?? "");
      }

      // Veritabanına Ekle
      await FirebaseFirestore.instance.collection('products').add({
        'name': _nameController.text.trim(),
        'price': double.parse(_priceController.text.trim()),
        'description': _descController.text.trim(),
        'category_id': selectedCategoryId,
        'image_urls': [finalImage], // Liste formatında kaydediyoruz
        'seller_id': uid,
        'university': userData['collage_name'] ?? "",
        'campüs': userData['campüs'] ?? "",
        'created_at': FieldValue.serverTimestamp(),
        'is_sold': false, // Satılmadı olarak başlar
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("İlanın başarıyla yayınlandı! 🚀"), backgroundColor: Colors.green));

        // Formu temizle
        _nameController.clear();
        _priceController.clear();
        _descController.clear();
        _imageController.clear();
        setState(() => selectedCategoryId = null);

        // Ana Sayfaya Yönlendir
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomePage()));
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("İlan Ver", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: anaRenk,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- RESİM ALANI (OPSİYONEL) ---
              const Text("Ürün Görseli", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.add_photo_alternate, size: 50, color: Colors.grey),
                    const SizedBox(height: 10),
                    const Text("Resim linki yapıştırabilirsin (İsteğe Bağlı)", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _imageController,
                      decoration: _inputDecoration("Resim URL (https://...)"),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 5),
                    const Text("* Boş bırakırsan kategoriye uygun ikon atanır.", style: TextStyle(fontSize: 11, color: Colors.orange)),
                  ],
                ),
              ),
              const SizedBox(height: 25),

              // --- KATEGORİ SEÇİMİ ---
              const Text("Kategori", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedCategoryId,
                decoration: _inputDecoration("Kategori Seç"),
                items: categories.map((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  return DropdownMenuItem(
                    value: doc.id,
                    child: Text(data['name']),
                    onTap: () {
                      selectedCategoryName = data['name'];
                    },
                  );
                }).toList(),
                onChanged: (val) => setState(() => selectedCategoryId = val),
              ),
              const SizedBox(height: 20),

              // --- ÜRÜN ADI ---
              _buildLabel("Ürün Başlığı"),
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration("Örn: Matematik 1 Ders Notu"),
                validator: (value) => value!.isEmpty ? "Başlık girmelisin" : null,
              ),
              const SizedBox(height: 20),

              // --- FİYAT ---
              _buildLabel("Fiyat (₺)"),
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration("0.00"),
                validator: (value) => value!.isEmpty ? "Fiyat girmelisin" : null,
              ),
              const SizedBox(height: 20),

              // --- AÇIKLAMA ---
              _buildLabel("Açıklama"),
              TextFormField(
                controller: _descController,
                maxLines: 4,
                decoration: _inputDecoration("Ürünün durumu, özellikleri vb..."),
                validator: (value) => value!.isEmpty ? "Açıklama girmelisin" : null,
              ),
              const SizedBox(height: 30),

              // --- YAYINLA BUTONU ---
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : _publishProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: turuncuRenk,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  icon: isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check_circle, color: Colors.white),
                  label: Text(
                    isLoading ? "Yayınlanıyor..." : "İlanı Yayınla",
                    style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Tasarım Yardımcıları
  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400]),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: anaRenk, width: 2)),
      filled: true,
      fillColor: Colors.grey[50],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }
}