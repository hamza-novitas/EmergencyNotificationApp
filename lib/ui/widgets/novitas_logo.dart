import 'package:flutter/material.dart';

class NovitasLogo extends StatelessWidget {
  const NovitasLogo({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/images/novitas_logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}