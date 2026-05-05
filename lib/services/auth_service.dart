import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AuthService {
  // Ganti dengan IP address komputer kamu yang sebenarnya
  static String baseUrl = dotenv.env['BASE_URL']!;

  static Future<void> saveToken(
    String accessToken, {
    String? refreshToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    if (refreshToken != null) {
      await prefs.setString('refresh_token', refreshToken);
    }
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }

  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? name,
    String? phone,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 201 || response.statusCode == 202) {
      return {'success': true, 'data': data};
    } else {
      return {
        'success': false,
        'message': data['message'] ?? 'Registration failed',
      };
    }
  }

  // Login user
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      // Login tanpa 2FA
      if (data['accessToken'] != null) {
        await saveToken(
          data['accessToken'],
          refreshToken: data['refreshToken'],
        );
      }
      return {'success': true, 'data': data, 'requiresTwoFactor': false};
    } else if (response.statusCode == 202 &&
        data['requiresTwoFactor'] == true) {
      return {'success': true, 'data': data, 'requiresTwoFactor': true};
    } else {
      return {'success': false, 'message': data['message'] ?? 'Login failed'};
    }
  }

  // Verify 2FA login
  static Future<Map<String, dynamic>> verifyLoginOtp({
    required String twoFactorToken,
    required String code,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/2fa/verify-login'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $twoFactorToken',
      },
      body: jsonEncode({'code': code}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      // Simpan token login
      if (data['accessToken'] != null) {
        await saveToken(
          data['accessToken'],
          refreshToken: data['refreshToken'],
        );
      }
      return {'success': true, 'data': data};
    } else {
      return {
        'success': false,
        'message': data['message'] ?? 'OTP verification failed',
      };
    }
  }

  // Forgot password
  static Future<Map<String, dynamic>> forgotPassword({
    required String email,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 202) {
      return {
        'success': true,
        'message': data['message'] ?? 'Email reset password dikirim',
      };
    } else {
      return {
        'success': false,
        'message': data['message'] ?? 'Gagal mengirim email reset password',
      };
    }
  }

  // Verify forgot password OTP
  static Future<Map<String, dynamic>> verifyForgotPasswordOtp({
    required String email,
    required String code,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/forgot-password/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {'success': true, 'message': data['message'] ?? 'OTP verified'};
    } else {
      return {
        'success': false,
        'message': data['message'] ?? 'OTP verification failed',
      };
    }
  }

  // Reset password
  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code, 'password': password}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {
        'success': true,
        'message': data['message'] ?? 'Password berhasil direset',
      };
    } else {
      return {
        'success': false,
        'message': data['message'] ?? 'Gagal mereset password',
      };
    }
  }

  // Logout user - revoke token on server
  static Future<Map<String, dynamic>> logout() async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/auth/logout'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      await clearToken();
      return {
        'success': true,
        'message': data['message'] ?? 'Logout successful',
      };
    } else {
      return {'success': false, 'message': data['message'] ?? 'Logout failed'};
    }
  }

  // Get user profile
  static Future<Map<String, dynamic>> getProfile() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/auth/profile'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      final userMap = data['data'] ?? data;
      return {
        'success': true,
        'name': userMap['name'] ?? userMap['user']?['name'] ?? 'User',
        'email': userMap['email'] ?? userMap['user']?['email'] ?? '',
        'phone': userMap['phone'] ?? userMap['user']?['phone'] ?? '',
      };
    } else {

      return {
        'success': false,
        'message': data['message'] ?? 'Failed to get profile',
      };
    }
  }

  // Update user profile
  static Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? email,
  }) async {
    final token = await getToken();
    
    final Map<String, dynamic> body = {};
    if (name != null && name.isNotEmpty) body['name'] = name;
    if (email != null && email.isNotEmpty) body['email'] = email;

    final response = await http.put(
      Uri.parse('$baseUrl/users/profile'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {
        'success': true,
        'data': data,
        'message': 'Profile updated successfully',
      };
    } else {
      return {
        'success': false,
        'message': data['message'] ?? 'Failed to update profile',
      };
    }
  }

  // Delete user account
  static Future<Map<String, dynamic>> deleteAccount({
    required String password,
  }) async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/users/account'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'password': password}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      await clearToken();
      return {
        'success': true,
        'message': data['message'] ?? 'Akun berhasil dihapus',
      };
    } else {
      return {
        'success': false,
        'message': data['message'] ?? 'Gagal menghapus akun',
      };
    }
  }

  // Verify registration OTP
  static Future<Map<String, dynamic>> verifyRegistrationOtp({
    required String email,
    required String code,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      if (data['accessToken'] != null) {
        await saveToken(
          data['accessToken'],
          refreshToken: data['refreshToken'],
        );
      }
      return {'success': true, 'data': data};
    } else {
      return {
        'success': false,
        'message': data['message'] ?? 'OTP verification failed',
      };
    }
  }
}
