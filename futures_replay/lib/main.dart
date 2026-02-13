import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'ui/screens/home_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'ui/theme/app_theme.dart';
import 'services/account_service.dart';
import 'services/settings_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );
  initializeDateFormatting('zh_CN', null).then((_) {
    runApp(const MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AccountService()),
        ChangeNotifierProvider(create: (_) => SettingsService()),
      ],
      child: Consumer<SettingsService>(
        builder: (context, settings, _) {
          final isLight = settings.appThemeMode == 'light';
          return MaterialApp(
            title: 'K线训练营',
            debugShowCheckedModeBanner: false,
            theme: isLight ? AppTheme.lightTheme : AppTheme.darkTheme,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
