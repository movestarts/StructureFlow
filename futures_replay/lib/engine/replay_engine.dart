import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/kline_model.dart';
import '../models/period.dart';
import '../services/data_service.dart';

class ReplayEngine extends ChangeNotifier {
  final List<KlineModel> _sourceData; // Source data (1m or 5m)
  final Period _viewPeriod;
  
  int _currentIndex = 0;
  int _endIndex = 0;
  bool _isPlaying = false;
  Timer? _timer;
  Duration _tickDuration = const Duration(milliseconds: 500);
  
  // 推进模式：true=按周期推进，false=按源K线推进
  bool _advanceByPeriod = true;
  
  // History stack for Undo
  final List<int> _indexHistory = [];
  
  // Current Display Data
  List<KlineModel> _completedKlines = [];
  KlineModel? _ghostBar;
  List<KlineModel> _displayKlinesCache = const [];
  
  final DataService _dataService = DataService();

  ReplayEngine(this._sourceData, this._viewPeriod, {int startIndex = 0, int? limit}) {
    _currentIndex = startIndex;
    _endIndex = limit != null 
        ? (startIndex + limit).clamp(0, _sourceData.length) 
        : _sourceData.length;
    
    _rebuildData();
  }

  // Getters
  List<KlineModel> get displayKlines => _displayKlinesCache;
  bool get isPlaying => _isPlaying;
  int get currentProgress => _currentIndex;
  int get totalLength => _endIndex;
  bool get canUndo => _indexHistory.isNotEmpty;
  bool get isFinished => _currentIndex >= _endIndex - 1;
  
  // Current Quote is the LATEST state (Ghost Bar if forming, or last completed)
  KlineModel? get currentQuote => _ghostBar ?? (_completedKlines.isNotEmpty ? _completedKlines.last : null);

  int get currentSpeedMs => _tickDuration.inMilliseconds;
  
  Period get viewPeriod => _viewPeriod;
  
  bool get advanceByPeriod => _advanceByPeriod;
  
  void setAdvanceMode(bool byPeriod) {
    _advanceByPeriod = byPeriod;
    notifyListeners();
  }

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

  /// Advances the replay by one source tick (e.g. 1 minute)
  /// This creates the "Ghost" effect where the bar grows.
  void next() {
    if (_currentIndex >= _endIndex - 1) {
      pause();
      return;
    }
    _indexHistory.add(_currentIndex);
    _currentIndex++;
    
    // Incremental update (O(1))
    _processTick(_sourceData[_currentIndex]);
    _refreshDisplayCache();
    
    notifyListeners();
  }

  /// Full Undo (O(N) - but acceptable for user action)
  void undo() {
    if (_indexHistory.isEmpty) return;
    _currentIndex = _indexHistory.removeLast();
    _rebuildData();
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
    _timer = Timer.periodic(_tickDuration, (_) {
      if (_advanceByPeriod) {
        nextBar();
      } else {
        next();
      }
    });
  }

  /// Full Rebuild of the state up to _currentIndex.
  /// Used for Initialization and Undo.
  void _rebuildData() {
    if (_currentIndex >= _sourceData.length) return;
    if (_currentIndex < 0) {
        _completedKlines = [];
        _ghostBar = null;
        _refreshDisplayCache();
        return;
    }

    // Reuse DataService for bulk aggregation
    // We aggregate everything up to current index
    List<KlineModel> subset = _sourceData.sublist(0, _currentIndex + 1);
    List<KlineModel> aggregated = _dataService.aggregate(subset, _viewPeriod);
    
    if (aggregated.isEmpty) {
        _completedKlines = [];
        _ghostBar = null;
        _refreshDisplayCache();
        return;
    }
    
    // The last bar from aggregation is always the "current forming" bar (Ghost Bar)
    // UNLESS the source data exactly ended at a period boundary? 
    // DataService logic: returns all bars.
    // If the last bar is "complete" or "partial", DataService doesn't distinguish.
    // Ideally, for Replay, we treat the last bar as Ghost until we move past it.
    
    // However, DataService.aggregate returns a list. 
    // We need to determine if the last one is "done".
    // Actually, simpler model: Last bar is ALWAYS _ghostBar.
    // Bars before it are _completedKlines.
    
    if (aggregated.isNotEmpty) {
      _completedKlines = aggregated.sublist(0, aggregated.length - 1);
      _ghostBar = aggregated.last;
    } else {
      _completedKlines = [];
      _ghostBar = null;
    }
    _refreshDisplayCache();
  }
  
  /// Incremental Update: Absorbs one new source tick.
  void _processTick(KlineModel tick) {
    if (_ghostBar == null) {
      _ghostBar = tick;
      return;
    }
    
    if (_isSamePeriod(_ghostBar!.time, tick.time, _viewPeriod)) {
      // Merge into ghost bar
      _ghostBar = _ghostBar!.copyWith(
        high: tick.high > _ghostBar!.high ? tick.high : _ghostBar!.high,
        low: tick.low < _ghostBar!.low ? tick.low : _ghostBar!.low,
        close: tick.close,
        volume: _ghostBar!.volume + tick.volume,
      );
    } else {
      // Ghost bar is complete (period changed)
      _completedKlines.add(_ghostBar!);
      // New ghost bar starts with this tick
      _ghostBar = tick;
    }
  }

  void _refreshDisplayCache() {
    if (_ghostBar == null) {
      _displayKlinesCache = List.unmodifiable(_completedKlines);
      return;
    }
    _displayKlinesCache = List.unmodifiable([
      ..._completedKlines,
      _ghostBar!,
    ]);
  }
  
  /// Jump to the next completed bar (skips intra-bar ticks)
  void nextBar() {
    if (_currentIndex >= _endIndex - 1) {
      pause();
      return;
    }
    
    // If we are already on 5m view (assuming source is 5m/1m), nextBar just means next tick
    // But if source is 1m and view is 5m, nextBar should skip to next 5m.
    // Here we use the Ghost Bar logic: Keep advancing until Ghost Bar changes (i.e. is finalized).
    
    _indexHistory.add(_currentIndex);
    
    final currentGhostTime = _ghostBar?.time;
    
    // Advance until we see a NEW ghost bar time
    int attempts = 0;
    while (_currentIndex < _endIndex - 1 && attempts < 200) { // Limit to avoid hang
      _currentIndex++;
      _processTick(_sourceData[_currentIndex]);
      
      if (_ghostBar != null && currentGhostTime != null && !_ghostBar!.time.isAtSameMomentAs(currentGhostTime)) {
        break; 
      }
      attempts++;
    }
    
    _refreshDisplayCache();
    notifyListeners();
  }
  
  /// Duplicate logic from DataService to avoid dependency loop or complexity
  bool _isSamePeriod(DateTime start, DateTime current, Period p) {
  final periodMinutes = p.minutes;
  
  // Normalize to start of minute to avoid second/milli issues
  final normalizedStart = DateTime(start.year, start.month, start.day, start.hour, start.minute);
  final normalizedCurrent = DateTime(current.year, current.month, current.day, current.hour, current.minute);
  
  final startTotalMinutes = normalizedStart.millisecondsSinceEpoch ~/ (60 * 1000);
  final currentTotalMinutes = normalizedCurrent.millisecondsSinceEpoch ~/ (60 * 1000);
  
  final startBucket = startTotalMinutes ~/ periodMinutes;
  final currentBucket = currentTotalMinutes ~/ periodMinutes;
  
  return startBucket == currentBucket;
}
  
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
