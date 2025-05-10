//https://raw.githubusercontent.com/samarthagarwal/FlutterScreens/master/lib/loaders/color_loader_3.dart
import 'dart:math';
import 'package:flutter/material.dart';

class ColorLoader3 extends StatefulWidget {
  const ColorLoader3({super.key, this.radius = 30.0, this.dotRadius = 3.0});
  final double radius;
  final double dotRadius;
  @override
  ColorLoader3State createState() => ColorLoader3State();
}

class ColorLoader3State extends State<ColorLoader3>
    with SingleTickerProviderStateMixin {
  late Animation<double> animationRotation;
  late Animation<double> animationRadiusIn;
  late Animation<double> animationRadiusOut;
  late AnimationController controller;

  double radius = 30;
  double dotRadius = 3;

  @override
  void initState() {
    super.initState();

    radius = widget.radius;
    dotRadius = widget.dotRadius;

    controller = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    animationRotation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0, 1),
      ),
    );

    animationRadiusIn = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.75, 1, curve: Curves.elasticIn),
      ),
    );

    animationRadiusOut = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0, 0.25, curve: Curves.elasticOut),
      ),
    );

    controller
      ..addListener(() {
        setState(() {
          if (controller.value >= 0.75 && controller.value <= 1.0) {
            radius = widget.radius * animationRadiusIn.value;
          } else if (controller.value >= 0.0 && controller.value <= 0.25) {
            radius = widget.radius * animationRadiusOut.value;
          }
        });
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {}
      })
      ..repeat();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      //color: Colors.black12,
      child: Center(
        child: RotationTransition(
          turns: animationRotation,
          child: Center(
            child: Stack(
              children: <Widget>[
                Transform.translate(
                  offset: Offset.zero,
                  child: Dot(
                    radius: radius,
                    color: Colors.black12,
                  ),
                ),
                Transform.translate(
                  offset: Offset(
                    radius * cos(0.0),
                    radius * sin(0.0),
                  ),
                  child: Dot(
                    radius: dotRadius,
                    color: Colors.amber,
                  ),
                ),
                Transform.translate(
                  offset: Offset(
                    radius * cos(0.0 + 1 * pi / 4),
                    radius * sin(0.0 + 1 * pi / 4),
                  ),
                  child: Dot(
                    radius: dotRadius,
                    color: Colors.deepOrangeAccent,
                  ),
                ),
                Transform.translate(
                  offset: Offset(
                    radius * cos(0.0 + 2 * pi / 4),
                    radius * sin(0.0 + 2 * pi / 4),
                  ),
                  child: Dot(
                    radius: dotRadius,
                    color: Colors.pinkAccent,
                  ),
                ),
                Transform.translate(
                  offset: Offset(
                    radius * cos(0.0 + 3 * pi / 4),
                    radius * sin(0.0 + 3 * pi / 4),
                  ),
                  child: Dot(
                    radius: dotRadius,
                    color: Colors.purple,
                  ),
                ),
                Transform.translate(
                  offset: Offset(
                    radius * cos(0.0 + 4 * pi / 4),
                    radius * sin(0.0 + 4 * pi / 4),
                  ),
                  child: Dot(
                    radius: dotRadius,
                    color: Colors.yellow,
                  ),
                ),
                Transform.translate(
                  offset: Offset(
                    radius * cos(0.0 + 5 * pi / 4),
                    radius * sin(0.0 + 5 * pi / 4),
                  ),
                  child: Dot(
                    radius: dotRadius,
                    color: Colors.lightGreen,
                  ),
                ),
                Transform.translate(
                  offset: Offset(
                    radius * cos(0.0 + 6 * pi / 4),
                    radius * sin(0.0 + 6 * pi / 4),
                  ),
                  child: Dot(
                    radius: dotRadius,
                    color: Colors.orangeAccent,
                  ),
                ),
                Transform.translate(
                  offset: Offset(
                    radius * cos(0.0 + 7 * pi / 4),
                    radius * sin(0.0 + 7 * pi / 4),
                  ),
                  child: Dot(
                    radius: dotRadius,
                    color: Colors.blueAccent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

class Dot extends StatelessWidget {
  const Dot({super.key, required this.radius, required this.color});
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: radius,
        height: radius,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
