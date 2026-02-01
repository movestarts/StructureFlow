import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/kline_model.dart';
import '../models/period.dart';
import '../services/data_service.dart';

class ReplayEngine extends ChangeNotifier {
  final List<KlineModel> _all5mBytes; // Source data
  final Period _viewPeriod; // Current Chart Period (e.g. 60m)
  
  int _currentIndex = 0; // Index in _all5mBytes
  int _endIndex = 0; // Where to stop
  bool _isPlaying = false;
  Timer? _timer;
  Duration _tickDuration = const Duration(milliseconds: 500); // Default speed
  
  // Current Display Data
  List<KlineModel> _displayKlines = [];
  KlineModel? _ghostBar; // The forming bar
  
  final DataService _dataService = DataService();

  ReplayEngine(this._all5mBytes, this._viewPeriod, {int startIndex = 0, int? limit}) {
    _currentIndex = startIndex;
    _endIndex = limit != null 
        ? (startIndex + limit).clamp(0, _all5mBytes.length) 
        : _all5mBytes.length;
    
    // Initial Build
    _updateDisplayData();
  }

  // Getters
  List<KlineModel> get displayKlines => [..._displayKlines, if (_ghostBar != null) _ghostBar!];
  bool get isPlaying => _isPlaying;
  int get currentProgress => _currentIndex;
  int get totalLength => _endIndex;
  KlineModel? get currentQuote => _ghostBar ?? (_displayKlines.isNotEmpty ? _displayKlines.last : null);

  int get currentSpeedMs => _tickDuration.inMilliseconds;

  void play() {
    if (_isPlaying) return;
    _isPlaying = true;
    notifyListeners();
    _startTimer();
  }

  void pause() {
    _isPlaying = false;
    _timer?.cancel();
    notifyListeners();
  }

  void next() {
    if (_currentIndex >= _endIndex - 1) {
      pause();
      return;
    }
    _currentIndex++;
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

  /// Simple, reliable update - re-aggregate every time
  void _updateDisplayData() {
    if (_currentIndex >= _all5mBytes.length) return;

    // Get all data from start to current
    List<KlineModel> subset = _all5mBytes.sublist(0, _currentIndex + 1);
    
    // Aggregate based on period
    List<KlineModel> aggregated = _dataService.aggregate(subset, _viewPeriod);
    
    if (aggregated.isEmpty) return;
    
    // Last bar is always the "ghost bar" (forming)
    if (aggregated.length > 1) {
      _displayKlines = aggregated.sublist(0, aggregated.length - 1);
      _ghostBar = aggregated.last;
    } else {
      _displayKlines = [];
      _ghostBar = aggregated.first;
    }
  }
  
  /// Jump to next completed K-line (skip to period boundary)
  void nextBar() {
    if (_currentIndex >= _endIndex - 1) {
      pause();
      return;
    }
    
    // For 5m period, just go next
    if (_viewPeriod == Period.m5) {
      next();
      return;
    }
    
    // Save current ghost bar start time
    final currentGhostTime = _ghostBar?.time;
    if (currentGhostTime == null) {
      next();
      return;
    }
    
    // Keep advancing until we get a new ghost bar with different time
    int attempts = 0;
    while (_currentIndex < _endIndex - 1 && attempts < 100) {
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
}
