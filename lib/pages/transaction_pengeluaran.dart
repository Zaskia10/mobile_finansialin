import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'transaction_pemasukan.dart';
import '../widgets/topbar.dart';
import '../services/auth_service.dart';
import 'scan_receipt_page.dart';

class TransactionPengeluaran extends StatefulWidget {
  const TransactionPengeluaran({Key? key}) : super(key: key);

  @override
  State<TransactionPengeluaran> createState() => _TransactionPengeluaranState();
}

class _TransactionPengeluaranState extends State<TransactionPengeluaran> {
  bool _isToday = false;

  late Dio dio;

  final TextEditingController amountController = TextEditingController();
  final TextEditingController dateController = TextEditingController();

  List<dynamic> categories = [];
  dynamic selectedCategory;
  bool isLoadingCategories = true;
  bool isErrorCategories = false;

  List<dynamic> resources = [];
  dynamic selectedResource;
  bool isLoadingResources = true;
  bool isErrorResources = false;

  DateTime? selectedDate;

  Uint8List? receiptImageBytes;
  XFile? receiptXFile;
  final ImagePicker _picker = ImagePicker();

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    dio = Dio(
      BaseOptions(
        baseUrl: dotenv.env['BASE_URL']!,
        connectTimeout: const Duration(seconds: 5), // Maksimal 5 detik untuk konek
        receiveTimeout: const Duration(seconds: 5), // Maksimal 5 detik untuk terima data
        headers: {"Accept": "application/json"},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await AuthService.getToken();
          debugPrint("TOKEN SAAT INI: ${token != null ? 'Tersedia' : 'KOSONG!'}");
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );

    fetchCategories();
    fetchResources();
  }

  Future<void> fetchCategories() async {
    setState(() {
      isLoadingCategories = true;
      isErrorCategories = false;
    });
    try {
      final res = await dio.get("/categories");
      debugPrint("DEBUG KATEGORI RAW: ${res.data}"); // Log ini penting
      setState(() {
        final dynamic rawData = res.data is Map ? res.data['data'] : res.data;
        categories = rawData is List ? rawData : [];
        isLoadingCategories = false;
        isErrorCategories = false;
      });
      debugPrint("KATEGORI BERHASIL DI-PARSE: ${categories.length} item");
    } catch (e) {
      debugPrint("GAGAL FETCH KATEGORI: $e");
      setState(() {
        isLoadingCategories = false;
        isErrorCategories = true;
      });
    }
  }

  Future<void> fetchResources() async {
    setState(() {
      isLoadingResources = true;
      isErrorResources = false;
    });
    try {
      final res = await dio.get("/resources");
      debugPrint("Resources Response: ${res.data}");
      setState(() {
        final dynamic rawData = res.data is Map ? res.data['data'] : res.data;
        resources = rawData is List ? rawData : [];
        isLoadingResources = false;
        isErrorResources = false;
      });
      if (resources.isNotEmpty) debugPrint("RESOURCES BERHASIL: ${resources.length} item");
    } catch (e) {
      debugPrint("Gagal fetch resources: $e");
      setState(() {
        isLoadingResources = false;
        isErrorResources = true;
      });
    }
  }

  String formatCurrency(num value) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(value);
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFFFC107),
            onPrimary: Colors.white,
            onSurface: Colors.black87,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
        _isToday = false;
        dateController.text = DateFormat('dd MMM yyyy').format(picked);
      });
    }
  }

  Future<void> _selectImage(ImageSource source) async {
    final xfile = await _picker.pickImage(
      source: source,
      maxWidth: 1920,
      imageQuality: 85,
    );
    if (xfile != null) {
      final bytes = await xfile.readAsBytes();
      setState(() {
        receiptXFile = xfile;
        receiptImageBytes = bytes;
      });
    }
  }

  Future<void> pickImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            if (!kIsWeb)
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFFFFC107)),
                title: const Text("Ambil dari Kamera"),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _selectImage(ImageSource.camera);
                },
              ),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: Color(0xFFFFC107),
              ),
              title: const Text("Pilih dari Galeri"),
              onTap: () async {
                Navigator.pop(ctx);
                await _selectImage(ImageSource.gallery);
              },
            ),
            if (receiptImageBytes != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  "Hapus Gambar",
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    receiptImageBytes = null;
                    receiptXFile = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  void _setToday() {
    setState(() {
      _isToday = !_isToday;
      if (_isToday) {
        selectedDate = DateTime.now();
        dateController.text = DateFormat('dd MMM yyyy').format(DateTime.now());
      } else {
        selectedDate = null;
        dateController.clear();
      }
    });
  }

  Future<void> _scanReceipt() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScanReceiptPage()),
    );
    if (result != null && result is XFile) {
      final bytes = await result.readAsBytes();
      setState(() {
        receiptXFile = result;
        receiptImageBytes = bytes;
      });
    }
  }

  Future<void> saveTransaction() async {
    if (amountController.text.isEmpty || selectedCategory == null || selectedResource == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Jumlah, kategori, dan dompet wajib diisi"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final DateTime finalDate = _isToday
          ? DateTime.now()
          : (selectedDate ?? DateTime.now());

      final cleanAmount = amountController.text.replaceAll(RegExp(r'[^0-9]'), '');

      // Coba ambil ID kategori dari key yang mungkin berbeda
      final dynamic catId = selectedCategory['idCategory'] ?? selectedCategory['id'];

      // DEBUG LOG — akan tampil di terminal flutter
      debugPrint("=== DEBUG SAVE ===");
      debugPrint("selectedCategory: $selectedCategory");
      debugPrint("catId: $catId");

      final Map<String, dynamic> formFields = {
        "type": "expense",
        "amount": cleanAmount,
        "description": selectedCategory['name'] ?? '',
        "date": finalDate.toIso8601String(),
      };

      // Hanya kirim idCategory jika tidak null
      if (catId != null) formFields["idCategory"] = catId;

      // Kirim idResource (Wajib)
      if (selectedResource != null) {
        formFields["idResource"] = selectedResource['idResource'];
      }

      await dio.post("/transactions", data: FormData.fromMap(formFields));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Transaksi berhasil disimpan"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      // DEBUG: cetak detail error dari backend
      if (e is DioException && e.response != null) {
        debugPrint("=== ERROR RESPONSE ===");
        debugPrint("Status: ${e.response?.statusCode}");
        debugPrint("Body: ${e.response?.data}");
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal menyimpan transaksi: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) setState(() => isLoading = false);
  }

  @override
  void dispose() {
    amountController.dispose();
    dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: "Tambah Transaksi",
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Colors.black),
            onPressed: _scanReceipt,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        // Kembali ke home dengan instruksi pindah ke pemasukan
                        Navigator.pop(context, "switch_to_pemasukan");
                      },
                      child: const Center(
                        child: Text(
                          "Pemasukan",
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFC107),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          "Pengeluaran",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _buildLabel("Jumlah Pengeluaran"),
            _buildTextField(
              "Rp. 0",
              controller: amountController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            _buildLabel("Kategori"),
            _buildDropdown(
              hint: "Pilih Kategori Pengeluaran",
              value: selectedCategory,
              items: categories,
              isLoading: isLoadingCategories,
              isError: isErrorCategories,
              onChanged: (val) => setState(() => selectedCategory = val),
              onRetry: fetchCategories,
            ),
            const SizedBox(height: 16),

            _buildLabel("Sumber Dana (Dompet)"),
            _buildDropdown(
              hint: "Pilih Dompet",
              value: selectedResource,
              items: resources,
              isLoading: isLoadingResources,
              isError: isErrorResources,
              onChanged: (val) {
                setState(() {
                  selectedResource = val;
                });
              },
              onRetry: fetchResources,
              isRequired: true,
            ),
            if (selectedResource != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(
                  "Saldo tersedia: ${formatCurrency(double.tryParse(selectedResource!['balance']?.toString() ?? '0') ?? 0)}",
                  style: TextStyle(
                    fontSize: 12,
                    color: (double.tryParse(selectedResource!['balance']?.toString() ?? '0') ?? 0) > 0
                        ? Colors.green
                        : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 16),

            _buildLabel("Kapan Uang Keluar"),
            GestureDetector(
              onTap: _isToday ? null : pickDate,
              child: AbsorbPointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: _isToday
                        ? Colors.grey.shade100
                        : const Color(0xFFF8F8F8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: TextField(
                    controller: dateController,
                    enabled: !_isToday,
                    decoration: InputDecoration(
                      hintText: "Pilih tanggal",
                      hintStyle: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      suffixIcon: Icon(
                        Icons.calendar_today,
                        color: _isToday ? Colors.grey.shade400 : Colors.grey,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            GestureDetector(
              onTap: _setToday,
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isToday ? const Color(0xFFFFC107) : Colors.grey,
                        width: 1.5,
                      ),
                    ),
                    child: _isToday
                        ? Center(
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFFFC107),
                              ),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  const Text("Hari ini", style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              "Bukti Pembayaran",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: pickImage,
              child: receiptImageBytes != null
                  ? _buildImagePreview()
                  : _buildUploadPlaceholder("bukti pembayaran"),
            ),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: isLoading ? null : saveTransaction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107),
                  disabledBackgroundColor: Colors.grey.shade300,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        "Simpan Anggaran Pengeluaran",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, {bool isRequired = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: RichText(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          children: isRequired
              ? const [
                  TextSpan(
                    text: " *",
                    style: TextStyle(color: Colors.red),
                  ),
                ]
              : [],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String hint, {
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String hint,
    required dynamic value,
    required List<dynamic> items,
    required bool isLoading,
    required bool isError,
    required ValueChanged<dynamic> onChanged,
    required VoidCallback onRetry,
    bool isRequired = true,
  }) {
    final containerDeco = BoxDecoration(
      color: const Color(0xFFF8F8F8),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.grey.shade200),
    );

    if (isLoading) {
      return Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: containerDeco,
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFFFC107),
              ),
            ),
            SizedBox(width: 12),
            Text(
              "Memuat data...",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (isError) {
      return Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: containerDeco.copyWith(
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.orange, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                "Gagal memuat, cek koneksi",
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(64, 36),
                foregroundColor: const Color(0xFFFFC107),
              ),
              child: const Text("Coba lagi", style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: containerDeco,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<dynamic>(
          value: value,
          hint: Text(
            hint,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          isExpanded: true,
          items: items
              .map(
                (item) {
                  // Cek apakah ini Kategori (pakai 'name') atau Sumber Dana (pakai 'source')
                  final String label = item['name']?.toString() ?? item['source']?.toString() ?? '-';
                  return DropdownMenuItem(
                    value: item,
                    child: Text(
                      label,
                      style: const TextStyle(color: Colors.black, fontSize: 14),
                    ),
                  );
                },
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildUploadPlaceholder(String label) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.note_add_rounded,
            color: Color(0xFFFFC107),
            size: 40,
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              text: "Klik disini ",
              style: const TextStyle(
                color: Color(0xFFFFC107),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              children: [
                TextSpan(
                  text: "untuk unggah $label.",
                  style: const TextStyle(color: Colors.black87),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Support Format : JPG, JPEG, PNG, WEBP (maks. 4MB)",
            style: TextStyle(color: Colors.grey, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            receiptImageBytes!,
            width: double.infinity,
            height: 180,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: () => setState(() {
              receiptImageBytes = null;
              receiptXFile = null;
            }),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          right: 8,
          child: GestureDetector(
            onTap: pickImage,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFC107),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                "Ganti",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
