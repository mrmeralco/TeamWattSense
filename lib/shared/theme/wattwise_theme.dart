import 'package:flutter/material.dart';

const green = Color(0xff168b4a);
const paleGreen = Color(0xffe9f8e0);
const summaryGradient =
    LinearGradient(colors: [Color(0xff239d58), Color(0xff086438)]);

ThemeData wattwiseTheme(bool dark) {
  final scheme = ColorScheme.fromSeed(
          seedColor: green,
          brightness: dark ? Brightness.dark : Brightness.light)
      .copyWith(
          primary: dark ? const Color(0xff76d99c) : green,
          surface: dark ? const Color(0xff1b2520) : Colors.white);
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    colorScheme: scheme,
    scaffoldBackgroundColor:
        dark ? const Color(0xff111914) : const Color(0xfff7f7f7),
    textTheme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light)
        .textTheme
        .apply(
            fontFamily: 'Inter',
            bodyColor: dark ? const Color(0xffe8efe9) : const Color(0xff242827),
            displayColor:
                dark ? const Color(0xffe8efe9) : const Color(0xff242827)),
    dividerColor: dark ? const Color(0xff334138) : const Color(0xffe5e5e5),
    inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: scheme.outlineVariant)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: scheme.outlineVariant))),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            backgroundColor: green,
            foregroundColor: Colors.white,
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)))),
    appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent),
  );
}
