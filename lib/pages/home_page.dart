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
import 'my_budgets.dart';

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
  int unreadNotifCount = 0;
  List<dynamic> transactions = [];
  List<dynamic> resources = [];
  List<dynamic> goals = [];
  Map<int, String> categoryMap = {};
  int? selectedResourceIndex;

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
    if (goals.isEmpty && transactions.isEmpty) {
      if (mounted) setState(() => _isLoading = true);
    }

    await Future.wait([
      fetchCategories(),
      fetchResourcesHome(),
      fetchTotalBalance(),
      fetchTransactionsMonth(),
      fetchTransactions(),
      fetchGoals(),
      fetchDashboardSummary(),
      _calculateMonthPercentage(),
      fetchUnreadNotifs(),
    ]);

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> fetchUnreadNotifs() async {
    try {
      final res = await dio.get("/notifications/unread/count");
      if (mounted) {
        setState(() {
          unreadNotifCount =
              int.tryParse(res.data['count']?.toString() ?? '0') ?? 0;
        });
      }
    } catch (e) {}
  }

  Future<void> fetchCategories() async {
    try {
      final res = await dio.get("/categories");
      if (res.data != null) {
        List<dynamic> catData = res.data is List
            ? res.data
            : (res.data['data'] ?? []);
        Map<int, String> tempMap = {};
        for (var c in catData) {
          int id = int.tryParse(c['id'].toString()) ?? 0;
          tempMap[id] = c['name']?.toString() ?? 'Lainnya';
        }
        if (mounted) setState(() => categoryMap = tempMap);
      }
    } catch (e) {}
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
      final res = await dio.get("/budgets");
      final List<dynamic> budgetList = res.data is Map
          ? (res.data['data'] ?? [])
          : (res.data ?? []);

      List<dynamic> enrichedGoals = [];
      for (var b in budgetList) {
        int id = int.tryParse(b['id'].toString()) ?? 0;
        try {
          final usageRes = await dio.get("/budgets/$id/usage");
          b['usage'] = usageRes.data is Map
              ? usageRes.data
              : (usageRes.data['data'] ?? {});
        } catch (_) {
          b['usage'] = {'used': 0.0, 'total': b['amount'], 'percent': 0.0};
        }
        enrichedGoals.add(b);
      }

      if (mounted) setState(() => goals = enrichedGoals);
    } catch (e) {}
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
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(value).trim();
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

  IconData _getIconForCategory(String categoryName) {
    String lower = categoryName.toLowerCase();
    if (lower.contains('food') || lower.contains('makan'))
      return Icons.restaurant;
    if (lower.contains('transport') ||
        lower.contains('mobil') ||
        lower.contains('car'))
      return Icons.directions_car;
    if (lower.contains('shop') || lower.contains('belanja'))
      return Icons.shopping_bag;
    if (lower.contains('health') ||
        lower.contains('sehat') ||
        lower.contains('medis'))
      return Icons.medical_services;
    if (lower.contains('edu') ||
        lower.contains('pendidikan') ||
        lower.contains('sekolah'))
      return Icons.school;
    if (lower.contains('ent') ||
        lower.contains('hibur') ||
        lower.contains('main'))
      return Icons.sports_esports;
    if (lower.contains('bill') ||
        lower.contains('tagihan') ||
        lower.contains('listrik'))
      return Icons.receipt_long;
    if (lower.contains('home') || lower.contains('rumah')) return Icons.home;
    return Icons.account_balance_wallet;
  }

  LinearGradient _getCardGradient() {
    Map<String, dynamic>? selectedRes;
    if (selectedResourceIndex != null &&
        selectedResourceIndex! < resources.length) {
      selectedRes = resources[selectedResourceIndex!];
    }

    if (selectedRes == null) {
      return const LinearGradient(
        colors: [Color(0xFFFFE000), Color(0xFFFF8C00)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    String sourceName = selectedRes['source']?.toString().toLowerCase() ?? '';
    if (sourceName.contains('e-wallet') ||
        sourceName.contains('emoney') ||
        sourceName.contains('dana') ||
        sourceName.contains('ovo') ||
        sourceName.contains('gopay')) {
      return const LinearGradient(
        colors: [Color(0xFFB2FF59), Color(0xFF00E676)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    return const LinearGradient(
      colors: [Color(0xFF90CAF9), Color(0xFF1976D2)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  void _showNotificationModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return FractionallySizedBox(
          heightFactor: 0.7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Notifications",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        try {
                          await dio.patch("/notifications/read-all");
                          _fetchAllData();
                          if (mounted) Navigator.pop(context);
                        } catch (e) {}
                      },
                      child: const Text(
                        "Mark all read",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              Expanded(
                child: FutureBuilder(
                  future: dio.get("/notifications"),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFFC107),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(
                        child: Text(
                          "Tidak ada notifikasi",
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    final response = snapshot.data as Response;
                    final List<dynamic> notifs = response.data is Map
                        ? (response.data['data'] ?? [])
                        : (response.data ?? []);

                    if (notifs.isEmpty) {
                      return const Center(
                        child: Text(
                          "Tidak ada notifikasi",
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: notifs.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1, color: Color(0xFFEEEEEE)),
                      itemBuilder: (context, index) {
                        final notif = notifs[index];
                        final isRead =
                            notif['isRead'] == true || notif['read'] == true;

                        final title =
                            notif['title']?.toString() ??
                            notif['message']?.toString() ??
                            'Notifikasi Baru';
                        final message = notif['message']?.toString() ?? '';
                        final dateStr =
                            notif['createdAt']?.toString() ??
                            notif['date']?.toString();

                        String displayDate = '';
                        if (dateStr != null) {
                          try {
                            final dt = DateTime.parse(dateStr).toLocal();
                            displayDate = "${dt.month}/${dt.day}/${dt.year}";
                          } catch (e) {
                            displayDate = dateStr;
                          }
                        }

                        String textToDisplay = title;
                        if (title != message && message.isNotEmpty) {
                          textToDisplay = "$title\n$message";
                        }

                        return Container(
                          color: isRead
                              ? Colors.white
                              : const Color(0xFFFCFAF5),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                textToDisplay,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF555555),
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                displayDate,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Image.asset(
                    'assets/images/logo_finansialin.png',
                    height: 28,
                    errorBuilder: (context, error, stackTrace) {
                      return const Text(
                        "finansialin",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          fontSize: 20,
                        ),
                      );
                    },
                  ),
                  GestureDetector(
                    onTap: _showNotificationModal,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(
                          Icons.notifications_none,
                          size: 28,
                          color: Colors.black87,
                        ),
                        if (unreadNotifCount > 0)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$unreadNotifCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildBalanceCard(),
              if (!_isLoading) ...[
                const SizedBox(height: 20),
                if (income != 0 || expense != 0) _buildIncomeExpense(),
                if (income != 0 || expense != 0) const SizedBox(height: 24),
                _buildMyBudgets(),
                const SizedBox(height: 24),
                if (chartData.isNotEmpty &&
                    !chartData.every((spot) => spot.y == 0))
                  _buildTracking(),
                if (chartData.isNotEmpty &&
                    !chartData.every((spot) => spot.y == 0))
                  const SizedBox(height: 24),
                if (transactions.isNotEmpty) _buildRecentTransactions(),
                if (transactions.isNotEmpty) const SizedBox(height: 40),
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
    String cardKeyStr = selectedResourceIndex?.toString() ?? 'all';

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0.0, 0.05),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: child,
            ),
          ),
        );
      },
      child: _buildBalanceCardContent(key: ValueKey(cardKeyStr)),
    );
  }

  Widget _buildBalanceCardContent({required Key key}) {
    double displayBalance = _totalBalance;
    String displayTitle = "Total Uang kamu sekarang";

    if (selectedResourceIndex != null &&
        selectedResourceIndex! < resources.length) {
      var selectedRes = resources[selectedResourceIndex!];
      displayBalance =
          double.tryParse(selectedRes['balance']?.toString() ?? '0') ?? 0;
      String sourceName = selectedRes['source']?.toString() ?? '';
      displayTitle = "Total Uang $sourceName";
    }

    List<DropdownMenuItem<int?>> dropdownItems = [
      const DropdownMenuItem<int?>(
        value: null,
        child: Text(
          "Semua Dompet (Total)",
          style: TextStyle(
            color: Colors.black87,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ];

    for (int i = 0; i < resources.length; i++) {
      var res = resources[i];
      dropdownItems.add(
        DropdownMenuItem<int?>(
          value: i,
          child: Text(
            res['source']?.toString() ?? '-',
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    if (selectedResourceIndex != null &&
        selectedResourceIndex! >= resources.length) {
      selectedResourceIndex = null;
    }

    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: _getCardGradient(),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Pilih sumber uang (dompet)",
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: selectedResourceIndex,
                  icon: const SizedBox.shrink(),
                  dropdownColor: Colors.white,
                  hint: const Text(
                    "All",
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  items: dropdownItems,
                  onChanged: (val) {
                    setState(() => selectedResourceIndex = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            displayTitle,
            style: const TextStyle(
              color: Colors.black87,
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
                        color: Color(0xFF4CAF50),
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
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC107),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "Add Budget",
                    style: TextStyle(
                      fontSize: 12,
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

            int idCat =
                int.tryParse(goal['idCategory']?.toString() ?? '0') ?? 0;

            double manualUsed = 0.0;
            for (var tx in transactions) {
              if (tx['type'] == 'expense') {
                int txCat =
                    int.tryParse(tx['idCategory']?.toString() ?? '0') ?? 0;
                if (txCat == idCat) {
                  manualUsed +=
                      double.tryParse(tx['amount']?.toString() ?? '0') ?? 0.0;
                }
              }
            }

            final usage = goal['usage'] ?? {};
            double apiUsed =
                double.tryParse(usage['used']?.toString() ?? '0') ?? 0.0;
            final double current = (manualUsed > 0) ? manualUsed : apiUsed;
            final double percent = target > 0 ? (current / target) : 0.0;

            String title =
                goal['categoryName'] ??
                goal['category']?['name'] ??
                categoryMap[idCat] ??
                goal['name'] ??
                'General';

            IconData iconToUse = _getIconForCategory(title);

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MyBudgetsPage(),
                  ),
                ).then((_) => _fetchAllData());
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: _buildGoalItem(
                  icon: iconToUse,
                  title: title,
                  current: current,
                  target: target,
                  percent: percent,
                ),
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
    bool isOverBudget = percent > 1.0;
    double displayPercent = percent.clamp(0.0, 1.0);
    Color progressColor = isOverBudget ? Colors.red : const Color(0xFFFFC107);

    String percentText = isOverBudget
        ? "OVER BUDGET"
        : "${(percent * 100).toInt()}%";

    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 24, color: Colors.black87),
            ),
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
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${formatCurrency(current)} / ${formatCurrency(target)}",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              percentText,
              style: TextStyle(
                fontSize: isOverBudget ? 14 : 16,
                fontWeight: FontWeight.bold,
                color: progressColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 8,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: displayPercent,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              decoration: BoxDecoration(
                color: progressColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTracking() {
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

            int idCat =
                int.tryParse(item['idCategory']?.toString() ?? '0') ?? 0;
            String catName = categoryMap[idCat] ?? 'Lainnya';
            String desc = item['description']?.toString() ?? '';
            String displayTitle = desc.isNotEmpty ? desc : catName;

            return _buildTransactionItem(
              name: displayTitle,
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
