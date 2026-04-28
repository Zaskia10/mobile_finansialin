import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiService {
  static const String baseUrl = AuthService.baseUrl;

  static Future<Map<String, String>> _authHeaders() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Ambil summary saldo dari semua resource (dompet) user
  /// GET /api/resources/summary
  /// Return: totalBalance (double) dan list resources
  static Future<Map<String, dynamic>> getResourceSummary() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/resources/summary'),
      headers: headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {
        'success': true,
        'totalBalance': (data['data']?['totalBalance'] ?? 0).toDouble(),
        'resources': data['data']?['resources'] ?? [],
      };
    } else {
      return {
        'success': false,
        'message': data['message'] ?? 'Gagal mengambil data saldo',
        'totalBalance': 0.0,
      };
    }
  }

  /// Ambil daftar resource (dompet) milik user
  /// GET /api/resources
  static Future<Map<String, dynamic>> getResources() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/resources'),
      headers: headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {'success': true, 'resources': data['data'] ?? []};
    } else {
      return {
        'success': false,
        'message': data['message'] ?? 'Gagal mengambil daftar dompet',
      };
    }
  }

  /// Set saldo awal dengan membuat transaksi income "Saldo Awal"
  /// Transaksi dikirim ke resource pertama (default: index 0)
  /// POST /api/transactions
  static Future<Map<String, dynamic>> setInitialBalance(double amount) async {
    // Ambil resource pertama milik user
    final resourceResult = await getResources();
    if (!resourceResult['success']) {
      return {'success': false, 'message': resourceResult['message']};
    }

    final resources = resourceResult['resources'] as List;
    if (resources.isEmpty) {
      return {'success': false, 'message': 'Tidak ada dompet yang tersedia'};
    }

    // Gunakan resource pertama (mbanking / cash / default)
    final firstResource = resources[0];
    final idResource = firstResource['idResource'];

    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/transactions'),
      headers: headers,
      body: jsonEncode({
        'idResource': idResource,
        'type': 'income',
        'amount': amount,
        'description': 'Saldo Awal',
        'date': DateTime.now().toIso8601String(),
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 201) {
      return {'success': true, 'data': data};
    } else {
      return {
        'success': false,
        'message': data['message'] ?? 'Gagal menyimpan saldo awal',
      };
    }
  }
}
