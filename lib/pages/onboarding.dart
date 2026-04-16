import 'package:flutter/material.dart';
import 'login.dart';

class LogoSplashScreen extends StatefulWidget {
  const LogoSplashScreen({super.key});

  @override
  State<LogoSplashScreen> createState() => _LogoSplashScreenState();
}

class _LogoSplashScreenState extends State<LogoSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -1),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    Future.delayed(const Duration(milliseconds: 1200), () async {
      if (!mounted) return;
      await _controller.forward();
      if (!mounted) return;
      setState(() {
        _showSplash = false;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_showSplash) {
      return const OnboardingScreen();
    }

    return Stack(
      children: [
        const OnboardingScreen(), // Onboarding di belakang
        SlideTransition(
          position: _slideAnimation,
          child: Scaffold(
            backgroundColor: theme
                .colorScheme
                .surface, // Background solid agar tidak transparan
            body: SafeArea(
              child: Center(
                child: Image.asset(
                  'assets/images/logo_finansialin.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingPageData> _pages = const [
    _OnboardingPageData(
      title: 'Yuk, Atur Keuanganmu!',
      subtitle:
          'Mulai kelola pengeluaran dan investasi dengan lebih baik. Capai tujuan finansialmu bersama Finansialin!',
      imagePath: 'assets/images/onboard1.png',
      imageWidth: 355,
      imageHeight: 230,
      buttonLabel: 'NEXT',
    ),
    _OnboardingPageData(
      title: 'Catat Setiap Transaksi',
      subtitle:
          'Masukkan pemasukan dan pengeluaran dengan mudah agar keuanganmu selalu tercatat dengan rapi.',
      imagePath: 'assets/images/onboard2.png',
      imageWidth: 266,
      imageHeight: 239,
      buttonLabel: 'NEXT',
    ),
    _OnboardingPageData(
      title: 'Atur Budget & Pantau Laporan',
      subtitle:
          'Buat budget untuk setiap kategori pengeluaran dan monitor laporan keuangan bulanamu secara praktis.',
      imagePath: 'assets/images/onboard3.png',
      imageWidth: 288,
      imageHeight: 257,
      buttonLabel: 'START',
    ),
  ];

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _onNextPressed() {
    if (_currentPage < _pages.length - 1) {
      _goToPage(_currentPage + 1);
    } else {
      _finishOnboarding();
    }
  }

  void _finishOnboarding() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const OnboardingFinishedScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() {
                  _currentPage = index;
                }),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 32,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 28),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: Center(
                              child: Image.asset(
                                page.imagePath,
                                width: page.imageWidth,
                                height: page.imageHeight,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              page.title,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                                fontSize: 24, // Ubah ukuran font title
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              page.subtitle,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.5,
                                fontSize: 12, // Ubah ukuran font subtitle
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage < _pages.length - 1)
                    TextButton(
                      onPressed: _finishOnboarding,
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurface,
                      ),
                      child: const Text('SKIP'),
                    )
                  else
                    const SizedBox(
                      width: 60,
                    ), // Placeholder untuk menjaga layout
                  Row(
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 20 : 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? const Color(
                                  0xFFFFC107,
                                ) // Warna kuning untuk dot aktif
                              : const Color(0xFFFFC107).withOpacity(
                                  0.35,
                                ), // Warna kuning transparan untuk dot tidak aktif
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _onNextPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFC107),
                      foregroundColor: theme.colorScheme.onSurface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                    child: Text(_pages[_currentPage].buttonLabel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  final String title;
  final String subtitle;
  final String imagePath;
  final double imageWidth;
  final double imageHeight;
  final String buttonLabel;

  const _OnboardingPageData({
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.imageWidth,
    required this.imageHeight,
    required this.buttonLabel,
  });
}

class OnboardingFinishedScreen extends StatelessWidget {
  const OnboardingFinishedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Navigate to LoginPage after a short delay
    Future.microtask(() {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
