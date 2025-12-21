import 'package:flutter/material.dart';

class GradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final List<Color> colors;

  const GradientText(
    this.text, {
    super.key,
    this.style,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        colors: colors,
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(
        text,
        style: style,
      ),
    );
  }
}