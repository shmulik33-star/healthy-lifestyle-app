import 'package:flutter/material.dart';
class AppTheme {
  static const green=Color(0xFF28816C), softGreen=Color(0xFFE8F5EE), purple=Color(0xFF8B5CF6), blue=Color(0xFF2563EB), orange=Color(0xFFFF8A00), background=Color(0xFFF7F8F8), ink=Color(0xFF1D1F23);

  // "Energetic/playful" accent palette -- home screen + floating nav bar
  // only (see home_screen.dart, app/shell.dart), picked from the direction
  // the product owner chose out of three mockup options. Deliberately not
  // wired into the base ThemeData/scaffoldBackgroundColor above: a full
  // app-wide reskin is a separate, larger piece of work than this pass.
  static const coral=Color(0xFFFF6B4A), teal=Color(0xFF3AB6C9), lavender=Color(0xFF8B7FE8), sunny=Color(0xFFFFC93C), mint=Color(0xFF38B27A), softMint=Color(0xFFEFF9F1), cream=Color(0xFFFFF8EE), warmInk=Color(0xFF221A12), warmMuted=Color(0xFF7A6E5F);
  static ThemeData get light { final scheme=ColorScheme.fromSeed(seedColor:green,brightness:Brightness.light,surface:Colors.white); return ThemeData(useMaterial3:true,colorScheme:scheme,scaffoldBackgroundColor:background,textTheme:const TextTheme(headlineSmall:TextStyle(fontWeight:FontWeight.w800,color:ink),titleLarge:TextStyle(fontWeight:FontWeight.w800,color:ink),titleMedium:TextStyle(fontWeight:FontWeight.w700,color:ink),bodyLarge:TextStyle(height:1.45,color:ink),bodyMedium:TextStyle(height:1.4,color:ink)),cardTheme:const CardThemeData(elevation:0,margin:EdgeInsets.zero,shape:RoundedRectangleBorder(borderRadius:BorderRadius.all(Radius.circular(20)),side:BorderSide(color:Color(0xFFE7EAEA)))),filledButtonTheme:FilledButtonThemeData(style:FilledButton.styleFrom(backgroundColor:green,foregroundColor:Colors.white,minimumSize:const Size(0,48),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16))))); }
}
