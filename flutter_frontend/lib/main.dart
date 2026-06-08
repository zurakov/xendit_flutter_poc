import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/payment_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => PaymentProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Xendit Payment POC',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF6366F1), // Electric Indigo
        scaffoldBackgroundColor: const Color(0xFF0F111A), // Dark Obsidian
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFF10B981), // Emerald
          surface: Color(0xFF1E2230),
          error: Color(0xFFF87171),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          bodyLarge: TextStyle(color: Colors.white70),
          bodyMedium: TextStyle(color: Colors.grey),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF161925),
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
          iconTheme: IconThemeData(color: Colors.white70),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
