import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import '../services/auth_service.dart';

class AnalisisPage extends StatefulWidget {
  const AnalisisPage({Key? key}) : super(key: key);

  @override
  State<AnalisisPage> createState() => _AnalisisPageState();
}

class _AnalisisPageState extends State<AnalisisPage> {
  int _currentTab = 0;
  int _reportMonth = DateTime.now().month;
  int _reportYear = DateTime.now().year;

  List<dynamic> _transactions = [];
  List<dynamic> _budgets = [];
  Map<int, Map<String, dynamic>> _budgetUsageMap = {};
  Map<int, String> _categoryMap = {};

  bool _isLoading = true;

  double _totalIncome = 0;
  double _totalExpense = 0;
  double _totalSavings = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Future<void> _fetchData() async {
    try {
      final String baseUrl = AuthService.baseUrl;
      final String? token = await AuthService.getToken();

      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final results = await Future.wait([
        http.get(Uri.parse('$baseUrl/transactions'), headers: headers),
        http.get(Uri.parse('$baseUrl/categories'), headers: headers),
        http.get(Uri.parse('$baseUrl/budgets'), headers: headers),
      ]);

      final txResponse = results[0];
      final catResponse = results[1];
      final budgetResponse = results[2];

      if (catResponse.statusCode == 200) {
        final decoded = json.decode(catResponse.body);
        List<dynamic> catData = decoded is List
            ? decoded
            : (decoded is Map && decoded.containsKey('data')
                  ? decoded['data']
                  : []);
        for (var c in catData) {
          _categoryMap[_parseInt(c['id'])] = c['name']?.toString() ?? 'Lainnya';
        }
      }

      if (txResponse.statusCode == 200) {
        final decodedTx = json.decode(txResponse.body);
        List<dynamic> txData = decodedTx is List
            ? decodedTx
            : (decodedTx is Map && decodedTx.containsKey('data')
                  ? decodedTx['data']
                  : []);
        _transactions = txData;

        double tempInc = 0, tempExp = 0;
        for (var t in txData) {
          final amt = _parseDouble(t['amount']);
          if (t['type'] == 'income')
            tempInc += amt;
          else if (t['type'] == 'expense')
            tempExp += amt;
        }
        _totalIncome = tempInc;
        _totalExpense = tempExp;
        _totalSavings = tempInc - tempExp;
      }

      if (budgetResponse.statusCode == 200) {
        final decodedBudget = json.decode(budgetResponse.body);
        List<dynamic> budgetData = decodedBudget is List
            ? decodedBudget
            : (decodedBudget is Map && decodedBudget.containsKey('data')
                  ? decodedBudget['data']
                  : []);
        _budgets = budgetData;

        await Future.wait(
          budgetData.map((b) async {
            final id = _parseInt(b['id']);
            try {
              final usageRes = await http.get(
                Uri.parse('$baseUrl/budgets/$id/usage'),
                headers: headers,
              );
              if (usageRes.statusCode == 200) {
                final u = json.decode(usageRes.body);
                _budgetUsageMap[id] = {
                  'used': _parseDouble(u['used']),
                  'total': _parseDouble(u['total']),
                  'percent': _parseDouble(u['percent']),
                };
              }
            } catch (_) {}
          }),
        );
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error fetching data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatCurrency(num? value) {
    if (value == null) return 'Rp 0';
    String str = value.round().toString();
    String result = '';
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      result = str[i] + result;
      count++;
      if (count % 3 == 0 && i != 0 && str[i - 1] != '-') result = '.$result';
    }
    return 'Rp $result';
  }

  String _formatShortCurrency(num? value) {
    if (value == null || value == 0) return 'Rp 0';
    if (value >= 1000000) return 'Rp ${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return 'Rp ${(value / 1000).toStringAsFixed(0)}k';
    return _formatCurrency(value);
  }

  List<Map<String, dynamic>> _getChartMonths() {
    final now = DateTime.now();
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Ags',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return List.generate(6, (i) {
      int m = now.month - (5 - i);
      int y = now.year;
      if (m <= 0) {
        m += 12;
        y -= 1;
      }
      return {'name': monthNames[m - 1], 'month': m, 'year': y};
    });
  }

  List<FlSpot> _getMonthlyExpenseSpots() {
    final months = _getChartMonths();
    return List.generate(months.length, (i) {
      double total = 0;
      for (var t in _transactions) {
        if (t['type'] != 'expense' || t['date'] == null) continue;
        final d = DateTime.parse(t['date']);
        if (d.month == months[i]['month'] && d.year == months[i]['year']) {
          total += _parseDouble(t['amount']);
        }
      }
      return FlSpot(i.toDouble(), total);
    });
  }

  List<Map<String, dynamic>> _getCategoryStats() {
    final Map<String, double> stats = {};
    for (var t in _transactions) {
      if (t['type'] == 'expense') {
        final name = _categoryMap[_parseInt(t['idCategory'])] ?? 'Lainnya';
        stats[name] = (stats[name] ?? 0) + _parseDouble(t['amount']);
      }
    }
    final list = stats.entries
        .map((e) => {'name': e.key, 'amount': e.value})
        .toList();
    list.sort(
      (a, b) => (b['amount'] as double).compareTo(a['amount'] as double),
    );
    return list;
  }

  Map<String, dynamic> _getReportData() {
    final filtered = _transactions.where((t) {
      if (t['date'] == null) return false;
      final d = DateTime.parse(t['date']);
      return d.month == _reportMonth && d.year == _reportYear;
    }).toList();

    double inc = 0, exp = 0;
    for (var t in filtered) {
      final amt = _parseDouble(t['amount']);
      if (t['type'] == 'income')
        inc += amt;
      else if (t['type'] == 'expense')
        exp += amt;
    }

    final filteredBdg = _budgets.where((b) {
      if (b['periodStart'] == null) return false;
      final d = DateTime.parse(b['periodStart']);
      return d.month == _reportMonth && d.year == _reportYear;
    }).toList();

    return {'income': inc, 'expense': exp, 'budgets': filteredBdg};
  }

  String _budgetCategoryName(dynamic b) =>
      _categoryMap[_parseInt(b['idCategory'])] ?? 'General';

  Map<String, dynamic> _getBudgetUsage(dynamic b) =>
      _budgetUsageMap[_parseInt(b['id'])] ??
      {'used': 0.0, 'total': 0.0, 'percent': 0.0};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Analisis & Laporan',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFC107)),
            )
          : Column(
              children: [
                _buildTabBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _currentTab == 0
                        ? _buildAnalyticsTab()
                        : _buildLaporanTab(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [_buildTab('Analisis', 0), _buildTab('Laporan', 1)],
        ),
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final active = _currentTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentTab = index),
        child: Container(
          decoration: BoxDecoration(
            color: active ? const Color(0xFFFFC107) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: active ? FontWeight.bold : FontWeight.w500,
              color: active ? Colors.white : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    final incCount = _transactions.where((t) => t['type'] == 'income').length;
    final expCount = _transactions.where((t) => t['type'] == 'expense').length;
    double maxInc = 0, maxExp = 0;
    for (var t in _transactions) {
      final amt = _parseDouble(t['amount']);
      if (t['type'] == 'income' && amt > maxInc) maxInc = amt;
      if (t['type'] == 'expense' && amt > maxExp) maxExp = amt;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.3,
          children: [
            _buildStatCard(
              title: 'Total Transaksi',
              value: _transactions.length.toString(),
              iconColor: const Color(0xFF5A67D8),
              iconBgColor: const Color(0xFFEBEFFF),
            ),
            _buildStatCard(
              title: 'Tingkat Tabungan',
              value:
                  '${_totalIncome > 0 ? ((_totalSavings / _totalIncome) * 100).toStringAsFixed(0) : 0}%',
              iconColor: const Color(0xFFE53E3E),
              iconBgColor: const Color(0xFFFDE8E8),
            ),
            _buildStatCard(
              title: 'Rata-rata Pemasukan',
              value: _formatShortCurrency(
                incCount > 0 ? _totalIncome / incCount : 0,
              ),
              iconColor: const Color(0xFF5A67D8),
              iconBgColor: const Color(0xFFEBEFFF),
            ),
            _buildStatCard(
              title: 'Rata-rata Pengeluaran',
              value: _formatShortCurrency(
                expCount > 0 ? _totalExpense / expCount : 0,
              ),
              iconColor: const Color(0xFFE53E3E),
              iconBgColor: const Color(0xFFFDE8E8),
            ),
            _buildStatCard(
              title: 'Pemasukan Tertinggi',
              value: _formatShortCurrency(maxInc),
              iconColor: const Color(0xFF5A67D8),
              iconBgColor: const Color(0xFFEBEFFF),
            ),
            _buildStatCard(
              title: 'Pengeluaran Tertinggi',
              value: _formatShortCurrency(maxExp),
              iconColor: const Color(0xFFE53E3E),
              iconBgColor: const Color(0xFFFDE8E8),
            ),
          ],
        ),
        const SizedBox(height: 24),

        _buildPanel(
          title: 'Income vs Expense',
          child: Column(
            children: [
              SizedBox(
                height: 140,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildComparisonBar(
                      'Income',
                      _totalIncome,
                      max(_totalIncome, _totalExpense),
                      const Color(0xFFFFC107),
                    ),
                    const SizedBox(width: 32),
                    _buildComparisonBar(
                      'Expense',
                      _totalExpense,
                      max(_totalIncome, _totalExpense),
                      const Color(0xFF333333),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Net Savings This Month',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatCurrency(_totalSavings)} (${_totalIncome > 0 ? ((_totalSavings / _totalIncome) * 100).toStringAsFixed(0) : 0}%)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _totalSavings >= 0
                            ? const Color(0xFF4AB2A6)
                            : const Color(0xFFE53E3E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        _buildPanel(
          title: 'Budget vs Actual',
          child: _budgets.isEmpty
              ? const Center(
                  child: Text(
                    'Belum ada data budget',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                )
              : SizedBox(
                  height: 160,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final items = _budgets.take(5).toList();
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: items.map((b) {
                          final amount = _parseDouble(b['amount']);
                          final usage = _getBudgetUsage(b);
                          final spent = usage['used'] as double;
                          final maxVal = max(amount, max(spent, 1.0));
                          return Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Stack(
                                    alignment: Alignment.bottomCenter,
                                    children: [
                                      Container(
                                        width: 18,
                                        height: max((amount / maxVal) * 120, 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFE082),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: 18,
                                        height: max((spent / maxVal) * 120, 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFC107),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _budgetCategoryName(b),
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Colors.grey,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
        ),
        const SizedBox(height: 24),

        _buildPanel(
          title: 'Pengeluaran Bulanan',
          child: SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.shade200,
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        return Text(
                          '${(value / 1000).toInt()}k',
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final months = _getChartMonths();
                        final idx = value.toInt();
                        if (idx >= 0 && idx < months.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              months[idx]['name'],
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.grey,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _getMonthlyExpenseSpots(),
                    isCurved: true,
                    color: const Color(0xFFFFC107),
                    barWidth: 2,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                            radius: 3,
                            color: Colors.white,
                            strokeWidth: 2,
                            strokeColor: const Color(0xFFFFC107),
                          ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFFC107).withOpacity(0.5),
                          const Color(0xFFFFC107).withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        _buildPanel(
          title: 'Kategori Spending Terbesar',
          child: () {
            final stats = _getCategoryStats();
            if (stats.isEmpty) {
              return const Text(
                'Belum ada data pengeluaran',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              );
            }
            final maxVal = stats.first['amount'] as double;
            return Column(
              children: stats.take(5).map((stat) {
                final percent = maxVal > 0
                    ? (stat['amount'] as double) / maxVal
                    : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: percent.clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFC107),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 72,
                        child: Text(
                          stat['name'],
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          }(),
        ),
      ],
    );
  }

  Widget _buildLaporanTab() {
    final rData = _getReportData();
    final List<dynamic> bdgs = rData['budgets'];
    final double inc = rData['income'];
    final double exp = rData['expense'];
    final double net = inc - exp;

    const monthNames = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildDropdown<int>(
                value: _reportMonth,
                items: List.generate(
                  12,
                  (i) => DropdownMenuItem(
                    value: i + 1,
                    child: Text(monthNames[i]),
                  ),
                ),
                onChanged: (v) {
                  if (v != null) setState(() => _reportMonth = v);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDropdown<int>(
                value: _reportYear,
                items: [2024, 2025, 2026]
                    .map(
                      (y) =>
                          DropdownMenuItem(value: y, child: Text(y.toString())),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _reportYear = v);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        _buildPanel(
          title: 'Ringkasan Laporan',
          child: Column(
            children: [
              _buildReportRow(
                'Total Pemasukan',
                _formatCurrency(inc),
                const Color(0xFF4AB2A6),
              ),
              const Divider(height: 24),
              _buildReportRow(
                'Total Pengeluaran',
                _formatCurrency(exp),
                const Color(0xFFE53E3E),
              ),
              const Divider(height: 24),
              _buildReportRow(
                'Net Savings',
                _formatCurrency(net),
                Colors.black,
                isBold: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        _buildPanel(
          title: 'Status Keuangan',
          child: Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              inc == 0 && exp == 0
                  ? 'Belum ada transaksi untuk bulan ini.'
                  : inc > exp
                  ? 'Anda berhasil menabung bulan ini! Pertahankan performa ini.'
                  : 'Pengeluaran Anda lebih besar dari pemasukan. Coba cek kembali daftar belanja Anda.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        _buildPanel(
          title: 'Penggunaan Budget',
          child: bdgs.isEmpty
              ? const Text(
                  'Tidak ada data budget untuk bulan ini.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                )
              : Column(
                  children: bdgs.map((b) {
                    final usage = _getBudgetUsage(b);
                    final pct = usage['percent'] as double;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  _budgetCategoryName(b),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${pct.toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 8,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: (pct / 100).clamp(0.0, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: pct > 100
                                      ? const Color(0xFFE53E3E)
                                      : const Color(0xFFFFC107),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_formatShortCurrency(usage['used'])} / ${_formatShortCurrency(usage['total'])}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          style: const TextStyle(
            color: Colors.black,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildReportRow(
    String label,
    String value,
    Color valueColor, {
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required Color iconColor,
    required Color iconBgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.account_balance_wallet,
              color: iconColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
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

  Widget _buildPanel({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
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
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 20),
            child: Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonBar(
    String label,
    double value,
    double maxVal,
    Color color,
  ) {
    if (maxVal == 0) maxVal = 1;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 36,
          height: max((value / maxVal) * 100, 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}
