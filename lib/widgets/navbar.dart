import 'package:flutter/material.dart';

class CustomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 12.0,
      color: Colors.white,
      elevation: 8,
      child: Container(
        height: 65,
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          children: <Widget>[
            Expanded(
              child: _buildNavItem(
                icon: Icons.home_filled,
                label: "Beranda",
                index: 0,
              ),
            ),
            Expanded(
              child: _buildNavItem(
                icon: Icons.trending_up,
                label: "Analisis",
                index: 1,
              ),
            ),
            const SizedBox(width: 48),
            Expanded(
              child: _buildNavItem(
                icon: Icons.account_balance_wallet_outlined,
                label: "Riwayat",
                index: 2,
              ),
            ),
            Expanded(
              child: _buildNavItem(
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
    required IconData icon,
    required String label,
    required int index,
  }) {
    bool isSelected = currentIndex == index;

    return MaterialButton(
      padding: EdgeInsets.zero,
      onPressed: () => onTap(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected ? const Color(0xFFFFC107) : Colors.grey,
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFFFFC107) : Colors.grey,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
