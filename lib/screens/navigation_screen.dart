import 'package:flutter/material.dart';
import '../utils/route_step.dart'; // Import RouteStep here
import '../services/navigation_service.dart';

class NavigationPage extends StatelessWidget {
  final List<RouteStep> steps;
  final int currentStepIndex;

  const NavigationPage({
    Key? key,
    required this.steps,
    this.currentStepIndex = 0,
  }) : super(key: key);

  // Colors and styles
  static const backgroundColor = Color(0xFF2A2A2A);
  static const buttonBackground = Color(0xFF232323);
  static const buttonHighlighted = Color(0xFF333333);
  static const accentColor = Color(0xFFE7E486);
  static const textActive = Color(0xFFF4F4F4);
  static const textInactive = Color(0xFFA4A4A4);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        title: const Text("Navigation", style: TextStyle(color: textInactive)),
      ),
      body: ListView.builder(
        itemCount: steps.length,
        itemBuilder: (context, index) {
          Color textColor;
          if (index == currentStepIndex) {
            textColor = accentColor;
          } else if (index == currentStepIndex + 1) {
            textColor = textActive;
          } else {
            textColor = textInactive;
          }

          return ListTile(
            title: Text(
              steps[index].instruction,
              style: TextStyle(color: textColor, fontSize: 24),
            ),
            subtitle: Text(
              (steps[index].additionalDetails.isNotEmpty
                  ? steps[index].additionalDetails + "\n"
                  : '') + steps[index].distance,
              style: TextStyle(color: textInactive, fontSize: 18),
            ),
          );
        },
      ),
    );
  }
}
