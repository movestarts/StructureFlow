import 'package:flutter/material.dart';
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
import '../../services/account_service.dart';
import 'package:intl/intl.dart';
import '../widgets/order_panel.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// 副图指标类型
enum SubIndicatorType { vol, macd, kdj, rsi, wr }

class MainScreen extends StatefulWidget {
  final List<KlineModel> allData;
  final int startIndex;
  final int? limit;
  final String instrumentCode;
  final Period initialPeriod;
  final bool spotOnly;
  final String? csvPath;  // 原始CSV路径

  const MainScreen({
    Key? key,
    required this.allData,
    required this.startIndex,
    this.limit,
    this.instrumentCode = 'RB',
    this.initialPeriod = Period.m5,
    this.spotOnly = false,
    this.csvPath,
  }) : super(key: key);

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

  // 主图指标
  MainIndicatorType _mainIndicator = MainIndicatorType.boll;

  // 副图指标
  SubIndicatorType _subIndicator = SubIndicatorType.vol;

  // 指标数据缓存
  List<double?> _ma5 = [];
  List<double?> _ma10 = [];
  List<double?> _ma20 = [];
  BOLLResult _bollData = BOLLResult(upper: [], middle: [], lower: []);
  MACDResult _macdData = MACDResult(dif: [], dea: [], macdBar: []);
  KDJResult _kdjData = KDJResult(k: [], d: [], j: []);
  List<double?> _rsiData = [];
  List<double?> _wrData = [];
  List<double?> _volMa5 = [];
  List<double?> _volMa10 = [];

  @override
  void initState() {
    super.initState();
    _currentPeriod = widget.initialPeriod;
    _replayEngine = ReplayEngine(widget.allData, _currentPeriod, startIndex: widget.startIndex, limit: widget.limit);
    _tradeEngine = TradeEngine();
    _chartController = ChartViewController();

    _replayEngine.addListener(_onReplayUpdate);
    _updateIndicators();
  }

  @override
  void dispose() {
    _submitResults();
    _replayEngine.removeListener(_onReplayUpdate);
    _replayEngine.dispose();
    _chartController.dispose();
    super.dispose();
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
    // 确定可见K线数量：如果是回看，默认显示到当前交易结束的时间点，或者整个session长度
    // 这里使用 _replayEngine.displayKlines.length 可能会有问题因为 engine 已销毁
    // 我们保存 closedTrades 时，每个 trade 都有 closeTime
    // 回看页面会根据 trade 自动定位
    
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
      csvPath: cachedPath ?? widget.csvPath, // 优先使用缓存，失败则尝试使用原始路径
      startIndex: 0,
      visibleBars: null, // 让回看页面自动计算
    )).toList();
    accountService.addTradeRecords(records);
  }

  void _onReplayUpdate() {
    if (_isInitialized) {
      _chartController.updateDataLength(_replayEngine.displayKlines.length);
      _updateIndicators();
    }
  }

  void _updateIndicators() {
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
      }
    });
  }

  void _setMainIndicator(MainIndicatorType indicator) {
    if (_mainIndicator == indicator) return;
    setState(() {
      _mainIndicator = indicator;
    });
    _updateIndicators();
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
      _replayEngine.addListener(_onReplayUpdate);
      _isInitialized = false;
      _updateIndicators();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _replayEngine),
        ChangeNotifierProvider.value(value: _tradeEngine),
        ChangeNotifierProvider.value(value: _chartController),
      ],
      child: Scaffold(
        backgroundColor: AppColors.bgDark,
        body: SafeArea(
          child: Column(
            children: [
              // 顶部状态栏
              _buildTopBar(),
              // 主图
              Expanded(flex: 5, child: _buildMainChart()),
              // 副图 (VOL / MACD / KDJ / RSI / WR)
              Expanded(flex: 2, child: _buildSubChart()),
              // 时间轴
              _buildTimeAxis(),
              // 指标切换栏
              _buildIndicatorTabs(),
              // 底部操作面板
              _buildActionBar(),
            ],
          ),
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

        return Container(
          color: AppColors.bgDark,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            children: [
              Row(
                children: [
                  // 返回 + 标题
                  GestureDetector(
                    onTap: () {
                      _submitResults();
                      Navigator.pop(context);
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.chevron_left, color: AppColors.textPrimary, size: 22),
                        const SizedBox(width: 2),
                        const Text('K线训练营', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 品种名 + 最新价 + 涨跌幅
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widget.instrumentCode,
                      style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '最新价: ',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  Text(
                    price.toStringAsFixed(1),
                    style: TextStyle(
                      color: isUp ? AppColors.bullish : AppColors.bearish,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${change >= 0 ? "+" : ""}${change.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: isUp ? AppColors.bullish : AppColors.bearish,
                      fontSize: 12,
                    ),
                  ),

                  const Spacer(),

                  // 周期选择
                  ..._buildPeriodTabs(),

                  const SizedBox(width: 6),
                  // 设置
                  GestureDetector(
                    onTap: () => _showSpeedDialog(),
                    child: const Icon(Icons.settings, color: AppColors.textMuted, size: 18),
                  ),
                  const SizedBox(width: 8),
                  // 播放/暂停
                  GestureDetector(
                    onTap: () => replay.togglePlayPause(),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: replay.isPlaying ? AppColors.bullish : AppColors.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        replay.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
              // 高开低收量
              const SizedBox(height: 4),
              Row(
                children: [
                  const Spacer(),
                  _buildQuoteItem('高', high, isUp),
                  const SizedBox(width: 12),
                  _buildQuoteItem('低', low, isUp),
                  const SizedBox(width: 12),
                  _buildQuoteItem('量', vol, null, isVolume: true),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuoteItem(String label, double value, bool? isUp, {bool isVolume = false}) {
    String text = isVolume ? _formatVolume(value) : value.toStringAsFixed(1);
    return Text(
      '$label: $text',
      style: TextStyle(
        color: isUp == null ? AppColors.textSecondary : (isUp ? AppColors.bullish : AppColors.bearish),
        fontSize: 11,
      ),
    );
  }

  List<Widget> _buildPeriodTabs() {
    final periods = [Period.m5, Period.m15, Period.m30, Period.h1];
    return periods.map((p) {
      final isSelected = _currentPeriod == p;
      return GestureDetector(
        onTap: () => _switchPeriod(p),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.warning : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            p.code,
            style: TextStyle(
              color: isSelected ? Colors.black : AppColors.textMuted,
              fontSize: 12,
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

            return GestureDetector(
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
                          mainIndicator: _mainIndicator,
                        ),
                      )
                    : const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
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
    }
  }

  // ===== 时间轴 =====
  Widget _buildTimeAxis() {
    return Consumer<ReplayEngine>(
      builder: (ctx, replay, _) {
        final klines = replay.displayKlines;
        if (klines.isEmpty) return const SizedBox(height: 16);

        final first = klines.first.time;
        final last = klines.last.time;

        return Container(
          height: 20,
          color: AppColors.bgOverlay,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(DateFormat('MM-dd HH:mm').format(first), style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
              Text(DateFormat('MM-dd HH:mm').format(last), style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
            ],
          ),
        );
      },
    );
  }

  // ===== 指标切换栏 =====
  Widget _buildIndicatorTabs() {
    return Container(
      height: 34,
      color: AppColors.bgDark,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            // 主图指标
            _buildIndicatorTab('分时', false, () {}),
            _buildIndicatorTab('MA', _mainIndicator == MainIndicatorType.ma, () => _setMainIndicator(MainIndicatorType.ma)),
            _buildIndicatorTab('EMA', _mainIndicator == MainIndicatorType.ema, () => _setMainIndicator(MainIndicatorType.ema)),
            _buildIndicatorTab('BOLL', _mainIndicator == MainIndicatorType.boll, () => _setMainIndicator(MainIndicatorType.boll)),
            Container(width: 1, height: 16, color: AppColors.borderLight, margin: const EdgeInsets.symmetric(horizontal: 6)),
            // 副图指标
            _buildIndicatorTab('VOL', _subIndicator == SubIndicatorType.vol, () => _setSubIndicator(SubIndicatorType.vol)),
            _buildIndicatorTab('MACD', _subIndicator == SubIndicatorType.macd, () => _setSubIndicator(SubIndicatorType.macd)),
            _buildIndicatorTab('KDJ', _subIndicator == SubIndicatorType.kdj, () => _setSubIndicator(SubIndicatorType.kdj)),
            _buildIndicatorTab('RSI', _subIndicator == SubIndicatorType.rsi, () => _setSubIndicator(SubIndicatorType.rsi)),
            _buildIndicatorTab('WR', _subIndicator == SubIndicatorType.wr, () => _setSubIndicator(SubIndicatorType.wr)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showSpeedDialog(),
              child: const Icon(Icons.tune, color: AppColors.textMuted, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicatorTab(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? AppColors.warning : AppColors.textMuted,
            fontSize: 13,
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

        return Container(
          color: AppColors.bgCard,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 数据行
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildDataItem('仓位', hasPosition ? '${trade.activePositions.length}' : '0'),
                  _buildDataItem('资产总值', totalEquity.toStringAsFixed(2), color: totalEquity >= 1000000 ? AppColors.bullish : AppColors.bearish),
                  _buildDataItem('胜率', '${winRate.toStringAsFixed(2)}%', color: winRate > 50 ? AppColors.bullish : AppColors.textSecondary),
                  _buildDataItem('收益率', '${roi.toStringAsFixed(2)}%', color: roi >= 0 ? AppColors.bullish : AppColors.bearish),
                  _buildDataItem('盈亏', floatingPnL.toStringAsFixed(2), color: floatingPnL >= 0 ? AppColors.bullish : AppColors.bearish),
                ],
              ),
              const SizedBox(height: 10),
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
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 做空按钮 (现货模式隐藏)
                  if (!widget.spotOnly)
                    Expanded(
                      child: _buildTradeButton(
                        '做空',
                        AppColors.bearish,
                        !hasPosition ? () => _showOrderPanel(context, trade, price, time, Direction.short) : null,
                      ),
                    ),
                  if (!widget.spotOnly) const SizedBox(width: 8),
                  // 平仓按钮
                  Expanded(
                    child: _buildTradeButton(
                      '平仓',
                      hasPosition ? AppColors.warning : AppColors.textSecondary,
                      hasPosition ? () => trade.closeAll(price, time) : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 向上图标（跳到最新）
                  GestureDetector(
                    onTap: () => _chartController.jumpToLatest(),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: const Icon(Icons.keyboard_double_arrow_up, color: AppColors.textMuted, size: 18),
                    ),
                  ),
                  const SizedBox(width: 20),
                  // 回退
                  _buildControlButton(
                    '回退',
                    Icons.undo,
                    replay.canUndo ? () => replay.undo() : null,
                  ),
                  const SizedBox(width: 8),
                  // 观望（步进）
                  _buildControlButton(
                    '观望',
                    Icons.skip_next,
                    replay.isFinished ? null : () => replay.next(),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDataItem(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color ?? AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
      ],
    );
  }

  Widget _buildTradeButton(String label, Color color, VoidCallback? onPressed, {bool small = false}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: onPressed != null ? color : color.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: onPressed != null ? Colors.white : Colors.white38,
              fontSize: small ? 13 : 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton(String label, IconData icon, VoidCallback? onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: onPressed != null ? AppColors.borderLight : AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: onPressed != null ? AppColors.textPrimary : AppColors.textMuted, size: 18),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: onPressed != null ? AppColors.textPrimary : AppColors.textMuted, fontSize: 10)),
          ],
        ),
      ),
    );
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
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text('播放设置', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 24),
                  const Text('播放速度', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  const SizedBox(height: 12),
                  Column(
                    children: [
                      Slider(
                        value: currentMs.toDouble(),
                        min: 50,
                        max: 2000,
                        divisions: 39,
                        activeColor: AppColors.primary,
                        label: '${currentMs}ms',
                        onChanged: (v) {
                          currentMs = v.toInt();
                          _replayEngine.setSpeed(Duration(milliseconds: currentMs));
                          setModalState(() {});
                        },
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('快', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          Text('${currentMs}ms/tick', style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                          const Text('慢', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // 快捷速度按钮
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [100, 250, 500, 1000].map((ms) {
                      final labels = {100: '5x', 250: '2x', 500: '1x', 1000: '0.5x'};
                      final isSelected = currentMs == ms;
                      return GestureDetector(
                        onTap: () {
                          currentMs = ms;
                          _replayEngine.setSpeed(Duration(milliseconds: ms));
                          setModalState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : AppColors.bgSurface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isSelected ? AppColors.primary : AppColors.borderLight),
                          ),
                          child: Text(
                            labels[ms]!,
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
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
