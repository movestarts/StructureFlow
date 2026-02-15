import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// 全局设置服务 - 持久化用户偏好
class SettingsService extends ChangeNotifier {
  // ===== 外观与偏好 =====
  // 应用界面主题: 'light' | 'dark'
  String appThemeMode = 'light';
  // K线图表主题: 'light' | 'dark'
  String chartThemeMode = 'dark';
  // 涨跌颜色: 'redUpGreenDown' | 'greenUpRedDown'
  String priceColorMode = 'redUpGreenDown';

  // ===== 系统配置 =====
  // 在线/离线模式
  bool isOnlineMode = false;
  // 图表初始加载 K线数量
  int initialKlineCount = 350;
  // 随机/裸K 预留最少K线
  int minReservedKlines = 300;
  // 随机模式允许加载的市场类型
  Set<String> allowedMarkets = {'crypto', 'futures'};
  // 随机模式允许加载的 K线周期
  Set<String> allowedPeriods = {
    '1M', '5M', '10M', '15M', '30M', '1H', '2H', '4H', '12H', '1D',
  };

  // 交易手续费 (%)
  double spotMakerFee = 0.050;
  double spotTakerFee = 0.100;
  double futuresMakerFee = 0.025;
  double futuresTakerFee = 0.050;

  // 数据缓存目录
  String dataCacheDir = '';

  // ===== LLM =====
  String llmProvider = 'zhipu'; // zhipu | openai | custom
  String llmApiKey = '';
  String llmEndpoint = 'https://open.bigmodel.cn/api/paas/v4/chat/completions';
  String llmModel = 'glm-4.6v-flash';

  // ===== 快捷键 =====
  String shortcutBuy = 'S';
  String shortcutSell = 'B';
  String shortcutClose = 'P';
  String shortcutNextBar = '→';
  String shortcutPrevBar = '←';

  SettingsService() {
    _loadFromDisk();
  }

  /// 恢复默认全局设置
  void resetGlobalSettings() {
    isOnlineMode = false;
    initialKlineCount = 350;
    minReservedKlines = 300;
    allowedMarkets = {'crypto', 'futures'};
    allowedPeriods = {
      '1M', '5M', '10M', '15M', '30M', '1H', '2H', '4H', '12H', '1D',
    };
    spotMakerFee = 0.050;
    spotTakerFee = 0.100;
    futuresMakerFee = 0.025;
    futuresTakerFee = 0.050;
    dataCacheDir = '';
    llmProvider = 'zhipu';
    llmApiKey = '';
    llmEndpoint = 'https://open.bigmodel.cn/api/paas/v4/chat/completions';
    llmModel = 'glm-4.6v-flash';
    notifyListeners();
    _saveToDisk();
  }

  /// 恢复默认快捷键
  void resetShortcuts() {
    shortcutBuy = 'S';
    shortcutSell = 'B';
    shortcutClose = 'P';
    shortcutNextBar = '→';
    shortcutPrevBar = '←';
    notifyListeners();
    _saveToDisk();
  }

  /// 保存所有设置
  void save() {
    notifyListeners();
    _saveToDisk();
  }

  // ===== 持久化 =====

  Future<String> get _filePath async {
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}/settings.json';
  }

  Future<void> _loadFromDisk() async {
    try {
      final path = await _filePath;
      final file = File(path);
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;

        appThemeMode = json['appThemeMode'] as String? ?? 'light';
        chartThemeMode = json['chartThemeMode'] as String? ?? 'dark';
        priceColorMode = json['priceColorMode'] as String? ?? 'redUpGreenDown';

        isOnlineMode = json['isOnlineMode'] as bool? ?? false;
        initialKlineCount = json['initialKlineCount'] as int? ?? 350;
        minReservedKlines = json['minReservedKlines'] as int? ?? 300;

        if (json['allowedMarkets'] != null) {
          allowedMarkets = Set<String>.from(json['allowedMarkets'] as List);
        }
        if (json['allowedPeriods'] != null) {
          allowedPeriods = Set<String>.from(json['allowedPeriods'] as List);
        }

        spotMakerFee = (json['spotMakerFee'] as num?)?.toDouble() ?? 0.050;
        spotTakerFee = (json['spotTakerFee'] as num?)?.toDouble() ?? 0.100;
        futuresMakerFee = (json['futuresMakerFee'] as num?)?.toDouble() ?? 0.025;
        futuresTakerFee = (json['futuresTakerFee'] as num?)?.toDouble() ?? 0.050;
        dataCacheDir = json['dataCacheDir'] as String? ?? '';
        llmProvider = json['llmProvider'] as String? ?? 'zhipu';
        llmApiKey = json['llmApiKey'] as String? ?? '';
        llmEndpoint = json['llmEndpoint'] as String? ??
            'https://open.bigmodel.cn/api/paas/v4/chat/completions';
        llmModel = json['llmModel'] as String? ?? 'glm-4.6v-flash';

        shortcutBuy = json['shortcutBuy'] as String? ?? 'S';
        shortcutSell = json['shortcutSell'] as String? ?? 'B';
        shortcutClose = json['shortcutClose'] as String? ?? 'P';
        shortcutNextBar = json['shortcutNextBar'] as String? ?? '→';
        shortcutPrevBar = json['shortcutPrevBar'] as String? ?? '←';

        notifyListeners();
      }
    } catch (e) {
      debugPrint('加载设置失败: $e');
    }
  }

  Future<void> _saveToDisk() async {
    try {
      final path = await _filePath;
      final file = File(path);
      await file.writeAsString(jsonEncode({
        'appThemeMode': appThemeMode,
        'chartThemeMode': chartThemeMode,
        'priceColorMode': priceColorMode,
        'isOnlineMode': isOnlineMode,
        'initialKlineCount': initialKlineCount,
        'minReservedKlines': minReservedKlines,
        'allowedMarkets': allowedMarkets.toList(),
        'allowedPeriods': allowedPeriods.toList(),
        'spotMakerFee': spotMakerFee,
        'spotTakerFee': spotTakerFee,
        'futuresMakerFee': futuresMakerFee,
        'futuresTakerFee': futuresTakerFee,
        'dataCacheDir': dataCacheDir,
        'llmProvider': llmProvider,
        'llmApiKey': llmApiKey,
        'llmEndpoint': llmEndpoint,
        'llmModel': llmModel,
        'shortcutBuy': shortcutBuy,
        'shortcutSell': shortcutSell,
        'shortcutClose': shortcutClose,
        'shortcutNextBar': shortcutNextBar,
        'shortcutPrevBar': shortcutPrevBar,
      }));
    } catch (e) {
      debugPrint('保存设置失败: $e');
    }
  }

  /// 将快捷键字符串转为 LogicalKeyboardKey
  LogicalKeyboardKey? getKeyForShortcut(String shortcut) {
    if (shortcut == '→') return LogicalKeyboardKey.arrowRight;
    if (shortcut == '←') return LogicalKeyboardKey.arrowLeft;
    if (shortcut == '↑') return LogicalKeyboardKey.arrowUp;
    if (shortcut == '↓') return LogicalKeyboardKey.arrowDown;
    if (shortcut.length == 1) {
      final lower = shortcut.toLowerCase();
      final code = lower.codeUnitAt(0);
      if (code >= 97 && code <= 122) {
        // a-z
        return LogicalKeyboardKey(code - 97 + 0x00000061);
      }
    }
    return null;
  }

  /// 将 LogicalKeyboardKey 转为显示字符串
  static String keyToLabel(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowRight) return '→';
    if (key == LogicalKeyboardKey.arrowLeft) return '←';
    if (key == LogicalKeyboardKey.arrowUp) return '↑';
    if (key == LogicalKeyboardKey.arrowDown) return '↓';
    final label = key.keyLabel;
    if (label.isNotEmpty) return label.toUpperCase();
    return '?';
  }
}
