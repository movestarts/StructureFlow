import 'package:flutter/services.dart';

/// 屏幕方向管理服务
class ScreenOrientationService {
  static final ScreenOrientationService _instance = ScreenOrientationService._internal();
  factory ScreenOrientationService() => _instance;
  ScreenOrientationService._internal();

  bool _isLandscape = false;
  bool get isLandscape => _isLandscape;

  /// 切换到横屏模式
  Future<void> setLandscape() async {
    _isLandscape = true;
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  /// 切换到竖屏模式
  Future<void> setPortrait() async {
    _isLandscape = false;
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  /// 自动旋转（允许所有方向）
  Future<void> setAutoRotate() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  /// 切换横竖屏
  Future<void> toggle() async {
    if (_isLandscape) {
      await setPortrait();
    } else {
      await setLandscape();
    }
  }

  /// 重置到默认（竖屏）
  Future<void> reset() async {
    await setPortrait();
  }
}
