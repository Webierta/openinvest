import 'package:flutter/material.dart';

import '../models/fund_data.dart';

class CircleAvatarFund extends StatelessWidget {
  final FundData fund;
  final double? radius;
  final double? fontSize;
  const new({
    super.key,
    required this.fund,
    this.radius = 20,
    this.fontSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: getFundColor.withValues(alpha: 0.2),
      child: Text(
        fund.name.isNotEmpty ? fund.name[0].toUpperCase() : 'F',
        style: TextStyle(
          color: getFundColor,
          fontWeight: FontWeight.bold,
          fontSize: fontSize,
        ),
      ),
    );
  }

  Color get getFundColor {
    final isin = fund.isin;
    final int hash = isin.hashCode;
    final List<Color> colors = [
      Colors.blueAccent,
      Colors.purpleAccent,
      Colors.orangeAccent,
      Colors.tealAccent,
      Colors.pinkAccent,
      Colors.indigoAccent,
      Colors.amberAccent,
      Colors.cyanAccent,
      Colors.lightGreenAccent,
    ];
    return colors[hash.abs() % colors.length];
  }
}
