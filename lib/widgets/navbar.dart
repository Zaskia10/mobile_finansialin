import 'package:flutter/material.dart';
import '../pages/home_page.dart';
// import '../pages/analysis_page.dart';
// import '../pages/history_page.dart';
// import '../pages/profile_page.dart';
import '../pages/chatbot_page.dart';

class CustomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  void _navigate(BuildContext context, int index) {
    Widget page;

    switch (index) {
      case 0:
        page = const HomePage();
        break;
      // case 1:
      //   page = const AnalysisPage();
      //   break;
      // case 2:
      //   page = const HistoryPage();
      //   break;
      // case 3:
      //   page = const ProfilePage();
      //   break;
      case 4:
        page = const AIAssistantScreen();
        break;
      default:
        page = const HomePage();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 10,
      color: Colors.white,
      elevation: 8,
      child: SizedBox(
        height: 70,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            Expanded(
              child: _buildNavItem(
                context: context,
                icon: Icons.home_filled,
                label: "Beranda",
                index: 0,
              ),
            ),
            Expanded(
              child: _buildNavItem(
                context: context,
                icon: Icons.trending_up,
                label: "Analisis",
                index: 1,
              ),
            ),
            const SizedBox(width: 48),
            Expanded(
              child: _buildNavItem(
                context: context,
                icon: Icons.account_balance_wallet_outlined,
                label: "Riwayat",
                index: 2,
              ),
            ),
            Expanded(
              child: _buildNavItem(
                context: context,
                icon: Icons.person_outline,
                label: "Profile",
                index: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required int index,
  }) {
    bool isSelected = currentIndex == index;

    return MaterialButton(
      minWidth: 40,
      padding: EdgeInsets.zero,
      onPressed: () {
        onTap(index);
        _navigate(context, index);
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected ? const Color(0xFFFFC107) : Colors.grey,
            size: 24,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFFFFC107) : Colors.grey,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
