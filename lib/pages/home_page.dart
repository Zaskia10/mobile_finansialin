import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../widgets/navbar.dart';
import 'transaction_pemasukan.dart';
import 'transaction_pengeluaran.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  late Dio dio;

  double income = 0;
  double expense = 0;
  double _totalBalance = 0;
  List<dynamic> transactions = [];
  List<dynamic> resources = [];
  dynamic selectedResourceHome;

  // ✅ FIXED: Hanya satu initState, semua inisialisasi digabung
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

    fetchTransactionsMonth();
    fetchTransactions();
    _fetchTotalBalance();
    fetchResourcesHome();
  }

  Future<void> fetchResourcesHome() async {
    try {
      final res = await dio.get("/resources");
      if (mounted) {
        setState(() {
          // Cek berbagai kemungkinan format response (List langsung atau dalam field 'data')
          if (res.data is List) {
            resources = res.data;
          } else if (res.data is Map && res.data['data'] != null) {
            resources = res.data['data'];
          } else {
            resources = [];
          }
          debugPrint("HOME: Berhasil ambil ${resources.length} dompet");
        });
      }
    } catch (e) {
      debugPrint("HOME: Gagal ambil dompet: $e");
    }
  }

  Future<void> _fetchTotalBalance() async {
    try {
      final res = await ApiService.getResourceSummary();
      if (res['success'] && mounted) {
        setState(() {
          _totalBalance = res['totalBalance'];
        });
      }
    } catch (e) {
      debugPrint("Error fetch total balance: $e");
    }
  }

  Future<void> fetchTransactionsMonth() async {
    try {
      final now = DateTime.now();
      final res = await dio.get("/transactions/month/${now.year}/${now.month}");
      final List<dynamic> dataList = res.data is Map
          ? (res.data['data'] ?? [])
          : res.data;

      double tempIncome = 0;
      double tempExpense = 0;

      for (var item in dataList) {
        if (item['type'] == 'income') {
          tempIncome +=
              double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
        } else if (item['type'] == 'expense') {
          tempExpense +=
              double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
        }
      }

      if (mounted) {
        setState(() {
          income = tempIncome;
          expense = tempExpense;
        });
      }
    } catch (e) {
      // Tetap tampilkan 0 jika gagal
    }
  }

  Future<void> fetchTransactions() async {
    try {
      final res = await dio.get("/transactions");
      final List<dynamic> dataList = res.data is Map
          ? (res.data['data'] ?? [])
          : res.data;
      if (mounted) {
        setState(() {
          transactions = dataList;
        });
      }
    } catch (e) {
      // Tetap tampilkan kosong jika gagal
    }
  }

  Future<void> _navigateToTransaction({required bool isIncome}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            isIncome ? TransactionPemasukan() : TransactionPengeluaran(),
      ),
    );

    if (result == "switch_to_pengeluaran") {
      _navigateToTransaction(isIncome: false);
    } else if (result == "switch_to_pemasukan") {
      _navigateToTransaction(isIncome: true);
    } else if (result == true) {
      _fetchTotalBalance();
      fetchTransactions();
      fetchTransactionsMonth();
      fetchResourcesHome(); // Refresh daftar dompet juga
    }
  }

  String formatCurrency(num value) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(value);
  }

  String formatDate(dynamic date) {
    if (date == null) return '-';
    try {
      final dt = DateTime.parse(date.toString());
      return '${DateFormat('dd MMMM yyyy - HH.mm', 'id_ID').format(dt)} WIB';
    } catch (_) {
      return date.toString();
    }
  }

  Widget _buildHomeContent() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBalanceCard(),
            const SizedBox(height: 20),
            if (income != 0 || expense != 0) _buildIncomeExpense(),
            if (income != 0 || expense != 0) const SizedBox(height: 24),
            _buildMyGoals(),
            const SizedBox(height: 24),
            _buildTracking(),
            const SizedBox(height: 24),
            _buildRecentTransactions(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderPage(String title) {
    return Center(
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return _buildPlaceholderPage('Analisis');
      case 2:
        return _buildPlaceholderPage('Riwayat');
      default:
        return _buildHomeContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToTransaction(isIncome: false),
        backgroundColor: Colors.grey.shade800,
        shape: const CircleBorder(),
        child: const Icon(Icons.blur_on, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: CustomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 3) {
            // Profile → navigate sebagai screen tersendiri
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfilePage()),
            ).then((_) {
              setState(() => _currentIndex = 0);
            });
          } else {
            setState(() {
              _currentIndex = index;
            });
          }
        },
      ),
    );
  }

  Widget _buildBalanceCard() {
    // Tentukan nominal yang ditampilkan
    double displayBalance = _totalBalance;
    String displayTitle = "Total uang kamu sekarang";

    if (selectedResourceHome != null) {
      displayBalance =
          double.tryParse(selectedResourceHome['balance']?.toString() ?? '0') ??
          0;
      displayTitle = "Uang kamu sekarang";
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 12, left: 20, right: 20, bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC107),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Pilihan Sumber Uang (Dompet) - Dibuat lebih simpel tanpa background
              GestureDetector(
                child: Container(
                  padding: EdgeInsets.zero,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<dynamic>(
                      value: selectedResourceHome,
                      hint: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.keyboard_arrow_down, color: Colors.black, size: 20),
                          SizedBox(width: 4),
                          Text(
                            "Pilih sumber uang (dompet)",
                            style: TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      icon: const SizedBox.shrink(), // Sembunyikan ikon bawaan di kanan
                      items: [
                        const DropdownMenuItem<dynamic>(
                          value: null,
                          child: Row(
                            children: [
                              Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey),
                              SizedBox(width: 8),
                              Text("Semua Dompet (Total)", style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                        ...resources.map((res) {
                          return DropdownMenuItem<dynamic>(
                            value: res,
                            child: Row(
                              children: [
                                const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text(res['source']?.toString() ?? '-', style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                      onChanged: (val) {
                        setState(() {
                          selectedResourceHome = val;
                        });
                      },
                    ),
                  ),
                ),
              ),
              const Text(
                "finansialin",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            displayTitle,
            style: const TextStyle(color: Colors.black87, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            formatCurrency(displayBalance),
            style: const TextStyle(
              color: Colors.black,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    "+12% Meningkat dalam 15 hari sebelumnya",
                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _navigateToTransaction(isIncome: true),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "+ Tambah Transaksi",
                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeExpense() {
    return Row(
      children: [
        if (income != 0)
          Expanded(
            child: GestureDetector(
              onTap: () => _navigateToTransaction(isIncome: true),
              child: _buildBox(
                "Pemasukan",
                formatCurrency(income),
                Colors.blue,
                Icons.arrow_downward,
              ),
            ),
          ),
        if (income != 0 && expense != 0) const SizedBox(width: 12),
        if (expense != 0)
          Expanded(
            child: GestureDetector(
              onTap: () => _navigateToTransaction(isIncome: false),
              child: _buildBox(
                "Pengeluaran",
                formatCurrency(expense),
                Colors.red,
                Icons.arrow_upward,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBox(String title, String amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                amount,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMyGoals() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "My Goals",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC107),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  "Add Goals",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildGoalItem(
            icon: Icons.flight,
            title: "Travel",
            current: 2000000,
            target: 5000000,
            percent: 0.5,
          ),
          const SizedBox(height: 24),
          _buildGoalItem(
            icon: Icons.directions_car,
            title: "Car",
            current: 100000000,
            target: 400000000,
            percent: 0.25,
          ),
        ],
      ),
    );
  }

  Widget _buildGoalItem({
    required IconData icon,
    required String title,
    required int current,
    required int target,
    required double percent,
  }) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 24, color: Colors.black),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${formatCurrency(current)} / ${formatCurrency(target)}",
                    style: const TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ],
              ),
            ),
            Text(
              "${(percent * 100).toInt()}%",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFFC107),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildSegmentedProgress(percent),
      ],
    );
  }

  Widget _buildSegmentedProgress(double percent) {
    const totalBars = 10;
    int filledBars = (percent * totalBars).round();

    return Row(
      children: List.generate(totalBars, (index) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            height: 8,
            decoration: BoxDecoration(
              color: index < filledBars
                  ? const Color(0xFFD4B72A)
                  : Colors.black,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTracking() {
    if (income == 0 && expense == 0) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Tracking",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          height: 220,
          width: double.infinity,
          padding: const EdgeInsets.only(
            right: 20,
            left: 4,
            top: 20,
            bottom: 10,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(16),
          ),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                horizontalInterval: 150000,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey.shade200,
                  strokeWidth: 1,
                  dashArray: [5, 5],
                ),
                getDrawingVerticalLine: (value) => FlLine(
                  color: Colors.grey.shade200,
                  strokeWidth: 1,
                  dashArray: [5, 5],
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: 150000,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) {
                        return const Text(
                          '0',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        );
                      }
                      return Text(
                        '${(value / 1000).toInt()}k',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: 5,
              minY: 0,
              maxY: 900000,
              lineBarsData: [
                LineChartBarData(
                  spots: const [
                    FlSpot(0, 720000),
                    FlSpot(1, 650000),
                    FlSpot(2, 850000),
                    FlSpot(3, 500000),
                    FlSpot(4, 380000),
                    FlSpot(5, 250000),
                  ],
                  isCurved: true,
                  color: Colors.black87,
                  barWidth: 2,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 4,
                        color: Colors.white,
                        strokeWidth: 2,
                        strokeColor: Colors.black87,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: const Color(0xFFFFC107).withOpacity(0.25),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentTransactions() {
    if (transactions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          children: [
            Icon(Icons.receipt_long, size: 50, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              "Belum ada transaksi",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Transaksi Terbaru",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...transactions.take(2).map((item) {
          final double parsedAmount =
              double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
          final bool isIncome = item['type'] == 'income';
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildTransactionItem(
              name: item['description'] ?? '-',
              date: formatDate(item['date']),
              amount: "${isIncome ? '+' : '-'}${formatCurrency(parsedAmount)}",
              isIncome: isIncome,
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildTransactionItem({
    required String name,
    required String date,
    required String amount,
    required bool isIncome,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.account_balance, color: Colors.blue),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  date,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              color: isIncome ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
