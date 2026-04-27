import 'package:flutter/material.dart';

const Color _carmaBlue = Color(0xFF139CFF);
const Color _carmaBlueLight = Color(0xFF63D5FF);
const Color _carmaBlueDark = Color(0xFF0A76FF);

class CarmaBlueIconBox extends StatelessWidget {
  const CarmaBlueIconBox({
    super.key,
    required this.icon,
    this.size = 46,
    this.iconSize = 23,
  });

  final IconData icon;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _carmaBlueDark,
            _carmaBlue,
            _carmaBlueLight,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _carmaBlue.withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: iconSize,
      ),
    );
  }
}