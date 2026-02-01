import 'package:flutter/material.dart';
import 'ui/screens/setup_screen.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  initializeDateFormatting('zh_CN', null).then((_) {
    runApp(const MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '期货复盘训练',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
      ),
      home: const SetupScreen(),
    );
  }
}
