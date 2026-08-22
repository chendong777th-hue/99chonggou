import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_tokens.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        fontFamily: AppTokens.fontFamily,
        colorScheme: const ColorScheme.light(
          primary: AppTokens.brand500,
          onPrimary: Colors.white,
          primaryContainer: AppTokens.brand50,
          onPrimaryContainer: AppTokens.brand700,
          secondary: AppTokens.brand300,
          onSecondary: Colors.white,
          surface: AppTokens.surface,
          onSurface: AppTokens.ink900,
          surfaceContainerHighest: AppTokens.ink25,
          outline: AppTokens.ink200,
          outlineVariant: AppTokens.divider,
          error: AppTokens.danger,
          onError: Colors.white,
        ),
        scaffoldBackgroundColor: AppTokens.surfaceAlt,
        dividerColor: AppTokens.divider,
        splashFactory: InkSparkle.splashFactory,
        appBarTheme: AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0.5,
          backgroundColor: AppTokens.surface,
          foregroundColor: AppTokens.ink900,
          iconTheme: IconThemeData(
            color: AppTokens.brand500,
          ),
          actionsIconTheme: IconThemeData(
            color: AppTokens.brand500,
          ),
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          titleTextStyle: TextStyle(
            fontFamily: AppTokens.fontFamily,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTokens.ink900,
            letterSpacing: -0.2,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppTokens.surface,
          selectedItemColor: AppTokens.brand500,
          unselectedItemColor: AppTokens.ink400,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppTokens.surface,
          indicatorColor: AppTokens.brand50,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTokens.brand500,
              );
            }
            return const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: AppTokens.ink400,
            );
          }),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: AppTokens.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.rMd),
            side: const BorderSide(color: AppTokens.divider, width: 1),
          ),
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppTokens.ink25,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTokens.rMd),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTokens.rMd),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTokens.rMd),
            borderSide: const BorderSide(color: AppTokens.brand400, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          hintStyle: AppTokens.body.copyWith(color: AppTokens.ink300),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTokens.brand500,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.rMd),
            ),
            textStyle: AppTokens.button,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppTokens.brand500,
            textStyle: AppTokens.link,
          ),
        ),
        iconTheme: const IconThemeData(
          color: AppTokens.ink500,
          size: 22,
        ),
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 2),
          minLeadingWidth: 0,
        ),
        dividerTheme: const DividerThemeData(
          color: AppTokens.divider,
          thickness: 1,
          space: 0,
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: AppTokens.fontFamily,
        colorScheme: ColorScheme.dark(
          primary: AppTokens.brand400,
          onPrimary: Colors.white,
          primaryContainer: AppTokens.brand700.withOpacity(0.4),
          onPrimaryContainer: AppTokens.brand300,
          secondary: AppTokens.brand300,
          onSecondary: AppTokens.ink900,
          surface: const Color(0xFF111827),
          onSurface: const Color(0xFFE5E7EB),
          surfaceContainerHighest: const Color(0xFF1F2937),
          outline: const Color(0xFF374151),
          outlineVariant: const Color(0xFF1F2937),
          error: const Color(0xFFF87171),
          onError: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFF0B1220),
        dividerColor: const Color(0xFF1F2937),
        splashFactory: InkSparkle.splashFactory,
        appBarTheme: AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0.5,
          backgroundColor: Color(0xFF111827),
          foregroundColor: Color(0xFFE5E7EB),
          iconTheme: IconThemeData(
            color: AppTokens.brand500,
          ),
          actionsIconTheme: IconThemeData(
            color: AppTokens.brand500,
          ),
          systemOverlayStyle: SystemUiOverlayStyle.light,
          titleTextStyle: TextStyle(
            fontFamily: AppTokens.fontFamily,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFFE5E7EB),
            letterSpacing: -0.2,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF111827),
          selectedItemColor: AppTokens.brand400,
          unselectedItemColor: Color(0xFF6B7280),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xFF111827),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.rMd),
            side: const BorderSide(color: Color(0xFF1F2937), width: 1),
          ),
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1F2937),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTokens.rMd),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTokens.rMd),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTokens.rMd),
            borderSide: const BorderSide(color: AppTokens.brand400, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          hintStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 15),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTokens.brand500,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.rMd),
            ),
          ),
        ),
        iconTheme: const IconThemeData(
          color: Color(0xFF9CA3AF),
          size: 22,
        ),
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 2),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF1F2937),
          thickness: 1,
          space: 0,
        ),
      );
}
