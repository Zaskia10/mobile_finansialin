import 'package:flutter/material.dart';
import 'transaction_pengeluaran.dart';
import '../widgets/topbar.dart';

class TransactionPemasukan extends StatefulWidget {
  const TransactionPemasukan({Key? key}) : super(key: key);

  @override
  State<TransactionPemasukan> createState() => _TransactionPemasukanState();
}

class _TransactionPemasukanState extends State<TransactionPemasukan> {
  bool _isToday = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CustomAppBar(title: "Tambah Transaksi"),
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
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFC107),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          "Pemasukan",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const TransactionPengeluaran(),
                          ),
                        );
                      },
                      child: Container(
                        color: Colors.transparent,
                        child: const Center(
                          child: Text(
                            "Pengeluaran",
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildLabel("Jumlah Pendapatan"),
            _buildTextField("Rp.0"),
            const SizedBox(height: 16),
            _buildLabel("Kategori"),
            _buildTextField("Pilih Kategori Pemasukan", isDropdown: true),
            const SizedBox(height: 16),
            _buildLabel("Kapan Uang Masuk"),
            _buildTextField("Pilih tanggal", isDropdown: true),
            const SizedBox(height: 12),
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isToday = !_isToday;
                    });
                  },
                  child: Container(
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
                ),
                const SizedBox(width: 8),
                const Text("Hari ini", style: TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              "Bukti Pendapatan",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
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
                    text: const TextSpan(
                      text: "Klik disini ",
                      style: TextStyle(
                        color: Color(0xFFFFC107),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      children: [
                        TextSpan(
                          text: "untuk unggah bukti pendapatan.",
                          style: TextStyle(color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Support Format : JPG, JPEG, SVG, PNG",
                    style: TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  "Simpan Anggaran Pemasukan",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
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
          children: const [
            TextSpan(
              text: "*",
              style: TextStyle(color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String hint, {bool isDropdown = false}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          suffixIcon: isDropdown
              ? const Icon(Icons.keyboard_arrow_down, color: Colors.grey)
              : null,
        ),
      ),
    );
  }
}
