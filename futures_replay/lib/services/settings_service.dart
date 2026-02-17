import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/llm_profile.dart';
import 'database_service.dart';

class SettingsService extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  bool _isInitialized = false;
  bool _isInitializing = false;
  final List<void Function()> _pendingOperations = [];

  String appThemeMode = 'light';
  String chartThemeMode = 'dark';
  String priceColorMode = 'redUpGreenDown';

  bool isOnlineMode = false;
  int initialKlineCount = 350;
  int minReservedKlines = 300;
  Set<String> allowedMarkets = {'crypto', 'futures'};
  Set<String> allowedPeriods = {
    '1M',
    '5M',
    '10M',
    '15M',
    '30M',
    '1H',
    '2H',
    '4H',
    '12H',
    '1D',
  };

  double spotMakerFee = 0.050;
  double spotTakerFee = 0.100;
  double futuresMakerFee = 0.025;
  double futuresTakerFee = 0.050;

  String dataCacheDir = '';

  String llmProvider = 'zhipu';
  String llmApiKey = '';
  String llmEndpoint = 'https://open.bigmodel.cn/api/paas/v4/chat/completions';
  String llmModel = 'glm-4.6v';
  List<LlmProfile> llmProfiles = [];
  String llmVisionProfileId = 'default_vision';
  String llmTextProfileId = 'default_text';

  String shortcutBuy = 'S';
  String shortcutSell = 'B';
  String shortcutClose = 'P';
  String shortcutNextBar = '→';
  String shortcutPrevBar = '←';

  SettingsService() {
    llmProfiles = _buildDefaultProfiles();
    llmVisionProfileId = llmProfiles.first.id;
    llmTextProfileId = llmProfiles.last.id;
    _initAsync();
  }

  Future<void> _initAsync() async {
    _isInitializing = true;
    await _loadFromDisk();
    _isInitializing = false;
    _isInitialized = true;

    for (final op in _pendingOperations) {
      op();
    }
    _pendingOperations.clear();
  }

  void _runAfterInit(void Function() operation) {
    if (_isInitialized) {
      operation();
    } else {
      _pendingOperations.add(operation);
    }
  }

  /// 等待初始化完成后，将当前大模型配置写入数据库（确保 API Key 等真正落盘）
  Future<void> persistLlmConfig() async {
    while (!_isInitialized) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    try {
      await _db.saveLlmConfigSnapshot(_buildLlmSettingsMap());
    } catch (e) {
      debugPrint('Save llm config snapshot failed: $e');
      rethrow;
    }
  }

  void resetGlobalSettings() {
    isOnlineMode = false;
    initialKlineCount = 350;
    minReservedKlines = 300;
    allowedMarkets = {'crypto', 'futures'};
    allowedPeriods = {
      '1M',
      '5M',
      '10M',
      '15M',
      '30M',
      '1H',
      '2H',
      '4H',
      '12H',
      '1D',
    };
    spotMakerFee = 0.050;
    spotTakerFee = 0.100;
    futuresMakerFee = 0.025;
    futuresTakerFee = 0.050;
    dataCacheDir = '';
    llmProvider = 'zhipu';
    llmApiKey = '';
    llmEndpoint = 'https://open.bigmodel.cn/api/paas/v4/chat/completions';
    llmModel = 'glm-4.6v';
    llmProfiles = _buildDefaultProfiles();
    llmVisionProfileId = llmProfiles.first.id;
    llmTextProfileId = llmProfiles.last.id;
    notifyListeners();
    _runAfterInit(() => _saveToDisk());
  }

  void resetShortcuts() {
    shortcutBuy = 'S';
    shortcutSell = 'B';
    shortcutClose = 'P';
    shortcutNextBar = '→';
    shortcutPrevBar = '←';
    notifyListeners();
    _runAfterInit(() => _saveToDisk());
  }

  void save() {
    notifyListeners();
    _runAfterInit(() => _saveToDisk());
  }

  Future<String> get _filePath async {
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}/settings.json';
  }

  Future<void> _loadFromDisk() async {
    try {
      final path = await _filePath;
      final file = File(path);
      if (await file.exists()) {
        final json =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;

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
        futuresMakerFee =
            (json['futuresMakerFee'] as num?)?.toDouble() ?? 0.025;
        futuresTakerFee =
            (json['futuresTakerFee'] as num?)?.toDouble() ?? 0.050;
        dataCacheDir = json['dataCacheDir'] as String? ?? '';
        // 大模型配置仅从数据库加载，不读配置文件

        shortcutBuy = json['shortcutBuy'] as String? ?? 'S';
        shortcutSell = json['shortcutSell'] as String? ?? 'B';
        shortcutClose = json['shortcutClose'] as String? ?? 'P';
        shortcutNextBar = json['shortcutNextBar'] as String? ?? '→';
        shortcutPrevBar = json['shortcutPrevBar'] as String? ?? '←';
      }
      // 大模型配置只从数据库加载
      final dbLlm = await _db.loadLlmConfigSnapshot();
      if (dbLlm != null) {
        _applyLlmSettingsMap(dbLlm);
      }
      _ensureLlmProfileBindings();
      notifyListeners();
    } catch (e) {
      debugPrint('Load settings failed: $e');
    }
  }

  Future<void> _saveToDisk() async {
    // 大模型配置只写入数据库，不写入配置文件
    try {
      await _db.saveLlmConfigSnapshot(_buildLlmSettingsMap());
    } catch (e) {
      debugPrint('Save llm config snapshot failed: $e');
    }

    try {
      final path = await _filePath;
      final file = File(path);
      await file.writeAsString(
        jsonEncode({
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
          'shortcutBuy': shortcutBuy,
          'shortcutSell': shortcutSell,
          'shortcutClose': shortcutClose,
          'shortcutNextBar': shortcutNextBar,
          'shortcutPrevBar': shortcutPrevBar,
        }),
      );
    } catch (e) {
      debugPrint('Save settings file failed: $e');
    }
  }

  LogicalKeyboardKey? getKeyForShortcut(String shortcut) {
    if (shortcut == '→') return LogicalKeyboardKey.arrowRight;
    if (shortcut == '←') return LogicalKeyboardKey.arrowLeft;
    if (shortcut == '↑') return LogicalKeyboardKey.arrowUp;
    if (shortcut == '↓') return LogicalKeyboardKey.arrowDown;
    if (shortcut.length == 1) {
      final lower = shortcut.toLowerCase();
      final code = lower.codeUnitAt(0);
      if (code >= 97 && code <= 122) {
        return LogicalKeyboardKey(code - 97 + 0x00000061);
      }
    }
    return null;
  }

  static String keyToLabel(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowRight) return '→';
    if (key == LogicalKeyboardKey.arrowLeft) return '←';
    if (key == LogicalKeyboardKey.arrowUp) return '↑';
    if (key == LogicalKeyboardKey.arrowDown) return '↓';
    final label = key.keyLabel;
    if (label.isNotEmpty) return label.toUpperCase();
    return '?';
  }

  void _applyLlmSettingsMap(Map<String, dynamic> json) {
    llmProvider = json['llmProvider'] as String? ?? llmProvider;
    llmApiKey = json['llmApiKey'] as String? ?? llmApiKey;
    llmEndpoint = json['llmEndpoint'] as String? ?? llmEndpoint;
    llmModel = json['llmModel'] as String? ?? llmModel;
    if (json['llmProfiles'] is List) {
      llmProfiles = (json['llmProfiles'] as List)
          .whereType<Map>()
          .map((e) => LlmProfile.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.id.isNotEmpty)
          .toList();
    }
    llmVisionProfileId =
        json['llmVisionProfileId'] as String? ?? llmVisionProfileId;
    llmTextProfileId = json['llmTextProfileId'] as String? ?? llmTextProfileId;
    _migrateLegacyLlmConfigIfNeeded();
    _ensureLlmProfileBindings();
  }

  Map<String, dynamic> _buildLlmSettingsMap() {
    return {
      'llmProvider': llmProvider,
      'llmApiKey': llmApiKey,
      'llmEndpoint': llmEndpoint,
      'llmModel': llmModel,
      'llmProfiles': llmProfiles.map((e) => e.toJson()).toList(),
      'llmVisionProfileId': llmVisionProfileId,
      'llmTextProfileId': llmTextProfileId,
    };
  }

  List<LlmProfile> _buildDefaultProfiles() {
    return [
      const LlmProfile(
        id: 'default_vision',
        name: 'Zhipu Vision Default',
        provider: 'zhipu',
        apiKey: '',
        endpoint: 'https://open.bigmodel.cn/api/paas/v4/chat/completions',
        model: 'glm-4.6v',
        supportsVision: true,
        supportsText: false,
      ),
      const LlmProfile(
        id: 'default_text',
        name: 'Zhipu Text Default',
        provider: 'zhipu',
        apiKey: '',
        endpoint: 'https://open.bigmodel.cn/api/paas/v4/chat/completions',
        model: 'glm-5',
        supportsVision: false,
        supportsText: true,
      ),
    ];
  }

  void _migrateLegacyLlmConfigIfNeeded() {
    if (llmProfiles.isNotEmpty) return;

    final legacy = LlmProfile(
      id: 'legacy_default',
      name: 'Legacy Migrated',
      provider: llmProvider,
      apiKey: llmApiKey,
      endpoint: llmEndpoint,
      model: llmModel,
      supportsVision: true,
      supportsText: true,
    );
    llmProfiles = [legacy];
    llmVisionProfileId = legacy.id;
    llmTextProfileId = legacy.id;
  }

  void _ensureLlmProfileBindings() {
    if (llmProfiles.isEmpty) {
      llmProfiles = _buildDefaultProfiles();
    }
    if (llmProfiles.every((e) => e.id != llmVisionProfileId)) {
      llmVisionProfileId = llmProfiles
          .firstWhere((e) => e.supportsVision, orElse: () => llmProfiles.first)
          .id;
    }
    if (llmProfiles.every((e) => e.id != llmTextProfileId)) {
      llmTextProfileId = llmProfiles
          .firstWhere((e) => e.supportsText, orElse: () => llmProfiles.first)
          .id;
    }

    final vision = llmProfiles.firstWhere(
      (e) => e.id == llmVisionProfileId,
      orElse: () => llmProfiles.first,
    );
    if (!vision.supportsVision) {
      llmVisionProfileId = llmProfiles
          .firstWhere((e) => e.supportsVision, orElse: () => llmProfiles.first)
          .id;
    }
    final text = llmProfiles.firstWhere(
      (e) => e.id == llmTextProfileId,
      orElse: () => llmProfiles.first,
    );
    if (!text.supportsText) {
      llmTextProfileId = llmProfiles
          .firstWhere((e) => e.supportsText, orElse: () => llmProfiles.first)
          .id;
    }
    _syncLegacyLlmFieldsWithVisionProfile();
  }

  void _syncLegacyLlmFieldsWithVisionProfile() {
    final p = getVisionProfile();
    llmProvider = p.provider;
    llmApiKey = p.apiKey;
    llmEndpoint = p.endpoint;
    llmModel = p.model;
  }

  LlmProfile getVisionProfile() {
    return llmProfiles.firstWhere(
      (e) => e.id == llmVisionProfileId,
      orElse: () => llmProfiles.first,
    );
  }

  LlmProfile getTextProfile() {
    return llmProfiles.firstWhere(
      (e) => e.id == llmTextProfileId,
      orElse: () => llmProfiles.first,
    );
  }

  LlmProfile getProfileForTask(String task) {
    if (task == 'text_analysis') return getTextProfile();
    return getVisionProfile();
  }

  List<LlmProfile> get visionEnabledProfiles =>
      llmProfiles.where((e) => e.supportsVision).toList();

  List<LlmProfile> get textEnabledProfiles =>
      llmProfiles.where((e) => e.supportsText).toList();

  void setTaskProfileBinding({String? visionProfileId, String? textProfileId}) {
    if (visionProfileId != null) llmVisionProfileId = visionProfileId;
    if (textProfileId != null) llmTextProfileId = textProfileId;
    _ensureLlmProfileBindings();
    save();
  }

  /// 新增或更新模型配置，并立即写入数据库（含 API Key），失败会抛出异常
  Future<void> upsertLlmProfile(LlmProfile profile) async {
    final idx = llmProfiles.indexWhere((e) => e.id == profile.id);
    if (idx >= 0) {
      llmProfiles[idx] = profile;
    } else {
      llmProfiles.add(profile);
    }
    _ensureLlmProfileBindings();
    notifyListeners();
    await persistLlmConfig();
    save(); // 再触发一次，保证其他配置也写入
  }

  Future<void> removeLlmProfile(String id) async {
    if (llmProfiles.length <= 1) return;
    llmProfiles.removeWhere((e) => e.id == id);
    _ensureLlmProfileBindings();
    notifyListeners();
    await persistLlmConfig();
    save();
  }
}
