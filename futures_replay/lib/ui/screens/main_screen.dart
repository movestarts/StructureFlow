import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/kline_model.dart';
import '../../models/period.dart';
import '../../engine/replay_engine.dart';
import '../../engine/trade_engine.dart';
import '../../services/indicator_service.dart';
import '../chart/kline_painter.dart';
import '../chart/macd_painter.dart';
import '../chart/volume_painter.dart';
import '../chart/sub_chart_painter.dart';
import '../chart/chart_view_controller.dart';
import '../theme/app_theme.dart';
import '../../models/trade_model.dart';
import '../../models/trade_record.dart';
import '../../models/ai_review_record.dart';
import '../../services/account_service.dart';
import '../../services/ai_review_service.dart';
import '../../services/database_service.dart';
import '../../services/settings_service.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import '../widgets/order_panel.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// 副图指标类型
enum SubIndicatorType { vol, macd, kdj, rsi, wr, adx }

class MainScreen extends StatefulWidget {
  final List<KlineModel> allData;
  final int startIndex;
  final int? limit;
  final String instrumentCode;
  final Period initialPeriod;
  final bool spotOnly;
  final String? csvPath;  // 原始CSV路径
  /// 是否在进入时即切换为横屏（来自配置页的「显示模式」）
  final bool initialLandscape;

  const MainScreen({
    super.key,
    required this.allData,
    required this.startIndex,
    this.limit,
    this.instrumentCode = 'RB',
    this.initialPeriod = Period.m5,
    this.spotOnly = false,
    this.csvPath,
    this.initialLandscape = false,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late ReplayEngine _replayEngine;
  late TradeEngine _tradeEngine;
  late ChartViewController _chartController;
  final IndicatorService _indicatorService = IndicatorService();

  Period _currentPeriod = Period.m5;
  bool _isInitialized = false;
  final GlobalKey _reviewCaptureKey = GlobalKey();
  final AiReviewService _aiReviewService = AiReviewService();
  final DatabaseService _databaseService = DatabaseService();
  bool _isReviewing = false;
  bool _requestedLandscape = false; // 用户请求的方向（仅控制按钮图标）
  
  // K线推进模式：true=按周期推进，false=按源K线推进
  bool _advanceByPeriod = true;
  
  // CZSC更新计数器（每5帧更新一次，避免频繁计算）
  int _czscUpdateCounter = 0;

  // 主图指标
  MainIndicatorType _mainIndicator = MainIndicatorType.boll;

  // 副图指标
  SubIndicatorType _subIndicator = SubIndicatorType.vol;

  // 指标数据缓存
  List<double?> _ma5 = [];
  List<double?> _ma10 = [];
  List<double?> _ma20 = [];
  BOLLResult _bollData = BOLLResult(upper: [], middle: [], lower: []);
  CZSCResult _czscData = CZSCResult(biList: [], zsList: [], fxList: []);
  MACDResult _macdData = MACDResult(dif: [], dea: [], macdBar: []);
  KDJResult _kdjData = KDJResult(k: [], d: [], j: []);
  List<double?> _rsiData = [];
  List<double?> _wrData = [];
  ADXResult _adxData = ADXResult(adx: [], pdi: [], mdi: []);
  List<double?> _volMa5 = [];
  List<double?> _volMa10 = [];

  @override
  void initState() {
    super.initState();
    _currentPeriod = widget.initialPeriod;
    _replayEngine = ReplayEngine(widget.allData, _currentPeriod, startIndex: widget.startIndex, limit: widget.limit);
    _replayEngine.setAdvanceMode(_advanceByPeriod); // 设置推进模式
    _tradeEngine = TradeEngine();
    _chartController = ChartViewController();

    _replayEngine.addListener(_onReplayUpdate);
    _updateIndicators();

    // 配置页选择了横屏时，进入训练页立即切换为横屏
    if (widget.initialLandscape) {
      _requestedLandscape = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
      });
    }
  }

  @override
  void dispose() {
    _submitResults();
    _replayEngine.removeListener(_onReplayUpdate);
    _replayEngine.dispose();
    _chartController.dispose();
    // 退出时重置屏幕方向和系统UI
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }
  
  /// 切换横竖屏 — 只请求系统旋转，布局由实际屏幕方向驱动
  void _toggleOrientation() {
    final goLandscape = !_requestedLandscape;
    _requestedLandscape = goLandscape;
    if (goLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  /// 提交本次训练结果到全局账户
  void _submitResults() {
    final closedTrades = _tradeEngine.closedTrades;
    if (closedTrades.isEmpty) return;

    final sessionPnL = _tradeEngine.balance - 1000000; // 初始资金100万
    final sessionTradeCount = closedTrades.length;
    final sessionWinCount = closedTrades.where((t) => t.realizedPnL > 0).length;

    try {
      final accountService = context.read<AccountService>();
      accountService.submitSessionResult(
        sessionPnL: sessionPnL,
        sessionTradeCount: sessionTradeCount,
        sessionWinCount: sessionWinCount,
      );

      // 捕获此会话的完整数据用于缓存（以便回看时能看到后续走势）
      final sessionData = widget.allData; 
      
      // 异步缓存K线数据并持久化交易记录
      // 注意：这里传入的是全量数据，而不是 replayEngine.displayKlines，确保回看时有完整数据
      _cacheKlineAndSaveTrades(accountService, closedTrades, sessionData);
    } catch (_) {
      // context may not be available in dispose
    }
  }

  /// 缓存K线数据到本地文件并保存交易记录
  Future<void> _cacheKlineAndSaveTrades(
    AccountService accountService,
    List<Trade> closedTrades,
    List<KlineModel> klinesToCache,
  ) async {
    String? cachedPath;

    try {
      // 获取缓存目录
      final dir = await getApplicationSupportDirectory();
      final cacheDir = Directory('${dir.path}/kline_cache');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      // 将K线数据保存为CSV
    if (klinesToCache.isNotEmpty) {
      final now = DateTime.now();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(now);
      // Sanitize instrument code to remove invalid filename characters
      final safeCode = widget.instrumentCode.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final fileName = '${safeCode}_$timestamp.csv';
      final file = File('${cacheDir.path}/$fileName');

      final buffer = StringBuffer();
        // 写入CSV头部（可选，但为了解析方便还是保持无头或标准头，这里保持无头与解析逻辑一致）
        // 格式: 2023-10-27 09:00:00,open,high,low,close,volume
        for (final k in klinesToCache) {
          buffer.writeln(
            '${DateFormat('yyyy-MM-dd HH:mm:ss').format(k.time)},'
            '${k.open},${k.high},${k.low},${k.close},${k.volume}',
          );
        }
        await file.writeAsString(buffer.toString());
        cachedPath = file.path;
      }
    } catch (e) {
      debugPrint('缓存K线数据失败: $e');
    }

    // 保存交易记录
    final now = DateTime.now();
    
    final records = closedTrades.map((t) => TradeRecord(
      id: t.id,
      instrumentCode: widget.instrumentCode,
      direction: t.direction == Direction.long ? 'long' : 'short',
      type: widget.spotOnly ? 'spot' : 'futures',
      entryPrice: t.entryPrice,
      closePrice: t.closePrice!,
      quantity: t.quantity,
      leverage: t.leverage,
      pnl: t.realizedPnL,
      fee: 0,
      entryTime: t.entryTime,
      closeTime: t.closeTime!,
      trainingTime: now,
      csvPath: cachedPath ?? widget.csvPath,
      startIndex: 0,
      visibleBars: null,
      period: _currentPeriod.code,
    )).toList();
    accountService.addTradeRecords(records);
  }

  void _onReplayUpdate() {
    if (_isInitialized) {
      _chartController.updateDataLength(_replayEngine.displayKlines.length);
      
      // CZSC优化策略：
      // 1. 如果未选择CZSC指标，始终跳过
      // 2. 如果正在播放，每5帧更新一次（降低计算频率）
      // 3. 如果暂停状态，每次都更新（实时响应）
      bool shouldSkipCzsc = true;
      
      if (_mainIndicator == MainIndicatorType.czsc) {
        if (_replayEngine.isPlaying) {
          _czscUpdateCounter++;
          shouldSkipCzsc = (_czscUpdateCounter % 5 != 0);
        } else {
          // 暂停时实时更新
          shouldSkipCzsc = false;
          _czscUpdateCounter = 0; // 重置计数器
        }
      }
      
      _updateIndicators(skipCzsc: shouldSkipCzsc);
    }
  }

  void _updateIndicators({bool skipCzsc = false}) {
    final data = _replayEngine.displayKlines;
    if (data.isEmpty) return;

    setState(() {
      if (_mainIndicator == MainIndicatorType.ma || _mainIndicator == MainIndicatorType.ema) {
        _ma5 = _indicatorService.calculateMA(data, 5);
        _ma10 = _indicatorService.calculateMA(data, 10);
        _ma20 = _indicatorService.calculateMA(data, 20);
      }
      if (_mainIndicator == MainIndicatorType.boll) {
        _bollData = _indicatorService.calculateBOLL(data);
      }
      // CZSC计算较慢，在播放过程中跳过，只在切换指标时计算
      if (_mainIndicator == MainIndicatorType.czsc && !skipCzsc) {
        _czscData = _indicatorService.calculateCZSC(data, widget.instrumentCode);
      }

      switch (_subIndicator) {
        case SubIndicatorType.vol:
          _volMa5 = _indicatorService.calculateVolumeMA(data, 5);
          _volMa10 = _indicatorService.calculateVolumeMA(data, 10);
          break;
        case SubIndicatorType.macd:
          _macdData = _indicatorService.calculateMACD(data);
          break;
        case SubIndicatorType.kdj:
          _kdjData = _indicatorService.calculateKDJ(data);
          break;
        case SubIndicatorType.rsi:
          _rsiData = _indicatorService.calculateRSI(data);
          break;
        case SubIndicatorType.wr:
          _wrData = _indicatorService.calculateWR(data);
          break;
        case SubIndicatorType.adx:
          _adxData = _indicatorService.calculateADX(data);
          break;
      }
    });
  }

  void _setMainIndicator(MainIndicatorType indicator) {
    if (_mainIndicator == indicator) return;
    setState(() {
      _mainIndicator = indicator;
      _czscUpdateCounter = 0; // 重置计数器，确保切换到CZSC时立即计算
    });
    _updateIndicators(); // 立即更新所有指标
  }

  void _setSubIndicator(SubIndicatorType indicator) {
    if (_subIndicator == indicator) return;
    setState(() {
      _subIndicator = indicator;
    });
    _updateIndicators();
  }

  void _switchPeriod(Period p) {
    if (p == _currentPeriod) return;
    int currentIdx = _replayEngine.currentProgress;
    _replayEngine.removeListener(_onReplayUpdate);
    _replayEngine.dispose();

    setState(() {
      _currentPeriod = p;
      _replayEngine = ReplayEngine(widget.allData, _currentPeriod, startIndex: currentIdx, limit: widget.limit);
      _replayEngine.setAdvanceMode(_advanceByPeriod); // 保持推进模式设置
      _replayEngine.addListener(_onReplayUpdate);
      _isInitialized = false;
      _czscUpdateCounter = 0; // 重置CZSC计数器
      
      // 清空所有指标数据，避免旧周期数据影响新周期
      _ma5 = [];
      _ma10 = [];
      _ma20 = [];
      _bollData = BOLLResult(upper: [], middle: [], lower: []);
      _czscData = CZSCResult(biList: [], zsList: [], fxList: []);
      _macdData = MACDResult(dif: [], dea: [], macdBar: []);
      _kdjData = KDJResult(k: [], d: [], j: []);
      _rsiData = [];
      _wrData = [];
      _adxData = ADXResult(adx: [], pdi: [], mdi: []);
      _volMa5 = [];
      _volMa10 = [];
      
      _updateIndicators();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _replayEngine),
        ChangeNotifierProvider.value(value: _tradeEngine),
        ChangeNotifierProvider.value(value: _chartController),
      ],
      child: Scaffold(
        backgroundColor: AppColors.bgDark,
        body: Builder(
          builder: (ctx) {
            // 获取系统安全区域（包含刘海、圆角等）
            final systemPadding = MediaQuery.of(ctx).padding;
            // 横屏时：系统安全区 + 额外24px缓冲，确保R角不遮挡
            final landscapePadding = EdgeInsets.only(
              left: max(systemPadding.left, 16) + 8,
              right: max(systemPadding.right, 16) + 8,
              top: 4,
              bottom: 2,
            );
            return Padding(
              padding: isLandscape ? landscapePadding : EdgeInsets.only(
                top: systemPadding.top,
                bottom: systemPadding.bottom,
              ),
              child: RepaintBoundary(
              key: _reviewCaptureKey,
              child: Column(
              children: [
                // 顶部状态栏
                _buildTopBar(),
                // 主图
                Expanded(flex: isLandscape ? 7 : 6, child: _buildMainChart()),
                // 时间轴
                _buildTimeAxis(),
                // 副图
                Expanded(flex: isLandscape ? 1 : 1, child: _buildSubChart()),
                // 指标切换栏
                _buildIndicatorTabs(),
                // 底部操作面板
                if (isLandscape)
                  _buildLandscapeActionBar()
                else
                  _buildActionBar(),
              ],
              ),
            ),
          );
          },
        ),
      ),
    );
  }

  // ===== 顶部状态栏 =====
  Widget _buildTopBar() {
    return Consumer<ReplayEngine>(
      builder: (ctx, replay, _) {
        final quote = replay.currentQuote;
        final price = quote?.close ?? 0;
        final open = quote?.open ?? 0;
        final high = quote?.high ?? 0;
        final low = quote?.low ?? 0;
        final vol = quote?.volume ?? 0;
        final change = open != 0 ? ((price - open) / open * 100) : 0.0;
        final isUp = price >= open;
        
        final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
        final isMobile = MediaQuery.of(context).size.shortestSide < 600;

        return Container(
          color: AppColors.bgDark,
          padding: EdgeInsets.symmetric(
            horizontal: isLandscape ? 4 : (isMobile ? 8 : 12), 
            vertical: isLandscape ? 4 : (isMobile ? 6 : 6)
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 主行
              Row(
                children: [
                  // 返回
                  GestureDetector(
                    onTap: () {
                      _submitResults();
                      Navigator.pop(context);
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: isLandscape ? 4 : 0),
                      child: Icon(Icons.chevron_left, 
                        color: AppColors.textPrimary, 
                        size: isLandscape ? 20 : (isMobile ? 22 : 22)
                      ),
                    ),
                  ),
                  if (!isLandscape && !isMobile) ...[
                    const SizedBox(width: 2),
                    const Text('K线训练营', 
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 14)
                    ),
                  ],
                  SizedBox(width: isLandscape ? 4 : (isMobile ? 6 : 12)),

                  // 品种名
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isLandscape ? 5 : (isMobile ? 4 : 6), 
                      vertical: isLandscape ? 2 : 1
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      widget.instrumentCode,
                      style: TextStyle(
                        color: AppColors.primary, 
                        fontSize: isLandscape ? 12 : (isMobile ? 12 : 13), 
                        fontWeight: FontWeight.bold
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '最新价:',
                    style: TextStyle(
                      color: AppColors.textMuted, 
                      fontSize: isLandscape ? 11 : (isMobile ? 11 : 12)
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    price.toStringAsFixed(1),
                    style: TextStyle(
                      color: isUp ? AppColors.bullish : AppColors.bearish,
                      fontSize: isLandscape ? 13 : (isMobile ? 14 : 15),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${change >= 0 ? "+" : ""}${change.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: isUp ? AppColors.bullish : AppColors.bearish,
                      fontSize: isLandscape ? 11 : (isMobile ? 11 : 12),
                    ),
                  ),
                  
                  // 横屏时在顶栏显示高低量
                  if (isLandscape) ...[
                    const SizedBox(width: 10),
                    _buildQuoteItem('高', high, isUp, true),
                    const SizedBox(width: 8),
                    _buildQuoteItem('低', low, isUp, true),
                    const SizedBox(width: 8),
                    _buildQuoteItem('量', vol, null, true, isVolume: true),
                  ],

                  const Spacer(),

                  // 右侧菜单：可横向滑动
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ..._buildPeriodTabs(),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: _toggleOrientation,
                            child: Container(
                              padding: EdgeInsets.all(isLandscape ? 4 : (isMobile ? 4 : 3)),
                              decoration: BoxDecoration(
                                color: AppColors.bgSurface,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(
                                _requestedLandscape ? Icons.screen_lock_portrait : Icons.screen_lock_landscape,
                                color: AppColors.textMuted,
                                size: isLandscape ? 16 : (isMobile ? 16 : 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: _isReviewing ? null : _showAiReviewPromptDialog,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isLandscape ? 6 : (isMobile ? 6 : 6),
                                vertical: isLandscape ? 3 : (isMobile ? 4 : 3),
                              ),
                              decoration: BoxDecoration(
                                color: _isReviewing
                                    ? AppColors.textMuted.withOpacity(0.2)
                                    : AppColors.primary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _isReviewing ? 'AI...' : 'AI',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: isLandscape ? 11 : (isMobile ? 10 : 11),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => _showSpeedDialog(),
                            child: Padding(
                              padding: EdgeInsets.all(isLandscape ? 4 : (isMobile ? 4 : 0)),
                              child: Icon(Icons.settings, 
                                color: AppColors.textMuted, 
                                size: isLandscape ? 18 : (isMobile ? 16 : 18)
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => replay.togglePlayPause(),
                            child: Container(
                              padding: EdgeInsets.all(isLandscape ? 5 : (isMobile ? 5 : 4)),
                              decoration: BoxDecoration(
                                color: replay.isPlaying ? AppColors.bullish : AppColors.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(
                                replay.isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                                size: isLandscape ? 16 : (isMobile ? 14 : 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // 竖屏时显示第二行：高低量
              if (!isLandscape) ...[
                SizedBox(height: isMobile ? 2 : 4),
                Row(
                  children: [
                    const Spacer(),
                    _buildQuoteItem('高', high, isUp, isMobile),
                    SizedBox(width: isMobile ? 6 : 12),
                    _buildQuoteItem('低', low, isUp, isMobile),
                    SizedBox(width: isMobile ? 6 : 12),
                    _buildQuoteItem('量', vol, null, isMobile, isVolume: true),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuoteItem(String label, double value, bool? isUp, bool isMobile, {bool isVolume = false}) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    String text = isVolume ? _formatVolume(value) : value.toStringAsFixed(1);
    return Text(
      '$label:$text',
      style: TextStyle(
        color: isUp == null ? AppColors.textSecondary : (isUp ? AppColors.bullish : AppColors.bearish),
        fontSize: isLandscape ? 10 : (isMobile ? 9 : 11),
      ),
    );
  }

  List<Widget> _buildPeriodTabs() {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final isMobile = MediaQuery.of(context).size.shortestSide < 600;
    final periods = [Period.m5, Period.m15, Period.m30, Period.h1];
    return periods.map((p) {
      final isSelected = _currentPeriod == p;
      return GestureDetector(
        onTap: () => _switchPeriod(p),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isLandscape ? 6 : (isMobile ? 7 : 8), 
            vertical: isLandscape ? 3 : (isMobile ? 4 : 3)
          ),
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.warning : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            p.code,
            style: TextStyle(
              color: isSelected ? Colors.black : AppColors.textMuted,
              fontSize: isLandscape ? 11 : (isMobile ? 11 : 12),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      );
    }).toList();
  }

  // ===== 主图 =====
  Widget _buildMainChart() {
    return Consumer3<ReplayEngine, TradeEngine, ChartViewController>(
      builder: (context, replay, trade, chartCtrl, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            if (!_isInitialized && replay.displayKlines.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _chartController.initialize(
                  constraints.maxWidth,
                  replay.displayKlines.length,
                  replay.displayKlines.length, // Fix: Use length to include the last item (sublist end is exclusive)
                );
                setState(() => _isInitialized = true);
              });
            }

            return Listener(
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  // 鼠标滚轮事件
                  // scrollDelta.dy > 0 = 向下滚 = 缩小
                  // scrollDelta.dy < 0 = 向上滚 = 放大
                  final delta = event.scrollDelta.dy;
                  final zoomFactor = delta > 0 ? 0.9 : 1.1; // 每次缩放10%
                  _chartController.setScale(chartCtrl.scale * zoomFactor);
                }
              },
              child: GestureDetector(
                onHorizontalDragStart: (_) => _chartController.onDragStart(),
                onHorizontalDragUpdate: (d) {
                  if (chartCtrl.isUserDragging) {
                    _chartController.onDragUpdate(d.delta.dx);
                  }
                },
                onHorizontalDragEnd: (_) => _chartController.onDragEnd(),
                onScaleUpdate: (details) {
                  if (details.scale != 1.0) {
                    _chartController.setScale(chartCtrl.scale * details.scale);
                  }
                },
                child: Container(
                  color: AppColors.bgOverlay,
                  width: double.infinity,
                  child: _isInitialized
                      ? CustomPaint(
                          painter: KlinePainter(
                            allData: replay.displayKlines,
                            allTrades: trade.allTrades,
                            viewController: chartCtrl,
                            currentPrice: replay.currentQuote?.close ?? 0,
                            ma5: _ma5,
                            ma10: _ma10,
                            ma20: _ma20,
                            bollData: _bollData,
                            czscData: _czscData,
                            mainIndicator: _mainIndicator,
                          ),
                        )
                      : const Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ===== 副图 =====
  Widget _buildSubChart() {
    return Consumer<ChartViewController>(
      builder: (context, chartCtrl, _) {
        if (!_isInitialized) return const SizedBox();
        final dataLen = _replayEngine.displayKlines.length;

        return Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: AppColors.bgOverlay,
            border: Border(
              top: BorderSide(color: AppColors.border, width: 0.5),
            ),
          ),
          child: CustomPaint(
            painter: _buildSubChartPainter(chartCtrl, dataLen),
          ),
        );
      },
    );
  }

  CustomPainter _buildSubChartPainter(ChartViewController chartCtrl, int dataLen) {
    switch (_subIndicator) {
      case SubIndicatorType.vol:
        return VolumePainter(
          allData: _replayEngine.displayKlines,
          viewController: chartCtrl,
          volMa5: _volMa5,
          volMa10: _volMa10,
        );
      case SubIndicatorType.macd:
        return MACDPainter(
          macdData: _macdData,
          viewController: chartCtrl,
          dataLength: dataLen,
        );
      case SubIndicatorType.kdj:
        return createKDJPainter(
          kdjData: _kdjData,
          viewController: chartCtrl,
          dataLength: dataLen,
        );
      case SubIndicatorType.rsi:
        return createRSIPainter(
          rsiData: _rsiData,
          viewController: chartCtrl,
          dataLength: dataLen,
        );
      case SubIndicatorType.wr:
        return createWRPainter(
          wrData: _wrData,
          viewController: chartCtrl,
          dataLength: dataLen,
        );
      case SubIndicatorType.adx:
        return createADXPainter(
          adxData: _adxData,
          viewController: chartCtrl,
          dataLength: dataLen,
        );
    }
  }

  // ===== 时间轴 =====
  Widget _buildTimeAxis() {
    return Consumer2<ReplayEngine, ChartViewController>(
      builder: (ctx, replay, chartCtrl, _) {
        final klines = replay.displayKlines;
        final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
        if (klines.isEmpty) return SizedBox(height: isLandscape ? 12 : 16);

        final dataLen = klines.length;
        int startIdx = chartCtrl.visibleStartIndex.clamp(0, dataLen);
        int endIdx = chartCtrl.visibleEndIndex.clamp(0, dataLen);
        if (startIdx >= endIdx) {
          startIdx = 0;
          endIdx = dataLen;
        }
        final visibleCount = endIdx - startIdx;

        final width = MediaQuery.of(context).size.width;
        final tickCount = width < 360 ? 3 : (width < 600 ? 4 : 6);
        final fmt = DateFormat('MM-dd HH:mm');
        final labels = List<String>.generate(tickCount, (i) {
          if (visibleCount <= 1) return fmt.format(klines[startIdx].time);
          final t = i / (tickCount - 1);
          final idx = (startIdx + (t * (visibleCount - 1)).round())
              .clamp(startIdx, endIdx - 1);
          return fmt.format(klines[idx].time);
        });

        return Container(
          height: isLandscape ? 16 : 20,
          color: AppColors.bgOverlay,
          padding: EdgeInsets.symmetric(horizontal: isLandscape ? 8 : 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: labels
                .map(
                  (text) => Text(
                    text,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: isLandscape ? 9 : 10,
                    ),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }

  // ===== 指标切换栏 =====
  Widget _buildIndicatorTabs() {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final isMobile = MediaQuery.of(context).size.shortestSide < 600;
    return Container(
      height: isLandscape ? 28 : (isMobile ? 26 : 34),
      color: AppColors.bgDark,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: isLandscape ? 4 : (isMobile ? 4 : 8)),
        child: Row(
          children: [
            _buildIndicatorTab('分时', false, () {}),
            _buildIndicatorTab('MA', _mainIndicator == MainIndicatorType.ma, () => _setMainIndicator(MainIndicatorType.ma)),
            _buildIndicatorTab('EMA', _mainIndicator == MainIndicatorType.ema, () => _setMainIndicator(MainIndicatorType.ema)),
            _buildIndicatorTab('BOLL', _mainIndicator == MainIndicatorType.boll, () => _setMainIndicator(MainIndicatorType.boll)),
            _buildIndicatorTab('CZSC', _mainIndicator == MainIndicatorType.czsc, () => _setMainIndicator(MainIndicatorType.czsc)),
            Container(
              width: 1, 
              height: isLandscape ? 14 : (isMobile ? 12 : 16), 
              color: AppColors.borderLight, 
              margin: EdgeInsets.symmetric(horizontal: isLandscape ? 3 : (isMobile ? 3 : 6))
            ),
            _buildIndicatorTab('VOL', _subIndicator == SubIndicatorType.vol, () => _setSubIndicator(SubIndicatorType.vol)),
            _buildIndicatorTab('MACD', _subIndicator == SubIndicatorType.macd, () => _setSubIndicator(SubIndicatorType.macd)),
            _buildIndicatorTab('KDJ', _subIndicator == SubIndicatorType.kdj, () => _setSubIndicator(SubIndicatorType.kdj)),
            _buildIndicatorTab('RSI', _subIndicator == SubIndicatorType.rsi, () => _setSubIndicator(SubIndicatorType.rsi)),
            _buildIndicatorTab('WR', _subIndicator == SubIndicatorType.wr, () => _setSubIndicator(SubIndicatorType.wr)),
            _buildIndicatorTab('ADX', _subIndicator == SubIndicatorType.adx, () => _setSubIndicator(SubIndicatorType.adx)),
            SizedBox(width: isLandscape ? 4 : (isMobile ? 4 : 8)),
            GestureDetector(
              onTap: () => _showSpeedDialog(),
              child: Icon(Icons.tune, 
                color: AppColors.textMuted, 
                size: isLandscape ? 16 : (isMobile ? 14 : 18)
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicatorTab(String label, bool isActive, VoidCallback onTap) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final isMobile = MediaQuery.of(context).size.shortestSide < 600;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isLandscape ? 6 : (isMobile ? 6 : 10), 
          vertical: isLandscape ? 4 : (isMobile ? 3 : 6)
        ),
        margin: EdgeInsets.symmetric(horizontal: isLandscape ? 1 : (isMobile ? 1 : 2)),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? AppColors.warning : AppColors.textMuted,
            fontSize: isLandscape ? 11 : (isMobile ? 10 : 13),
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ===== 底部操作面板 =====
  Widget _buildActionBar() {
    return Consumer2<ReplayEngine, TradeEngine>(
      builder: (ctx, replay, trade, _) {
        final price = replay.currentQuote?.close ?? 0;
        final time = replay.currentQuote?.time ?? DateTime.now();
        final floatingPnL = trade.calculateFloatingPnL(price);
        final totalEquity = trade.balance + floatingPnL;
        final hasPosition = trade.activePositions.isNotEmpty;
        final closedTrades = trade.closedTrades;
        final winCount = closedTrades.where((t) => t.realizedPnL > 0).length;
        final winRate = closedTrades.isEmpty ? 0.0 : (winCount / closedTrades.length * 100);
        final roi = ((totalEquity - 1000000) / 1000000 * 100);
        final isMobile = MediaQuery.of(context).size.width < 600;

        return Container(
          color: AppColors.bgCard,
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 6 : 12, 
            vertical: isMobile ? 4 : 8
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 数据行
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildDataItem('仓位', hasPosition ? '${trade.activePositions.length}' : '0', isMobile),
                  _buildDataItem('资产总值', totalEquity.toStringAsFixed(2), isMobile, color: totalEquity >= 1000000 ? AppColors.bullish : AppColors.bearish),
                  _buildDataItem('胜率', '${winRate.toStringAsFixed(2)}%', isMobile, color: winRate > 50 ? AppColors.bullish : AppColors.textSecondary),
                  _buildDataItem('收益率', '${roi.toStringAsFixed(2)}%', isMobile, color: roi >= 0 ? AppColors.bullish : AppColors.bearish),
                  _buildDataItem('盈亏', floatingPnL.toStringAsFixed(2), isMobile, color: floatingPnL >= 0 ? AppColors.bullish : AppColors.bearish),
                ],
              ),
              SizedBox(height: isMobile ? 5 : 10),
              // 按钮行
              Row(
                children: [
                  // 做多按钮
                  Expanded(
                    child: _buildTradeButton(
                      '做多',
                      AppColors.bullish,
                      widget.spotOnly || !hasPosition
                          ? () => _showOrderPanel(context, trade, price, time, Direction.long)
                          : null,
                      isMobile,
                    ),
                  ),
                  SizedBox(width: isMobile ? 4 : 8),
                  // 做空按钮 (现货模式隐藏)
                  if (!widget.spotOnly)
                    Expanded(
                      child: _buildTradeButton(
                        '做空',
                        AppColors.bearish,
                        !hasPosition ? () => _showOrderPanel(context, trade, price, time, Direction.short) : null,
                        isMobile,
                      ),
                    ),
                  if (!widget.spotOnly) SizedBox(width: isMobile ? 4 : 8),
                  // 平仓按钮
                  Expanded(
                    child: _buildTradeButton(
                      '平仓',
                      hasPosition ? AppColors.warning : AppColors.textSecondary,
                      hasPosition ? () => trade.closeAll(price, time) : null,
                      isMobile,
                    ),
                  ),
                  SizedBox(width: isMobile ? 4 : 8),
                  // 向上图标（跳到最新）
                  GestureDetector(
                    onTap: () => _chartController.jumpToLatest(),
                    child: Container(
                      padding: EdgeInsets.all(isMobile ? 4 : 6),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(isMobile ? 6 : 8),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Icon(Icons.keyboard_double_arrow_up, 
                        color: AppColors.textMuted, 
                        size: isMobile ? 14 : 18
                      ),
                    ),
                  ),
                  SizedBox(width: isMobile ? 8 : 20),
                  // 回退
                  _buildControlButton(
                    '回退',
                    Icons.undo,
                    replay.canUndo ? () => replay.undo() : null,
                    isMobile,
                  ),
                  SizedBox(width: isMobile ? 4 : 8),
                  // 观望（步进）
                  _buildControlButton(
                    '观望',
                    Icons.skip_next,
                    replay.isFinished ? null : () {
                      if (_advanceByPeriod) {
                        replay.nextBar();
                      } else {
                        replay.next();
                      }
                    },
                    isMobile,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDataItem(String label, String value, bool isMobile, {Color? color}) {
    return Column(
      children: [
        Text(value, style: TextStyle(
          color: color ?? AppColors.textPrimary, 
          fontSize: isMobile ? 10 : 13, 
          fontWeight: FontWeight.bold, 
          fontFamily: 'monospace'
        )),
        SizedBox(height: isMobile ? 1 : 2),
        Text(label, style: TextStyle(
          color: AppColors.textMuted, 
          fontSize: isMobile ? 8 : 10
        )),
      ],
    );
  }

  Widget _buildTradeButton(String label, Color color, VoidCallback? onPressed, bool isMobile, {bool small = false}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: isMobile ? 30 : 38,
        decoration: BoxDecoration(
          color: onPressed != null ? color : color.withOpacity(0.3),
          borderRadius: BorderRadius.circular(isMobile ? 6 : 8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: onPressed != null ? Colors.white : Colors.white38,
              fontSize: isMobile ? 12 : (small ? 13 : 15),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton(String label, IconData icon, VoidCallback? onPressed, bool isMobile) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 14, 
          vertical: isMobile ? 5 : 8
        ),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(isMobile ? 6 : 8),
          border: Border.all(color: onPressed != null ? AppColors.borderLight : AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, 
              color: onPressed != null ? AppColors.textPrimary : AppColors.textMuted, 
              size: isMobile ? 14 : 18
            ),
            SizedBox(height: isMobile ? 1 : 2),
            Text(label, style: TextStyle(
              color: onPressed != null ? AppColors.textPrimary : AppColors.textMuted, 
              fontSize: isMobile ? 8 : 10
            )),
          ],
        ),
      ),
    );
  }

  // ===== 横屏专用底部单行操作面板（参考图二设计） =====
  Widget _buildLandscapeActionBar() {
    return Consumer2<ReplayEngine, TradeEngine>(
      builder: (ctx, replay, trade, _) {
        final price = replay.currentQuote?.close ?? 0;
        final time = replay.currentQuote?.time ?? DateTime.now();
        final floatingPnL = trade.calculateFloatingPnL(price);
        final totalEquity = trade.balance + floatingPnL;
        final hasPosition = trade.activePositions.isNotEmpty;
        final closedTrades = trade.closedTrades;
        final winCount = closedTrades.where((t) => t.realizedPnL > 0).length;
        final winRate = closedTrades.isEmpty ? 0.0 : (winCount / closedTrades.length * 100);
        final roi = ((totalEquity - 1000000) / 1000000 * 100);

        return Container(
          color: AppColors.bgCard,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              // 做多
              _buildLandscapeTradeBtn(
                '做多', AppColors.bullish,
                widget.spotOnly || !hasPosition
                    ? () => _showOrderPanel(context, trade, price, time, Direction.long)
                    : null,
              ),
              const SizedBox(width: 2),
              // 做空
              if (!widget.spotOnly)
                _buildLandscapeTradeBtn(
                  '做空', AppColors.bearish,
                  !hasPosition ? () => _showOrderPanel(context, trade, price, time, Direction.short) : null,
                ),
              if (!widget.spotOnly) const SizedBox(width: 2),
              // 平仓
              _buildLandscapeTradeBtn(
                '平仓',
                hasPosition ? AppColors.warning : AppColors.textSecondary,
                hasPosition ? () => trade.closeAll(price, time) : null,
              ),
              const SizedBox(width: 3),
              // 跳最新
              GestureDetector(
                onTap: () => _chartController.jumpToLatest(),
                child: const Icon(Icons.keyboard_double_arrow_up, color: AppColors.textMuted, size: 14),
              ),
              // 数据项：用Expanded + Row自适应
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildLandscapeDataCell('仓位', hasPosition ? '${trade.activePositions.length}' : '0'),
                    _buildLandscapeDataCell('资产', _formatCompactNum(totalEquity), 
                      color: totalEquity >= 1000000 ? AppColors.bullish : AppColors.bearish),
                    _buildLandscapeDataCell('胜率', '${winRate.toStringAsFixed(1)}%',
                      color: winRate > 50 ? AppColors.bullish : AppColors.textSecondary),
                    _buildLandscapeDataCell('收益', '${roi.toStringAsFixed(1)}%',
                      color: roi >= 0 ? AppColors.bullish : AppColors.bearish),
                    _buildLandscapeDataCell('盈亏', _formatCompactNum(floatingPnL),
                      color: floatingPnL >= 0 ? AppColors.bullish : AppColors.bearish),
                  ],
                ),
              ),
              // 回退
              _buildLandscapeControlBtn(
                Icons.undo,
                replay.canUndo ? () => replay.undo() : null,
              ),
              const SizedBox(width: 3),
              // 观望
              _buildLandscapeControlBtn(
                Icons.skip_next,
                replay.isFinished ? null : () {
                  if (_advanceByPeriod) {
                    replay.nextBar();
                  } else {
                    replay.next();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// 格式化紧凑数字（横屏用）
  String _formatCompactNum(double v) {
    if (v.abs() >= 10000) return '${(v / 10000).toStringAsFixed(1)}万';
    if (v.abs() >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(1);
  }

  Widget _buildLandscapeTradeBtn(String label, Color color, VoidCallback? onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: onPressed != null ? color : color.withOpacity(0.3),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: onPressed != null ? Colors.white : Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLandscapeDataCell(String label, String value, {Color? color}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(value, style: TextStyle(
          color: color ?? AppColors.textPrimary,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        )),
        Text(label, style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 8,
        )),
      ],
    );
  }

  Widget _buildLandscapeControlBtn(IconData icon, VoidCallback? onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: onPressed != null ? AppColors.borderLight : AppColors.border,
            width: 0.5,
          ),
        ),
        child: Icon(icon, 
          color: onPressed != null ? AppColors.textPrimary : AppColors.textMuted, 
          size: 16
        ),
      ),
    );
  }

  Future<void> _showAiReviewPromptDialog() async {
    final controller = TextEditingController(
      text: '请从趋势、入场时机、止盈止损和风险控制角度点评这张复盘图，并给出0-100分。',
    );
    final prompt = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text(
          'AI 交易助理',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: TextField(
          controller: controller,
          maxLines: 4,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: '输入你希望AI重点点评的内容',
            hintStyle: TextStyle(color: AppColors.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('开始点评'),
          ),
        ],
      ),
    );
    if (!mounted || prompt == null || prompt.isEmpty) return;
    await _runAiReview(prompt);
  }

  Future<void> _runAiReview(String prompt) async {
    if (_isReviewing) return;
    setState(() => _isReviewing = true);
    try {
      final imageBase64 = await _captureReviewImageBase64();
      final settings = context.read<SettingsService>();
      final visionProfile = settings.getProfileForTask('image_review');
      final result = await _aiReviewService.reviewChartImage(
        imageBase64: imageBase64,
        userPrompt: prompt,
        apiKey: visionProfile.apiKey,
        endpoint: visionProfile.endpoint,
        model: visionProfile.model,
      );
      await _saveAiReview(prompt: prompt, result: result);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.bgCard,
          title: Row(
            children: [
              const Text(
                'AI 点评结果',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              const Spacer(),
              Text(
                '${result.score}分',
                style: TextStyle(
                  color: result.score >= 70 ? AppColors.bullish : AppColors.warning,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              _buildReviewText(result),
              style: const TextStyle(color: AppColors.textSecondary, height: 1.35),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI点评失败: $e')),
      );
    } finally {
      if (mounted) setState(() => _isReviewing = false);
    }
  }

  Future<void> _saveAiReview({
    required String prompt,
    required AiReviewResult result,
  }) async {
    final now = DateTime.now();
    final closedIds = _tradeEngine.closedTrades.map((e) => e.id).toList();
    final record = AiReviewRecord.fromResult(
      id: _nextAiReviewId(now),
      createdAt: now,
      instrumentCode: widget.instrumentCode,
      period: _currentPeriod.code,
      prompt: prompt,
      result: result,
      tradeIds: closedIds,
    );
    await _databaseService.saveAiReview(record);
  }

  String _nextAiReviewId(DateTime now) {
    final rand = Random().nextInt(1 << 32).toRadixString(16);
    return 'ai_${now.microsecondsSinceEpoch}_$rand';
  }

  Future<String> _captureReviewImageBase64() async {
    await Future.delayed(const Duration(milliseconds: 16));
    final boundary = _reviewCaptureKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      throw Exception('截图失败：图像边界不可用');
    }
    final ui.Image image = await boundary.toImage(pixelRatio: 1.2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw Exception('截图失败：图像数据为空');
    }
    final Uint8List bytes = data.buffer.asUint8List();
    return base64Encode(bytes);
  }

  String _buildReviewText(AiReviewResult result) {
    final buffer = StringBuffer();
    buffer.writeln('总评：${result.summary}');
    if (result.strengths.isNotEmpty) {
      buffer.writeln('\n优点：');
      for (final item in result.strengths) {
        buffer.writeln('• $item');
      }
    }
    if (result.risks.isNotEmpty) {
      buffer.writeln('\n问题：');
      for (final item in result.risks) {
        buffer.writeln('• $item');
      }
    }
    if (result.suggestions.isNotEmpty) {
      buffer.writeln('\n建议：');
      for (final item in result.suggestions) {
        buffer.writeln('• $item');
      }
    }
    return buffer.toString().trim();
  }

  void _showOrderPanel(BuildContext context, TradeEngine trade, double price, DateTime time, Direction? initialDirection) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16),
        child: OrderPanel(
          currentPrice: price,
          availableMargin: trade.availableMargin,
          onSubmit: (dir, qty, leverage) {
            trade.placeOrder(dir, qty, price, time, leverage: leverage);
          },
        ),
      ),
    );
  }

  void _showSpeedDialog() {
    int currentMs = _replayEngine.currentSpeedMs;
    bool currentAdvanceByPeriod = _advanceByPeriod;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  const Center(
                    child: Text('K线图表设置', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 24),
                  
                  // 推进模式选择
                  const Text('推进模式', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  const SizedBox(height: 12),
                  RadioListTile<bool>(
                    title: const Text('使用源K线推进', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                    value: false,
                    groupValue: currentAdvanceByPeriod,
                    activeColor: AppColors.primary,
                    onChanged: (value) {
                      setModalState(() {
                        currentAdvanceByPeriod = value!;
                        setState(() => _advanceByPeriod = value);
                        _replayEngine.setAdvanceMode(value);
                      });
                    },
                  ),
                  RadioListTile<bool>(
                    title: const Text('按照周期推进', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                    value: true,
                    groupValue: currentAdvanceByPeriod,
                    activeColor: AppColors.primary,
                    onChanged: (value) {
                      setModalState(() {
                        currentAdvanceByPeriod = value!;
                        setState(() => _advanceByPeriod = value);
                        _replayEngine.setAdvanceMode(value);
                      });
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.borderLight),
                  const SizedBox(height: 16),
                  
                  // 速度设置（仅在源K线推进模式下有效）
                  Row(
                    children: [
                      const Text('自动模式速度', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                      if (!currentAdvanceByPeriod)
                        const Text(' (使用源k线推进生效)', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Column(
                    children: [
                      Slider(
                        value: currentMs.toDouble(),
                        min: 50,
                        max: 2000,
                        divisions: 39,
                        activeColor: currentAdvanceByPeriod ? AppColors.borderLight : AppColors.primary,
                        inactiveColor: currentAdvanceByPeriod ? AppColors.borderLight : null,
                        label: '${currentMs}ms',
                        onChanged: currentAdvanceByPeriod ? null : (v) {
                          currentMs = v.toInt();
                          _replayEngine.setSpeed(Duration(milliseconds: currentMs));
                          setModalState(() {});
                        },
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('快', style: TextStyle(color: currentAdvanceByPeriod ? AppColors.borderLight : AppColors.textMuted, fontSize: 12)),
                          Text('${currentMs}ms/tick', style: TextStyle(color: currentAdvanceByPeriod ? AppColors.textMuted : AppColors.textPrimary, fontSize: 13)),
                          Text('慢', style: TextStyle(color: currentAdvanceByPeriod ? AppColors.borderLight : AppColors.textMuted, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // 快捷速度按钮（仅在源K线推进模式下可用）
                  Opacity(
                    opacity: currentAdvanceByPeriod ? 0.3 : 1.0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [100, 250, 500, 1000].map((ms) {
                        final labels = {100: '5x', 250: '2x', 500: '1x', 1000: '0.5x'};
                        final isSelected = currentMs == ms;
                        return GestureDetector(
                          onTap: currentAdvanceByPeriod ? null : () {
                            currentMs = ms;
                            _replayEngine.setSpeed(Duration(milliseconds: ms));
                            setModalState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected && !currentAdvanceByPeriod ? AppColors.primary : AppColors.bgSurface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isSelected && !currentAdvanceByPeriod ? AppColors.primary : AppColors.borderLight),
                            ),
                            child: Text(
                              labels[ms]!,
                              style: TextStyle(
                                color: isSelected && !currentAdvanceByPeriod ? Colors.white : AppColors.textSecondary,
                                fontWeight: isSelected && !currentAdvanceByPeriod ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }


  String _formatVolume(double vol) {
    if (vol >= 10000) return '${(vol / 10000).toStringAsFixed(2)}万';
    if (vol >= 1000) return '${(vol / 1000).toStringAsFixed(2)}K';
    return vol.toStringAsFixed(0);
  }
}
