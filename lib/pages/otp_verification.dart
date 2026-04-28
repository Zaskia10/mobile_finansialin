import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_page.dart';
import 'setup_saldo_awal.dart';

class OtpVerificationPage extends StatefulWidget {
  final String email;
  final String? twoFactorToken;
  final bool isLoginVerification;

  const OtpVerificationPage({
    super.key,
    required this.email,
    this.twoFactorToken,
    this.isLoginVerification = false,
  });

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  bool _isSubmitting = false;
  bool _isResending = false;
  Timer? _timer;
  int _secondsRemaining = 600;

  void _startTimer() {
    _secondsRemaining = 600;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  String get _formattedTime {
    int minutes = _secondsRemaining ~/ 60;
    int seconds = _secondsRemaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(6, (_) => TextEditingController());
    _focusNodes = List.generate(6, (_) => FocusNode());
    Future.microtask(() => _focusNodes[0].requestFocus());
    _startTimer();
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _submitCode() async {
    final code = _controllers
        .map((controller) => controller.text.trim())
        .join();
    if (code.length != 6 || !RegExp(r'^\d{6}$').hasMatch(code)) {
      _showMessage('Masukkan kode OTP 6 digit');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      Map<String, dynamic> result;

      if (widget.isLoginVerification && widget.twoFactorToken != null) {
        // Verify login OTP
        result = await AuthService.verifyLoginOtp(
          twoFactorToken: widget.twoFactorToken!,
          code: code,
        );
      } else {
        // Verify registration OTP
        result = await AuthService.verifyRegistrationOtp(
          email: widget.email,
          code: code,
        );
      }

      if (result['success']) {
        _showMessage('Kode OTP berhasil diverifikasi');
        // Login → HomePage, Registrasi baru → SetupSaldoAwalPage
        if (widget.isLoginVerification) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomePage()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const SetupSaldoAwalPage()),
          );
        }
      } else {
        _showMessage(result['message']);
      }
    } catch (e) {
      _showMessage('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _resendCode() {
    setState(() {
      _isResending = true;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _isResending = false;
      });
      _showMessage('Kode OTP telah dikirim ulang');
      for (final controller in _controllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();
      _startTimer();
    });
  }

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 50,
      height: 58,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFFFC107), width: 2),
          ),
        ),
        onChanged: (value) {
          if (value.isNotEmpty) {
            if (index < _focusNodes.length - 1) {
              _focusNodes[index + 1].requestFocus();
            }
          } else {
            if (index > 0) {
              _focusNodes[index - 1].requestFocus();
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFFEFDFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        title: const Text('Register'),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: size.height * 0.04),
              const Text(
                'Verifikasi akun anda',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Kode verifikasi telah dikirimkan ke alamat email anda',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 28),
              Center(
                child: Text(
                  _formattedTime,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              SizedBox(height: size.height * 0.04),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, _buildOtpBox),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Belum mendapat kode OTP? ',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                  TextButton(
                    onPressed: _isResending ? null : _resendCode,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      _isResending ? 'Mengirim...' : 'Kirim ulang OTP',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A7CFF),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: size.height * 0.04),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    disabledBackgroundColor: const Color(0xFFCCCCCC),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Submit',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                ),
              ),
              SizedBox(height: size.height * 0.04),
            ],
          ),
        ),
      ),
    );
  }
}
