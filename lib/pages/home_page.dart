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
import 'add_my_budgets.dart';
import 'riwayat_page.dart';
import 'analisis_page.dart';

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
  String percentageText = "0%";
  bool _isLoading = true;

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

  Future<void> _fetchAllData() async {
    if (mounted) setState(() => _isLoading = true);
    await Future.wait([
      fetchResourcesHome(),
      fetchTotalBalance(),
      fetchTransactionsMonth(),
      fetchTransactions(),
      fetchGoals(),
      fetchDashboardSummary(),
      _calculateMonthPercentage(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _calculateMonthPercentage() async {
    try {
      final now = DateTime.now();
      final results = await Future.wait([
        dio.get("/resources/summary"),
        dio.get("/transactions/month/${now.year}/${now.month}"),
      ]);

      final resSummary = results[0];
      final resTx = results[1];

      if (resSummary.statusCode == 200 && resTx.statusCode == 200) {
        double currentBalance =
            double.tryParse(
              resSummary.data['data']?['totalBalance']?.toString() ?? '0',
            ) ??
            0.0;

        final List<dynamic> dataList = resTx.data is Map
            ? (resTx.data['data'] ?? [])
            : resTx.data;

        double thisMonthIncome = 0;
        double thisMonthExpense = 0;

        for (var item in dataList) {
          double amt =
              double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
          if (item['type'] == 'income') {
            thisMonthIncome += amt;
          } else if (item['type'] == 'expense') {
            thisMonthExpense += amt;
          }
        }

        double lastMonthBalance =
            currentBalance - (thisMonthIncome - thisMonthExpense);

        if (lastMonthBalance <= 0) {
          if (mounted) setState(() => percentageText = "+100%");
        } else {
          double percentage =
              ((currentBalance - lastMonthBalance) / lastMonthBalance) * 100;
          String sign = percentage >= 0 ? "+" : "";
          if (mounted) {
            setState(
              () => percentageText = "$sign${percentage.toStringAsFixed(0)}%",
            );
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => percentageText = "0%");
    }
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
    } catch (e) {}
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
    } catch (e) {}
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
        double amt = double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
        if (item['type'] == 'income') {
          tempIncome += amt;
        } else if (item['type'] == 'expense') {
          tempExpense += amt;
        }
      }

      if (mounted) {
        setState(() {
          income = tempIncome;
          expense = tempExpense;
        });
      }
    } catch (e) {}
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
    } catch (e) {}
  }

  Future<void> fetchGoals() async {
    try {
      final res = await dio.get("/budgets/goals");
      final List<dynamic> dataList = res.data is Map
          ? (res.data['data'] ?? [])
          : res.data;
      if (mounted) setState(() => goals = dataList);
    } catch (e) {
      try {
        final resFallback = await dio.get("/budgets");
        final List<dynamic> fallbackList = resFallback.data is Map
            ? (resFallback.data['data'] ?? [])
            : resFallback.data;
        if (mounted) setState(() => goals = fallbackList);
      } catch (eFallback) {}
    }
  }

  Future<void> fetchDashboardSummary() async {
    try {
      final res = await dio.get("/dashboard-summary");
      final data = res.data is Map ? (res.data['data'] ?? {}) : {};

      if (mounted) {
        setState(() {
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
    } catch (e) {}
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
      symbol: 'Rp. ',
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
      child: RefreshIndicator(
        onRefresh: _fetchAllData,
        color: const Color(0xFFFFC107),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBalanceCard(),
              if (!_isLoading) ...[
                const SizedBox(height: 20),
                if (income != 0 || expense != 0) _buildIncomeExpense(),
                if (income != 0 || expense != 0) const SizedBox(height: 24),
                _buildMyBudgets(),
                const SizedBox(height: 24),
                _buildTracking(),
                const SizedBox(height: 24),
                _buildRecentTransactions(),
                const SizedBox(height: 40),
              ] else ...[
                const SizedBox(height: 40),
                const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFFC107)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return const AnalisisPage();
      case 2:
        return const AIAssistantScreen();
      case 3:
        return const RiwayatPage();
      default:
        return _buildHomeContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: _buildBody(),
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
    String displayTitle = "Total Uang kamu sekarang";

    if (selectedResourceHome != null) {
      displayBalance =
          double.tryParse(selectedResourceHome['balance']?.toString() ?? '0') ??
          0;
      displayTitle = "Uang kamu sekarang";
    }

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<dynamic>(
                    value: selectedResourceHome,
                    icon: const SizedBox.shrink(),
                    hint: const Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet,
                          size: 16,
                          color: Colors.black,
                        ),
                        SizedBox(width: 8),
                        Text(
                          "Pilih sumber uang (dompet)",
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    items: [
                      const DropdownMenuItem<dynamic>(
                        value: null,
                        child: Row(
                          children: [
                            Icon(
                              Icons.account_balance_wallet,
                              size: 16,
                              color: Colors.black,
                            ),
                            SizedBox(width: 8),
                            Text(
                              "Semua Dompet (Total)",
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
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
                                Icons.account_balance_wallet,
                                size: 16,
                                color: Colors.black,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                res['source']?.toString() ?? '-',
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                    onChanged: (val) {
                      setState(() => selectedResourceHome = val);
                    },
                  ),
                ),
              ),
              const Text(
                "finansialin",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            displayTitle,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
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
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      percentageText,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFFFFC107),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Meningkat dalam 15 hari sebelumnya",
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
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
                const Color(0xFF3B82F6),
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
                const Color(0xFFEF4444),
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
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  amount,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyBudgets() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "My Budgets",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AddBudgets()),
                  );
                  if (result == true) _fetchAllData();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC107),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "Add Budget",
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
              "Belum ada budgets.",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ...goals.take(3).map((goal) {
            final double target =
                double.tryParse(goal['amount']?.toString() ?? '0') ?? 0.0;
            final double current =
                double.tryParse(goal['used']?.toString() ?? '0') ?? 0.0;
            final double percent = target > 0 ? (current / target) : 0.0;
            String title = goal['category']?['name'] ?? 'Goal';
            IconData iconToUse = Icons.flight_takeoff;
            if (title.toLowerCase().contains('car') ||
                title.toLowerCase().contains('mobil')) {
              iconToUse = Icons.directions_car;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: _buildGoalItem(
                icon: iconToUse,
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
          children: [
            Icon(icon, size: 30, color: Colors.black),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${formatCurrency(current)} / ${formatCurrency(target)}",
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
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
            margin: const EdgeInsets.symmetric(horizontal: 3),
            height: 8,
            decoration: BoxDecoration(
              color: index < filledBars
                  ? const Color(0xFFE4C640)
                  : Colors.black,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTracking() {
    if (chartData.isEmpty || chartData.every((spot) => spot.y == 0)) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Tracking",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: chartData,
                    isCurved: true,
                    color: Colors.black,
                    barWidth: 3,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFFFFC107).withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions() {
    if (transactions.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Transaksi Terbaru",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...transactions.take(3).map((item) {
            final double amt =
                double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
            final bool isInc = item['type'] == 'income';
            return _buildTransactionItem(
              name: item['description'] ?? '-',
              date: formatDate(item['date']),
              amount: "${isInc ? '+' : '-'}${formatCurrency(amt)}",
              isIncome: isInc,
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTransactionItem({
    required String name,
    required String date,
    required String amount,
    required bool isIncome,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isIncome ? Colors.green : Colors.red).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isIncome ? Icons.arrow_downward : Icons.arrow_upward,
              color: isIncome ? Colors.green : Colors.red,
              size: 20,
            ),
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
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
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
