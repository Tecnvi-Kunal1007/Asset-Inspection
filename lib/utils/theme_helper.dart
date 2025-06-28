import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ThemeHelper {
  // Primary colors
  static Color primaryBlue = const Color(0xFF2196F3);
  static Color purple = const Color(0xFF9C27B0);
  static Color teal = const Color(0xFF009688);
  static Color orange = const Color(0xFFFF9800);
  static Color green = const Color(0xFF4CAF50);
  static Color indigo = const Color(0xFF3F51B5);
  static Color cyan = const Color(0xFF00BCD4);
  static Color pink = const Color(0xFFE91E63);

  // Background colors
  static Color backgroundLight = const Color(0xFFF5F7FA);
  static Color cardBackground = Colors.white;
  
  // Text colors
  static Color textPrimary = const Color(0xFF2D3748);
  static Color textSecondary = const Color(0xFF718096);
  static Color textLight = Colors.white;
  
  // Gradient backgrounds
  static LinearGradient blueGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryBlue.withOpacity(0.8), primaryBlue],
  );
  
  static LinearGradient purpleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [purple.withOpacity(0.8), purple],
  );
  
  static LinearGradient tealGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [teal.withOpacity(0.8), teal],
  );
  
  static LinearGradient orangeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [orange.withOpacity(0.8), orange],
  );
  
  static LinearGradient greenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [green.withOpacity(0.8), green],
  );
  
  static LinearGradient indigoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [indigo.withOpacity(0.8), indigo],
  );
  
  static LinearGradient cyanGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [cyan.withOpacity(0.8), cyan],
  );
  
  static LinearGradient pinkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [pink.withOpacity(0.8), pink],
  );
  
  static LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      backgroundLight,
      backgroundLight.withOpacity(0.8),
    ],
  );
  
  // Shadow styles
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static var backgroundGray;
  
  static List<BoxShadow> coloredShadow(Color color) {
    return [
      BoxShadow(
        color: color.withOpacity(0.15),
        blurRadius: 12,
        offset: const Offset(0, 5),
      ),
    ];
  }
  
  // Text styles
  static TextStyle headingStyle(BuildContext context, {Color? color}) {
    return GoogleFonts.poppins(
      fontSize: 22,
      fontWeight: FontWeight.bold,
      color: color ?? textPrimary,
    );
  }
  
  static TextStyle subheadingStyle(BuildContext context, {Color? color}) {
    return GoogleFonts.poppins(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: color ?? textPrimary,
    );
  }
  
  static TextStyle bodyStyle(BuildContext context, {Color? color}) {
    return GoogleFonts.poppins(
      fontSize: 14,
      color: color ?? textSecondary,
    );
  }
  
  static TextStyle buttonTextStyle(BuildContext context, {Color? color}) {
    return GoogleFonts.poppins(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: color ?? textLight,
    );
  }
  
  // Card decoration
  static BoxDecoration cardDecoration({Color? color, LinearGradient? gradient}) {
    return BoxDecoration(
      color: color ?? cardBackground,
      gradient: gradient,
      borderRadius: BorderRadius.circular(24),
      boxShadow: cardShadow,
    );
  }
  
  static BoxDecoration gradientCardDecoration(LinearGradient gradient) {
    return BoxDecoration(
      gradient: gradient,
      borderRadius: BorderRadius.circular(24),
      boxShadow: cardShadow,
    );
  }
  
  // Button styles
  static ButtonStyle primaryButtonStyle(Color color) {
    return ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
    );
  }
  
  // Floating element decoration
  static Widget floatingElement({
    required double size,
    required Color color,
    double opacity = 0.1,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(opacity),
      ),
    );
  }
  
  // Helper method to get a random gradient
  static LinearGradient getRandomGradient() {
    final gradients = [
      blueGradient,
      purpleGradient,
      tealGradient,
      orangeGradient,
      greenGradient,
      indigoGradient,
      cyanGradient,
      pinkGradient,
    ];
    
    return gradients[DateTime.now().millisecond % gradients.length];
  }
  
  // Helper method to get a gradient by index
  static LinearGradient getGradientByIndex(int index) {
    final gradients = [
      blueGradient,
      purpleGradient,
      tealGradient,
      orangeGradient,
      greenGradient,
      indigoGradient,
      cyanGradient,
      pinkGradient,
    ];
    
    return gradients[index % gradients.length];
  }
  
  // Helper method to get a color by index
  static Color getColorByIndex(int index) {
    final colors = [
      primaryBlue,
      purple,
      teal,
      orange,
      green,
      indigo,
      cyan,
      pink,
    ];
    
    return colors[index % colors.length];
  }
} 