import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/auth_service.dart';
import 'add_my_budgets.dart';

class MyBudgetsPage extends StatefulWidget {
  const MyBudgetsPage({Key? key}) : super(key: key);

  @override
  State<MyBudgetsPage> createState() => _MyBudgetsPageState();
}

class _MyBudgetsPageState extends State<MyBudgetsPage> {
  late Dio dio;
  List<dynamic> allBudgets = [];
  List<dynamic> filteredBudgets = [];
  Map<int, String> categoryMap = {};
  List<dynamic> categoryList = [];
  List<dynamic> transactions = [];
  bool isLoading = true;
  String selectedTab = "All";
  String searchQuery = "";
  int? selectedFilterCategoryId;

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
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => isLoading = true);
    try {
      final results = await Future.wait([
        dio.get("/categories"),
        dio.get("/budgets"),
        dio.get("/transactions"),
      ]);

      final catData = results[0].data is List
          ? results[0].data
          : (results[0].data['data'] ?? []);
      Map<int, String> tempMap = {};
      for (var c in catData) {
        int id = int.tryParse(c['id']?.toString() ?? '0') ?? 0;
        int idCategory = int.tryParse(c['idCategory']?.toString() ?? '0') ?? 0;
        String name = c['name']?.toString() ?? 'Lainnya';

        tempMap[id] = name;
        if (idCategory != 0) tempMap[idCategory] = name;
      }

      final budgetList = results[1].data is List
          ? results[1].data
          : (results[1].data['data'] ?? []);
      transactions = results[2].data is List
          ? results[2].data
          : (results[2].data['data'] ?? []);

      List<dynamic> enriched = List.from(budgetList);

      await Future.wait(
        enriched.map((b) async {
          int id = int.tryParse(b['id'].toString()) ?? 0;
          try {
            final usageRes = await dio.get("/budgets/$id/usage");
            b['usage'] = usageRes.data is Map
                ? usageRes.data
                : (usageRes.data['data'] ?? {});
          } catch (_) {
            b['usage'] = {'used': 0.0, 'total': b['amount'], 'percent': 0.0};
          }
        }),
      );

      if (mounted) {
        setState(() {
          categoryMap = tempMap;
          categoryList = catData;
          allBudgets = enriched;
          isLoading = false;
          _applyFilters();
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      filteredBudgets = allBudgets.where((b) {
        int idCat = int.tryParse(b['idCategory']?.toString() ?? '0') ?? 0;
        String title = b['categoryName'] ?? categoryMap[idCat] ?? 'General';

        bool matchesSearch = title.toLowerCase().contains(
          searchQuery.toLowerCase(),
        );

        bool matchesCategory = true;
        if (selectedFilterCategoryId != null) {
          matchesCategory = (idCat == selectedFilterCategoryId);
        }

        double target = double.tryParse(b['amount']?.toString() ?? '0') ?? 0.0;
        double manualUsed = 0.0;
        for (var tx in transactions) {
          if (tx['type'] == 'expense' &&
              (int.tryParse(tx['idCategory']?.toString() ?? '0') == idCat)) {
            manualUsed +=
                double.tryParse(tx['amount']?.toString() ?? '0') ?? 0.0;
          }
        }
        double apiUsed =
            double.tryParse(b['usage']?['used']?.toString() ?? '0') ?? 0.0;
        double current = (manualUsed > 0) ? manualUsed : apiUsed;
        double percent = target > 0 ? (current / target) : 0.0;

        bool matchesTab = true;
        if (selectedTab == "On Track") matchesTab = percent <= 1.0;
        if (selectedTab == "Over Budget") matchesTab = percent > 1.0;

        return matchesSearch && matchesCategory && matchesTab;
      }).toList();
    });
  }

  void _deleteBudget(int budgetId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "Hapus Budget",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "Apakah Anda yakin akan menghapus budget ini? Data tidak dapat dikembalikan.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                setState(() => isLoading = true);
                try {
                  await dio.delete("/budgets/$budgetId");
                  _fetchData();
                } catch (e) {
                  setState(() => isLoading = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Gagal menghapus budget')),
                    );
                  }
                }
              },
              child: const Text(
                "Yakin",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Filter by Category",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedFilterCategoryId = null;
                            _applyFilters();
                          });
                          Navigator.pop(context);
                        },
                        child: Chip(
                          label: const Text("All Categories"),
                          backgroundColor: selectedFilterCategoryId == null
                              ? const Color(0xFFFFC107)
                              : Colors.grey.shade200,
                          labelStyle: TextStyle(
                            color: selectedFilterCategoryId == null
                                ? Colors.black
                                : Colors.black87,
                            fontWeight: selectedFilterCategoryId == null
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      ...categoryList.map((c) {
                        int id = int.tryParse(c['id']?.toString() ?? '0') ?? 0;
                        String name = c['name']?.toString() ?? 'Lainnya';
                        bool isSelected = selectedFilterCategoryId == id;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedFilterCategoryId = id;
                              _applyFilters();
                            });
                            Navigator.pop(context);
                          },
                          child: Chip(
                            label: Text(name),
                            backgroundColor: isSelected
                                ? const Color(0xFFFFC107)
                                : Colors.grey.shade200,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.black : Colors.black87,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String formatCurrency(num value) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(value).trim();
  }

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
          "My Budgets",
          style: TextStyle(
            color: Color(0xFFFFC107),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: TextField(
                          onChanged: (val) {
                            searchQuery = val;
                            _applyFilters();
                          },
                          decoration: const InputDecoration(
                            icon: Icon(Icons.search, color: Colors.grey),
                            hintText: "Search category...",
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _showFilterModal,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: selectedFilterCategoryId != null
                              ? const Color(0xFFFFC107)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Icon(
                          Icons.filter_list,
                          color: selectedFilterCategoryId != null
                              ? Colors.black
                              : Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: ["All", "On Track", "Over Budget"].map((tab) {
                    bool isSelected = selectedTab == tab;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedTab = tab;
                          _applyFilters();
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? Colors.grey.shade300
                                : Colors.transparent,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [],
                        ),
                        child: Text(
                          tab,
                          style: TextStyle(
                            color: isSelected ? Colors.black87 : Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFFC107)),
                  )
                : filteredBudgets.isEmpty
                ? const Center(
                    child: Text(
                      "No budgets found",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: filteredBudgets.length,
                    itemBuilder: (context, index) {
                      final b = filteredBudgets[index];
                      return _buildBudgetCard(b);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetCard(dynamic b) {
    int budgetId = int.tryParse(b['id']?.toString() ?? '0') ?? 0;
    int idCat = int.tryParse(b['idCategory']?.toString() ?? '0') ?? 0;

    String title = b['categoryName'] ?? categoryMap[idCat] ?? 'General';

    double target = double.tryParse(b['amount']?.toString() ?? '0') ?? 0.0;

    double manualUsed = 0.0;
    for (var tx in transactions) {
      if (tx['type'] == 'expense' &&
          (int.tryParse(tx['idCategory']?.toString() ?? '0') == idCat)) {
        manualUsed += double.tryParse(tx['amount']?.toString() ?? '0') ?? 0.0;
      }
    }
    double apiUsed =
        double.tryParse(b['usage']?['used']?.toString() ?? '0') ?? 0.0;
    double current = (manualUsed > 0) ? manualUsed : apiUsed;

    double percent = target > 0 ? (current / target) : 0.0;
    bool isOver = percent > 1.0;

    double remainingPercent = (1.0 - percent) * 100;
    if (remainingPercent < 0) remainingPercent = 0.0;

    String dateRange = "";
    if (b['periodStart'] != null && b['periodEnd'] != null) {
      try {
        DateTime start = DateTime.parse(b['periodStart'].toString());
        DateTime end = DateTime.parse(b['periodEnd'].toString());
        List<String> months = [
          "Jan",
          "Feb",
          "Mar",
          "Apr",
          "Mei",
          "Jun",
          "Jul",
          "Agu",
          "Sep",
          "Okt",
          "Nov",
          "Des",
        ];
        String startStr =
            "${start.day} ${months[start.month - 1]} ${start.year}";
        String endStr = "${end.day} ${months[end.month - 1]} ${end.year}";
        dateRange = "$startStr - $endStr";
      } catch (e) {
        dateRange = "-";
      }
    }

    String periodText = b['period']?.toString() ?? 'monthly';
    periodText = periodText.isNotEmpty
        ? '${periodText[0].toUpperCase()}${periodText.substring(1).toLowerCase()}'
        : 'Monthly';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
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
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Row(
                children: [
                  Text(
                    periodText,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddBudgets(),
                        ),
                      ).then((_) => _fetchData());
                    },
                    child: const Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _deleteBudget(budgetId),
                    child: const Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatCurrency(current),
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
              Text(
                formatCurrency(target),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 6,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percent.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: isOver
                      ? const Color(0xFFEF4444)
                      : const Color(0xFFFFC107),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isOver
                    ? "Over budget!"
                    : "${remainingPercent.toStringAsFixed(0)}% remaining",
                style: TextStyle(
                  fontSize: 12,
                  color: isOver ? const Color(0xFFEF4444) : Colors.grey,
                ),
              ),
              Text(
                dateRange,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
