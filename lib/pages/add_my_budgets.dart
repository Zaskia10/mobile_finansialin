import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class AddBudgets extends StatefulWidget {
  const AddBudgets({Key? key}) : super(key: key);

  @override
  State<AddBudgets> createState() => _AddMyBudgets();
}

class _AddMyBudgets extends State<AddBudgets> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();

  late Dio dio;

  List<dynamic> _categories = [];
  int? _selectedCategoryId;
  String _selectedPeriod = 'monthly';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;
  bool _isLoadingCategories = true;

  final List<String> _periods = ['daily', 'weekly', 'monthly', 'yearly'];

  @override
  void initState() {
    super.initState();

    dio = Dio(
      BaseOptions(
        baseUrl: dotenv.env['BASE_URL']!,
        headers: {"Accept": "application/json"},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await AuthService.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );

    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    try {
      final res = await dio.get('/categories');
      if (mounted) {
        setState(() {
          _categories = res.data is Map
              ? (res.data['data'] ?? [])
              : (res.data ?? []);
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      debugPrint("Gagal mengambil kategori: $e");
      if (mounted) {
        setState(() => _isLoadingCategories = false);
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFFC107),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _submitGoal() async {
    if (!_formKey.currentState!.validate() ||
        _startDate == null ||
        _endDate == null ||
        _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap lengkapi semua data dengan benar'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final Map<String, dynamic> payload = {
        "idCategory": _selectedCategoryId,
        "period": _selectedPeriod,
        "periodStart": DateFormat('yyyy-MM-dd').format(_startDate!),
        "periodEnd": DateFormat('yyyy-MM-dd').format(_endDate!),
        "amount": int.parse(
          _amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
        ),
      };

      final response = await ApiService.post('/budgets', payload);

      if (response.statusCode == 201 || response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Anggaran berhasil ditambahkan!',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Color(0xFFFFC107),
          ),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception('Gagal menyimpan anggaran');
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 16.0),
      child: RichText(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          children: const [
            TextSpan(
              text: '*',
              style: TextStyle(color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: Colors.grey.shade500,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: const Color(0xFFF5F5F5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderSide: BorderSide.none,
        borderRadius: BorderRadius.circular(8.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide.none,
        borderRadius: BorderRadius.circular(8.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFFFFC107), width: 1.5),
        borderRadius: BorderRadius.circular(8.0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Tambah Anggaran',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel('Jumlah Anggaran'),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontWeight: FontWeight.w500),
                decoration: _inputDecoration('Rp. 0'),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Masukkan jumlah';
                  return null;
                },
              ),

              _buildLabel('Kategori'),
              _isLoadingCategories
                  ? const Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<int>(
                      decoration: _inputDecoration('Pilih Kategori'),
                      value: _selectedCategoryId,
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.grey,
                      ),
                      items: _categories.map((cat) {
                        return DropdownMenuItem<int>(
                          value: cat['idCategory'] ?? cat['id'],
                          child: Text(
                            cat['name']?.toString() ?? 'Kategori',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setState(() => _selectedCategoryId = val),
                      validator: (val) => val == null ? 'Pilih kategori' : null,
                    ),

              _buildLabel('Periode'),
              DropdownButtonFormField<String>(
                decoration: _inputDecoration('Pilih Periode'),
                value: _selectedPeriod,
                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                items: _periods.map((p) {
                  return DropdownMenuItem<String>(
                    value: p,
                    child: Text(
                      p,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedPeriod = val!),
              ),

              _buildLabel('Tanggal Mulai'),
              InkWell(
                onTap: () => _selectDate(context, true),
                child: IgnorePointer(
                  child: TextFormField(
                    decoration:
                        _inputDecoration(
                          _startDate == null
                              ? 'Pilih tanggal mulai'
                              : DateFormat('yyyy-MM-dd').format(_startDate!),
                        ).copyWith(
                          hintStyle: TextStyle(
                            color: _startDate == null
                                ? Colors.grey.shade500
                                : Colors.black87,
                            fontWeight: _startDate == null
                                ? FontWeight.w400
                                : FontWeight.w500,
                          ),
                        ),
                  ),
                ),
              ),

              _buildLabel('Tanggal Selesai'),
              InkWell(
                onTap: () => _selectDate(context, false),
                child: IgnorePointer(
                  child: TextFormField(
                    decoration:
                        _inputDecoration(
                          _endDate == null
                              ? 'Pilih tanggal selesai'
                              : DateFormat('yyyy-MM-dd').format(_endDate!),
                        ).copyWith(
                          hintStyle: TextStyle(
                            color: _endDate == null
                                ? Colors.grey.shade500
                                : Colors.black87,
                            fontWeight: _endDate == null
                                ? FontWeight.w400
                                : FontWeight.w500,
                          ),
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitGoal,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFC107),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Simpan Anggaran',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
