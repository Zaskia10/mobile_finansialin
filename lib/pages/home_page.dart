import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/auth_service.dart';
import '../widgets/navbar.dart';
import 'transaction_pemasukan.dart';
import 'transaction_pengeluaran.dart';
import 'profile_page.dart';
import 'chatbot_page.dart';
import 'add_goal_page.dart';

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
  List<dynamic> goals = [];
  dynamic selectedResourceHome;

  List<FlSpot> chartData = [];
  String percentageText = "";

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

    _fetchAllData();
  }

  void _fetchAllData() {
    fetchResourcesHome();
    fetchTotalBalance();
    fetchTransactionsMonth();
    fetchTransactions();
    fetchGoals();
    fetchDashboardSummary();
  }

  Future<void> fetchResourcesHome() async {
    try {
      final res = await dio.get("/resources");
      if (mounted) {
        setState(() {
          if (res.data is List) {
            resources = res.data;
          } else if (res.data is Map && res.data['data'] != null) {
            resources = res.data['data'];
          } else {
            resources = [];
          }
        });
      }
    } catch (e) {
      debugPrint("Gagal fetch resources: $e");
    }
  }

  Future<void> fetchTotalBalance() async {
    try {
      final res = await dio.get("/resources/summary");
      if (mounted) {
        setState(() {
          _totalBalance =
              double.tryParse(
                res.data['data']?['totalBalance']?.toString() ?? '0',
              ) ??
              0.0;
        });
      }
    } catch (e) {
      debugPrint("Gagal fetch total balance: $e");
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
      debugPrint("Gagal fetch monthly transactions: $e");
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
      debugPrint("Gagal fetch transactions: $e");
    }
  }

  Future<void> fetchGoals() async {
    try {
      final res = await dio.get("/budgets/goals");
      final List<dynamic> dataList = res.data is Map
          ? (res.data['data'] ?? [])
          : res.data;
      if (mounted) {
        setState(() {
          goals = dataList;
        });
      }
    } catch (e) {
      try {
        final resFallback = await dio.get("/budgets");
        final List<dynamic> fallbackList = resFallback.data is Map
            ? (resFallback.data['data'] ?? [])
            : resFallback.data;
        if (mounted) {
          setState(() {
            goals = fallbackList;
          });
        }
      } catch (eFallback) {
        debugPrint("Gagal fetch goals: $eFallback");
      }
    }
  }

  Future<void> fetchDashboardSummary() async {
    try {
      final res = await dio.get("/dashboard-summary");
      final data = res.data is Map ? (res.data['data'] ?? {}) : {};

      if (mounted) {
        setState(() {
          percentageText =
              data['percentage_text']?.toString() ?? "Tidak ada data";

          if (data['chart_data'] != null && data['chart_data'] is List) {
            chartData = (data['chart_data'] as List).map((point) {
              return FlSpot(
                double.tryParse(point['x'].toString()) ?? 0,
                double.tryParse(point['y'].toString()) ?? 0,
              );
            }).toList();
          } else {
            chartData = [];
          }
        });
      }
    } catch (e) {
      debugPrint("Gagal fetch dashboard summary: $e");
      if (mounted) {
        setState(() {
          percentageText = "Gagal memuat data";
        });
      }
    }
  }

  Future<void> _navigateToTransaction({required bool isIncome}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => isIncome
            ? const TransactionPemasukan()
            : const TransactionPengeluaran(),
      ),
    );

    if (result == "switch_to_pengeluaran") {
      _navigateToTransaction(isIncome: false);
    } else if (result == "switch_to_pemasukan") {
      _navigateToTransaction(isIncome: true);
    } else if (result == true) {
      _fetchAllData();
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
      final dt = DateTime.parse(date.toString()).toLocal();
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
        return const AIAssistantScreen();
      case 3:
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
          if (index == 4) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfilePage()),
            ).then((_) {
              setState(() => _currentIndex = 0);
              _fetchAllData();
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
              GestureDetector(
                child: Container(
                  padding: EdgeInsets.zero,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<dynamic>(
                      value: selectedResourceHome,
                      hint: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.black,
                            size: 20,
                          ),
                          SizedBox(width: 4),
                          Text(
                            "Pilih sumber uang (dompet)",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      icon: const SizedBox.shrink(),
                      items: [
                        const DropdownMenuItem<dynamic>(
                          value: null,
                          child: Row(
                            children: [
                              Icon(
                                Icons.keyboard_arrow_down,
                                size: 18,
                                color: Colors.grey,
                              ),
                              SizedBox(width: 8),
                              Text(
                                "Semua Dompet (Total)",
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        ...resources.map((res) {
                          return DropdownMenuItem<dynamic>(
                            value: res,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.keyboard_arrow_down,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  res['source']?.toString() ?? '-',
                                  style: const TextStyle(fontSize: 12),
                                ),
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
                  child: Text(
                    percentageText.isNotEmpty
                        ? percentageText
                        : "Menghitung data...", 
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                    ),
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
              GestureDetector(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddGoalPage(),
                    ),
                  );
                  if (result == true) {
                    _fetchAllData();
                  }
                },
                child: Container(
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
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (goals.isEmpty)
            const Text(
              "Belum ada goals yang dibuat.",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ...goals.map((goal) {
            final String title =
                goal['category']?['name'] ?? goal['name'] ?? 'Goal';
            final double target =
                double.tryParse(goal['amount']?.toString() ?? '0') ?? 0.0;
            final double current =
                double.tryParse(
                  goal['usage']?.toString() ??
                      goal['current']?.toString() ??
                      '0',
                ) ??
                0.0;
            final double percent = target > 0 ? (current / target) : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: _buildGoalItem(
                icon: Icons.track_changes,
                title: title,
                current: current,
                target: target,
                percent: percent > 1.0 ? 1.0 : percent,
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildGoalItem({
    required IconData icon,
    required String title,
    required double current,
    required double target,
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
    bool isChartZero =
        chartData.isEmpty || chartData.every((spot) => spot.y == 0);

    if (income == 0 && expense == 0 && isChartZero) {
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
          child: chartData.isEmpty
              ? const Center(
                  child: Text(
                    "Memuat data grafik...",
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : LineChart(
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
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
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
                    lineBarsData: [
                      LineChartBarData(
                        spots: chartData,
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
