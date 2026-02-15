import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/llm_profile.dart';
import 'database_service.dart';

/// 鍏ㄥ眬璁剧疆鏈嶅姟 - 鎸佷箙鍖栫敤鎴峰亸濂?
class SettingsService extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  // ===== 澶栬涓庡亸濂?=====
  // 搴旂敤鐣岄潰涓婚: 'light' | 'dark'
  String appThemeMode = 'light';
  // K绾垮浘琛ㄤ富棰? 'light' | 'dark'
  String chartThemeMode = 'dark';
  // 娑ㄨ穼棰滆壊: 'redUpGreenDown' | 'greenUpRedDown'
  String priceColorMode = 'redUpGreenDown';

  // ===== 绯荤粺閰嶇疆 =====
  // 鍦ㄧ嚎/绂荤嚎妯″紡
  bool isOnlineMode = false;
  // 鍥捐〃鍒濆鍔犺浇 K绾挎暟閲?
  int initialKlineCount = 350;
  // 闅忔満/瑁窴 棰勭暀鏈€灏慘绾?
  int minReservedKlines = 300;
  // 闅忔満妯″紡鍏佽鍔犺浇鐨勫競鍦虹被鍨?
  Set<String> allowedMarkets = {'crypto', 'futures'};
  // 闅忔満妯″紡鍏佽鍔犺浇鐨?K绾垮懆鏈?
  Set<String> allowedPeriods = {
    '1M', '5M', '10M', '15M', '30M', '1H', '2H', '4H', '12H', '1D',
  };

  // 浜ゆ槗鎵嬬画璐?(%)
  double spotMakerFee = 0.050;
  double spotTakerFee = 0.100;
  double futuresMakerFee = 0.025;
  double futuresTakerFee = 0.050;

  // 鏁版嵁缂撳瓨鐩綍
  String dataCacheDir = '';

  // ===== LLM =====
  String llmProvider = 'zhipu'; // zhipu | openai | custom
  String llmApiKey = '';
  String llmEndpoint = 'https://open.bigmodel.cn/api/paas/v4/chat/completions';
  String llmModel = 'glm-4.6v';
  List<LlmProfile> llmProfiles = [];
  String llmVisionProfileId = 'default_vision';
  String llmTextProfileId = 'default_text';

  // ===== 蹇嵎閿?=====
  String shortcutBuy = 'S';
  String shortcutSell = 'B';
  String shortcutClose = 'P';
  String shortcutNextBar = '→';
  String shortcutPrevBar = '←';

  SettingsService() {
    llmProfiles = _buildDefaultProfiles();
    llmVisionProfileId = llmProfiles.first.id;
    llmTextProfileId = llmProfiles.last.id;
    _loadFromDisk();
  }

  /// 鎭㈠榛樿鍏ㄥ眬璁剧疆
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
    llmModel = 'glm-4.6v';
    llmProfiles = _buildDefaultProfiles();
    llmVisionProfileId = llmProfiles.first.id;
    llmTextProfileId = llmProfiles.last.id;
    notifyListeners();
    _saveToDisk();
  }

  /// 鎭㈠榛樿蹇嵎閿?
  void resetShortcuts() {
    shortcutBuy = 'S';
    shortcutSell = 'B';
    shortcutClose = 'P';
    shortcutNextBar = '→';
    shortcutPrevBar = '←';
    notifyListeners();
    _saveToDisk();
  }

  /// 淇濆瓨鎵€鏈夎缃?
  void save() {
    notifyListeners();
    _saveToDisk();
  }

  // ===== 鎸佷箙鍖?=====

  Future<String> get _filePath async {
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}/settings.json';
  }

  Future<void> _loadFromDisk() async {
    try {
      final path = await _filePath;
      final file = File(path);
      bool fileHasLlmConfig = false;
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
        fileHasLlmConfig = _hasLlmSettings(json);
        _applyLlmSettingsMap(json);

        shortcutBuy = json['shortcutBuy'] as String? ?? 'S';
        shortcutSell = json['shortcutSell'] as String? ?? 'B';
        shortcutClose = json['shortcutClose'] as String? ?? 'P';
        shortcutNextBar = json['shortcutNextBar'] as String? ?? '→';
        shortcutPrevBar = json['shortcutPrevBar'] as String? ?? '←';

      }
      final dbLlm = await _db.loadLlmConfigSnapshot();
      if (dbLlm != null && !fileHasLlmConfig) {
        _applyLlmSettingsMap(dbLlm);
      }
      _ensureLlmProfileBindings();
      notifyListeners();
    } catch (e) {
      debugPrint('鍔犺浇璁剧疆澶辫触: $e');
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
        'llmProfiles': llmProfiles.map((e) => e.toJson()).toList(),
        'llmVisionProfileId': llmVisionProfileId,
        'llmTextProfileId': llmTextProfileId,
        'shortcutBuy': shortcutBuy,
        'shortcutSell': shortcutSell,
        'shortcutClose': shortcutClose,
        'shortcutNextBar': shortcutNextBar,
        'shortcutPrevBar': shortcutPrevBar,
      }));
    } catch (e) {
      debugPrint('Save settings file failed: $e');
    }

    try {
      await _db.saveLlmConfigSnapshot(_buildLlmSettingsMap());
    } catch (e) {
      debugPrint('Save llm config snapshot failed: $e');
    }
  }

  /// 灏嗗揩鎹烽敭瀛楃涓茶浆涓?LogicalKeyboardKey
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

  /// 灏?LogicalKeyboardKey 杞负鏄剧ず瀛楃涓?
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

  bool _hasLlmSettings(Map<String, dynamic> json) {
    return json.containsKey('llmProfiles') ||
        json.containsKey('llmVisionProfileId') ||
        json.containsKey('llmTextProfileId') ||
        json.containsKey('llmApiKey') ||
        json.containsKey('llmModel');
  }

  List<LlmProfile> _buildDefaultProfiles() {
    return const [
      LlmProfile(
        id: 'default_vision',
        name: 'Zhipu Vision Default',
        provider: 'zhipu',
        apiKey: '',
        endpoint: 'https://open.bigmodel.cn/api/paas/v4/chat/completions',
        model: 'glm-4.6v',
        supportsVision: true,
        supportsText: false,
      ),
      LlmProfile(
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
      llmVisionProfileId =
          llmProfiles.firstWhere((e) => e.supportsVision, orElse: () => llmProfiles.first).id;
    }
    if (llmProfiles.every((e) => e.id != llmTextProfileId)) {
      llmTextProfileId =
          llmProfiles.firstWhere((e) => e.supportsText, orElse: () => llmProfiles.first).id;
    }

    final vision = llmProfiles.firstWhere(
      (e) => e.id == llmVisionProfileId,
      orElse: () => llmProfiles.first,
    );
    if (!vision.supportsVision) {
      llmVisionProfileId =
          llmProfiles.firstWhere((e) => e.supportsVision, orElse: () => llmProfiles.first).id;
    }
    final text = llmProfiles.firstWhere(
      (e) => e.id == llmTextProfileId,
      orElse: () => llmProfiles.first,
    );
    if (!text.supportsText) {
      llmTextProfileId =
          llmProfiles.firstWhere((e) => e.supportsText, orElse: () => llmProfiles.first).id;
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

  void setTaskProfileBinding({
    String? visionProfileId,
    String? textProfileId,
  }) {
    if (visionProfileId != null) llmVisionProfileId = visionProfileId;
    if (textProfileId != null) llmTextProfileId = textProfileId;
    _ensureLlmProfileBindings();
    save();
  }

  void upsertLlmProfile(LlmProfile profile) {
    final idx = llmProfiles.indexWhere((e) => e.id == profile.id);
    if (idx >= 0) {
      llmProfiles[idx] = profile;
    } else {
      llmProfiles.add(profile);
    }
    _ensureLlmProfileBindings();
    save();
  }

  void removeLlmProfile(String id) {
    if (llmProfiles.length <= 1) return;
    llmProfiles.removeWhere((e) => e.id == id);
    _ensureLlmProfileBindings();
    save();
  }
}

