import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/auth_service.dart';

class RiwayatPage extends StatefulWidget {
  const RiwayatPage({super.key});

  @override
  State<RiwayatPage> createState() => _RiwayatPageState();
}

class _RiwayatPageState extends State<RiwayatPage> {
  late Dio dio;

  List<dynamic> transactions = [];
  bool isLoading = true;
  bool isError = false;

  // Filter state
  String selectedFilter = 'Semua';
  final List<String> filterOptions = ['Semua', 'Pemasukan', 'Pengeluaran'];

  @override
  void initState() {
    super.initState();
    dio = Dio(
      BaseOptions(
        baseUrl: dotenv.env['BASE_URL']!,
        headers: {'Accept': 'application/json'},
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

    fetchTransactions();
  }

  Future<void> fetchTransactions() async {
    setState(() {
      isLoading = true;
      isError = false;
    });
    try {
      final res = await dio.get('/transactions');
      final List<dynamic> dataList =
          res.data is Map ? (res.data['data'] ?? []) : res.data;
      if (mounted) {
        setState(() {
          transactions = dataList;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Gagal fetch transactions: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          isError = true;
        });
      }
    }
  }

  String formatCurrency(num value) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(value);
  }

  String formatTime(dynamic date) {
    if (date == null) return '-';
    try {
      final dt = DateTime.parse(date.toString()).toLocal();
      return '${DateFormat('dd MMMM yyyy', 'id_ID').format(dt)} - ${DateFormat('HH.mm').format(dt)} WIB';
    } catch (_) {
      return date.toString();
    }
  }

  List<dynamic> get filteredTransactions {
    if (selectedFilter == 'Pemasukan') {
      return transactions.where((t) => t['type'] == 'income').toList();
    } else if (selectedFilter == 'Pengeluaran') {
      return transactions.where((t) => t['type'] == 'expense').toList();
    }
    return transactions;
  }

  /// Group transaksi berdasarkan tanggal
  Map<String, List<dynamic>> _groupByDate(List<dynamic> txList) {
    final Map<String, List<dynamic>> grouped = {};

    // Pisahkan "Transaksi Terbaru" (3 terbaru) dan sisanya
    final recentItems = txList.take(3).toList();
    final olderItems = txList.skip(3).toList();

    if (recentItems.isNotEmpty) {
      grouped['__recent__'] = recentItems;
    }

    for (var tx in olderItems) {
      try {
        final dt = DateTime.parse(tx['date'].toString()).toLocal();
        final dateKey = DateFormat('yyyy-MM-dd').format(dt);
        grouped.putIfAbsent(dateKey, () => []);
        grouped[dateKey]!.add(tx);
      } catch (_) {
        grouped.putIfAbsent('__unknown__', () => []);
        grouped['__unknown__']!.add(tx);
      }
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFilterChips(),
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFFC107),
                        strokeWidth: 2,
                      ),
                    )
                  : isError
                      ? _buildErrorState()
                      : filteredTransactions.isEmpty
                          ? _buildEmptyState()
                          : _buildTransactionList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Riwayat',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          GestureDetector(
            onTap: fetchTransactions,
            child: const Icon(Icons.refresh, color: Colors.black, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      child: Row(
        children: filterOptions.map((filter) {
          final isSelected = selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => selectedFilter = filter),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFFFC107)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFFFC107)
                        : Colors.grey.shade300,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFFC107).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Text(
                  filter,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.w500,
                    color: isSelected ? Colors.black : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTransactionList() {
    final grouped = _groupByDate(filteredTransactions);

    return RefreshIndicator(
      color: const Color(0xFFFFC107),
      onRefresh: fetchTransactions,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: grouped.keys.length,
        itemBuilder: (context, index) {
          final key = grouped.keys.elementAt(index);
          final items = grouped[key]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Header
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 12),
                child: Text(
                  key == '__recent__'
                      ? 'Transaksi Terbaru'
                      : key == '__unknown__'
                          ? 'Tanggal tidak diketahui'
                          : _formatDateHeader(key),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              // Transaction Items
              ...items.map((tx) => _buildTransactionCard(tx)),
              const SizedBox(height: 4),
            ],
          );
        },
      ),
    );
  }

  String _formatDateHeader(String dateKey) {
    try {
      final dt = DateTime.parse(dateKey);
      return DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(dt);
    } catch (_) {
      return dateKey;
    }
  }

  Widget _buildTransactionCard(dynamic tx) {
    final double amount =
        double.tryParse(tx['amount']?.toString() ?? '0') ?? 0.0;
    final bool isIncome = tx['type'] == 'income';
    final String description = tx['description'] ?? '-';
    final String timeText = formatTime(tx['date']);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isIncome
                  ? Icons.arrow_downward_rounded
                  : Icons.account_balance,
              color: Colors.blue.shade600,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  timeText,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Amount
          Text(
            '${isIncome ? '+' : '-'}${formatCurrency(amount)}',
            style: TextStyle(
              color: isIncome ? Colors.green.shade600 : Colors.red.shade600,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFFFC107).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 60,
              color: Color(0xFFFFC107),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Belum ada transaksi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            selectedFilter != 'Semua'
                ? 'Tidak ada transaksi $selectedFilter'
                : 'Tambah transaksi pertamamu\ndi halaman beranda',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 60, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Gagal memuat riwayat',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Periksa koneksi internet kamu',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: fetchTransactions,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Coba Lagi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC107),
              foregroundColor: Colors.black,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
