import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/kline_model.dart';
import '../models/period.dart';
import '../services/data_service.dart';

class ReplayEngine extends ChangeNotifier {
  final List<KlineModel> _all5mBytes; // Source data
  final Period _viewPeriod;
  
  int _currentIndex = 0;
  int _endIndex = 0;
  bool _isPlaying = false;
  Timer? _timer;
  Duration _tickDuration = const Duration(milliseconds: 500);
  
  // 历史索引栈 (用于回退)
  final List<int> _indexHistory = [];
  
  // Current Display Data
  List<KlineModel> _displayKlines = [];
  KlineModel? _ghostBar;
  
  final DataService _dataService = DataService();

  ReplayEngine(this._all5mBytes, this._viewPeriod, {int startIndex = 0, int? limit}) {
    _currentIndex = startIndex;
    _endIndex = limit != null 
        ? (startIndex + limit).clamp(0, _all5mBytes.length) 
        : _all5mBytes.length;
    
    _updateDisplayData();
  }

  // Getters
  List<KlineModel> get displayKlines => [..._displayKlines, if (_ghostBar != null) _ghostBar!];
  bool get isPlaying => _isPlaying;
  int get currentProgress => _currentIndex;
  int get totalLength => _endIndex;
  bool get canUndo => _indexHistory.isNotEmpty;
  bool get isFinished => _currentIndex >= _endIndex - 1;
  
  KlineModel? get currentQuote => _ghostBar ?? (_displayKlines.isNotEmpty ? _displayKlines.last : null);

  int get currentSpeedMs => _tickDuration.inMilliseconds;
  
  Period get viewPeriod => _viewPeriod;

  void play() {
    if (_isPlaying || isFinished) return;
    _isPlaying = true;
    notifyListeners();
    _startTimer();
  }

  void pause() {
    _isPlaying = false;
    _timer?.cancel();
    notifyListeners();
  }

  void togglePlayPause() {
    if (_isPlaying) {
      pause();
    } else {
      play();
    }
  }

  void next() {
    if (_currentIndex >= _endIndex - 1) {
      pause();
      return;
    }
    _indexHistory.add(_currentIndex);
    _currentIndex++;
    _updateDisplayData();
    notifyListeners();
  }

  /// 回退一步
  void undo() {
    if (_indexHistory.isEmpty) return;
    _currentIndex = _indexHistory.removeLast();
    _updateDisplayData();
    notifyListeners();
  }

  void setSpeed(Duration d) {
    _tickDuration = d;
    if (_isPlaying) {
      _timer?.cancel();
      _startTimer();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(_tickDuration, (_) => next());
  }

  void _updateDisplayData() {
    if (_currentIndex >= _all5mBytes.length) return;

    List<KlineModel> subset = _all5mBytes.sublist(0, _currentIndex + 1);
    List<KlineModel> aggregated = _dataService.aggregate(subset, _viewPeriod);
    
    if (aggregated.isEmpty) return;
    
    if (aggregated.length > 1) {
      _displayKlines = aggregated.sublist(0, aggregated.length - 1);
      _ghostBar = aggregated.last;
    } else {
      _displayKlines = [];
      _ghostBar = aggregated.first;
    }
  }
  
  /// 跳到下一根完整K线
  void nextBar() {
    if (_currentIndex >= _endIndex - 1) {
      pause();
      return;
    }
    
    if (_viewPeriod == Period.m5) {
      next();
      return;
    }
    
    _indexHistory.add(_currentIndex);
    
    final currentGhostTime = _ghostBar?.time;
    if (currentGhostTime == null) {
      next();
      return;
    }
    
    int attempts = 0;
    while (_currentIndex < _endIndex - 1 && attempts < 200) {
      _currentIndex++;
      _updateDisplayData();
      
      if (_ghostBar != null && _ghostBar!.time != currentGhostTime) {
        notifyListeners();
        return;
      }
      attempts++;
    }
    
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
