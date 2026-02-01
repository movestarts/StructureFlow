import 'package:flutter/material.dart';

/// 图表视口控制器
/// 管理K线图表的显示范围、拖动状态、自动跟随等
class ChartViewController extends ChangeNotifier {
  // 状态变量
  double _chartOffsetX = 0.0;        // 横向偏移（单位：K线根数）
  int _visibleStartIndex = 0;        // 屏幕左侧K线索引
  int _visibleEndIndex = 0;          // 屏幕右侧K线索引
  bool _isUserDragging = false;      // 用户是否正在拖动
  bool _autoFollowLatest = true;     // 是否自动跟随最新K线
  
  double _candleWidth = 8.0;
  double _candleGap = 2.0;
  double _scale = 1.0;
  
  int _totalDataLength = 0;
  double _screenWidth = 0;
  
  // Getters
  double get chartOffsetX => _chartOffsetX;
  int get visibleStartIndex => _visibleStartIndex;
  int get visibleEndIndex => _visibleEndIndex;
  bool get isUserDragging => _isUserDragging;
  bool get autoFollowLatest => _autoFollowLatest;
  double get scale => _scale;
  double get candleWidth => _candleWidth * _scale;
  double get step => candleWidth + _candleGap;
  
  /// 初始化图表视口
  /// [screenWidth] 屏幕宽度
  /// [totalLength] 数据总长度
  /// [replayStartIndex] 复盘起点索引
  void initialize(double screenWidth, int totalLength, int replayStartIndex) {
    _screenWidth = screenWidth - 60; // 减去右侧价格轴宽度
    _totalDataLength = totalLength;
    
    // 计算屏幕可容纳的K线数量
    final visibleCount = (_screenWidth / step).floor();
    
    // 复盘起点在最右侧，左侧填满历史
    _visibleEndIndex = replayStartIndex;
    _visibleStartIndex = (_visibleEndIndex - visibleCount + 1).clamp(0, _totalDataLength);
    
    // 初始偏移为0（显示最新）
    _chartOffsetX = 0;
    _autoFollowLatest = true;
    
    notifyListeners();
  }
  
  /// 更新数据长度（回放推进时调用）
  void updateDataLength(int newLength) {
    if (newLength == _totalDataLength) return;
    
    final oldLength = _totalDataLength;
    _totalDataLength = newLength;
    
    // 如果自动跟随且未拖动，则跟随最新
    if (_autoFollowLatest && !_isUserDragging) {
      final increment = newLength - oldLength;
      _visibleEndIndex += increment;
      _visibleStartIndex += increment;
      
      // 确保不超界
      if (_visibleEndIndex > _totalDataLength) {
        _visibleEndIndex = _totalDataLength;
      }
      
      notifyListeners();
    }
  }
  
  /// 处理拖动开始
  void onDragStart() {
    _isUserDragging = true;
    notifyListeners();
  }
  
  /// 处理拖动更新
  /// [deltaX] 拖动增量（像素）
  void onDragUpdate(double deltaX) {
    if (!_isUserDragging) return;
    
    // 向右拖 (+deltaX) = 查看更早历史 = 减小索引
    // 向左拖 (-deltaX) = 回到最新 = 增大索引
    final deltaCount = -deltaX / step;
    
    // 更新结束索引
    final newEndIndex = (_visibleEndIndex + deltaCount).round();
    
    // 计算可见数量
    final visibleCount = (_screenWidth / step).floor();
    
    // 边界检查
    if (newEndIndex >= visibleCount && newEndIndex <= _totalDataLength) {
      _visibleEndIndex = newEndIndex;
      _visibleStartIndex = _visibleEndIndex - visibleCount + 1;
      
      // 判断是否回到最新位置
      if (_visibleEndIndex >= _totalDataLength - 2) {
        _autoFollowLatest = true;
      } else {
        _autoFollowLatest = false;
      }
      
      notifyListeners();
    }
  }
  
  /// 处理拖动结束
  void onDragEnd() {
    _isUserDragging = false;
    notifyListeners();
  }
  
  /// 缩放
  void setScale(double newScale) {
    _scale = newScale.clamp(0.5, 3.0);
    
    // 重新计算可见范围
    final visibleCount = (_screenWidth / step).floor();
    _visibleStartIndex = (_visibleEndIndex - visibleCount + 1).clamp(0, _totalDataLength);
    
    notifyListeners();
  }
  
  /// 跳转到最新
  void jumpToLatest() {
    final visibleCount = (_screenWidth / step).floor();
    _visibleEndIndex = _totalDataLength;
    _visibleStartIndex = (_visibleEndIndex - visibleCount + 1).clamp(0, _totalDataLength);
    _autoFollowLatest = true;
    notifyListeners();
  }
}
