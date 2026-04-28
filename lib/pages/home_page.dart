import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../widgets/navbar.dart';
import '../services/api_service.dart';
import 'transaction_pemasukan.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  double _totalBalance = 0.0;
  bool _isLoadingBalance = true;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    setState(() => _isLoadingBalance = true);
    try {
      final result = await ApiService.getResourceSummary();
      if (mounted) {
        setState(() {
          _totalBalance = result['totalBalance'] ?? 0.0;
        });
      }
    } catch (_) {
      // Tetap tampilkan 0 jika gagal
    } finally {
      if (mounted) setState(() => _isLoadingBalance = false);
    }
  }

  String _formatRupiah(double amount) {
    // Format angka ke Rupiah: Rp 500.000
    final parts = amount.toStringAsFixed(0).split('');
    final buffer = StringBuffer();
    for (int i = 0; i < parts.length; i++) {
      if (i != 0 && (parts.length - i) % 3 == 0) buffer.write('.');
      buffer.write(parts[i]);
    }
    return 'Rp ${buffer.toString()}';
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
            _buildIncomeExpense(),
            const SizedBox(height: 24),
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

  late Dio dio;

  double income = 0;
  double expense = 0;
  List<dynamic> transactions = [];

  @override
  void initState() {
    super.initState();

    dio = Dio(
      BaseOptions(
        baseUrl: dotenv.env['BASE_URL']!,
        headers: {"Accept": "application/json"},
      ),
    );

    fetchTransactionsMonth();
    fetchTransactions();
  }

  Future<void> fetchTransactionsMonth() async {
    try {
      final now = DateTime.now();
      final res = await dio.get("/transactions/month/${now.year}/${now.month}");

      double tempIncome = 0;
      double tempExpense = 0;

      for (var item in res.data) {
        if (item['type'] == 'income') {
          tempIncome += (item['amount'] as num).toDouble();
        } else if (item['type'] == 'expense') {
          tempExpense += (item['amount'] as num).toDouble();
        }
      }

      setState(() {
        income = tempIncome;
        expense = tempExpense;
      });
    } catch (e) {}
  }

  Future<void> fetchTransactions() async {
    try {
      final res = await dio.get("/transactions");
      setState(() {
        transactions = res.data;
      });
    } catch (e) {}
  }

  String formatCurrency(num value) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp. ',
      decimalDigits: 0,
    ).format(value);
  }

  String formatDate(String date) {
    final dt = DateTime.parse(date);
    return DateFormat('dd MMMM yyyy - HH.mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
<<<<<<< HEAD
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeContent(),                    // index 0 - Beranda
          _buildPlaceholderPage('Analisis'),       // index 1 - Analisis
          _buildPlaceholderPage('Riwayat'),        // index 2 - Riwayat
          const ProfilePage(),                     // index 3 - Profile
        ],
=======
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBalanceCard(),
              const SizedBox(height: 20),
              if (income != 0 || expense != 0) _buildIncomeExpense(),
              const SizedBox(height: 24),
              _buildMyGoals(),
              const SizedBox(height: 24),
              _buildTracking(),
              const SizedBox(height: 24),
              _buildRecentTransactions(),
              const SizedBox(height: 40),
            ],
          ),
        ),
>>>>>>> a835c875fb48d86e0fcff8dfc8b1749799b5f2d1
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: Colors.grey.shade800,
        shape: const CircleBorder(),
        child: const Icon(Icons.blur_on, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: CustomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC107),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Align(
            alignment: Alignment.topRight,
            child: Text(
              "finansialin",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const Text(
            "Uang kamu sekarang",
            style: TextStyle(color: Colors.black87, fontSize: 14),
          ),
          const SizedBox(height: 4),
          _isLoadingBalance
              ? const SizedBox(
                  height: 36,
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black54,
                    ),
                  ),
                )
              : Text(
                  _formatRupiah(_totalBalance),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "+12% Meningkat dalam 15 hari sebelumnya",
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TransactionPemasukan(),
                    ),
                  );
                },
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
            child: _buildBox(
              "Pemasukan",
              formatCurrency(income),
              Colors.blue,
              Icons.arrow_downward,
            ),
          ),
        if (income != 0 && expense != 0) const SizedBox(width: 12),
        if (expense != 0)
          Expanded(
            child: _buildBox(
              "Pengeluaran",
              formatCurrency(expense),
              Colors.red,
              Icons.arrow_upward,
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
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
            Icon(icon, size: 36, color: Colors.black),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${formatCurrency(current)} / ${formatCurrency(target)}",
                    style: const TextStyle(fontSize: 16, color: Colors.green),
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
            height: 10,
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(16),
          ),
          child: LineChart(LineChartData()),
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
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildTransactionItem(
              name: item['description'] ?? '-',
              date: formatDate(item['date']),
              amount:
                  "${item['type'] == 'expense' ? '-' : '+'}${formatCurrency(item['amount'])}",
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
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
