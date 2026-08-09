import 'package:flutter/material.dart';

/// Shared accent palette for teams, so a team reads with the same color
/// wherever it appears in the setup screens.
const List<Color> _teamColors = [
  Color(0xFF1565C0), // blue
  Color(0xFF2E7D32), // green
  Color(0xFFC62828), // red
  Color(0xFF6A1B9A), // purple
  Color(0xFFE65100), // orange
  Color(0xFF00695C), // teal
];

/// The accent color for the team at [teamIndex], cycling through the palette.
Color teamColor(int teamIndex) => _teamColors[teamIndex % _teamColors.length];
