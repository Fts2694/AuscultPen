import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/home_screen.dart';
import 'services/database_service.dart';
import 'providers/settings_provider.dart';

void main() async {
  // 确保 Flutter 绑定初始化（异步操作前必须调用）
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化日期格式化（中文 locale）
  await initializeDateFormatting('zh_CN');

  // 初始化 Isar 数据库
  await DatabaseService().init();

  // 初始化设置（读取 SharedPreferences）
  final container = ProviderContainer();
  await container.read(settingsProvider.notifier).load();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const AuscultPenApp(),
    ),
  );
}

class AuscultPenApp extends StatelessWidget {
  const AuscultPenApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1677FF);
    const backgroundColor = Color(0xFFF5F7FA);

    return MaterialApp(
      title: 'AuscultPen 听诊笔',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          primary: primaryColor,
          surface: backgroundColor,
        ),
        scaffoldBackgroundColor: backgroundColor,
        textTheme: GoogleFonts.notoSansScTextTheme(
          Theme.of(context).textTheme,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryColor, width: 2),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: primaryColor.withValues(alpha: 0.1),
          labelTextStyle: WidgetStateProperty.all(
            GoogleFonts.notoSansSc(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
