import 'dart:io';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import '../theme/app_theme.dart';
import '../chart/kline_painter.dart';
import '../chart/macd_painter.dart';
import '../chart/volume_painter.dart';
import '../chart/sub_chart_painter.dart';
import '../chart/chart_view_controller.dart';
import '../../models/kline_model.dart';
import '../../models/trade_model.dart';
import '../../models/trade_record.dart';
import '../../models/ai_review_record.dart';
import '../../services/indicator_service.dart';
import '../../services/data_service.dart';
import '../../services/database_service.dart';
import '../../models/period.dart';
import 'package:intl/intl.dart' show DateFormat;

/// 副图指标类型 (与 main_screen 保持一致)
enum _SubIndicator { vol, macd, kdj, rsi, wr }

/// 交易历史 K线回看页面
class TradeHistoryChartScreen extends StatefulWidget {
  final List<TradeRecord> sessionTrades;

  const TradeHistoryChartScreen({super.key, required this.sessionTrades});

  @override
  State<TradeHistoryChartScreen> createState() => _TradeHistoryChartScreenState();
}

class _TradeHistoryChartScreenState extends State<TradeHistoryChartScreen> {
  final ChartViewController _chartController = ChartViewController();
  final IndicatorService _indicatorService = IndicatorService();
  final DatabaseService _databaseService = DatabaseService();

  List<KlineModel> _allData = [];
  bool _isLoading = true;
  String? _error;

  MainIndicatorType _mainIndicator = MainIndicatorType.boll;
  _SubIndicator _subIndicator = _SubIndicator.macd;

  // 指标缓存
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

  bool _isInitialized = false;

  /// 构建虚拟的 Trade 对象用于在图表上显示买卖标记
  List<Trade> get _fakeTrades {
    return widget.sessionTrades.map((t) => Trade(
        id: '${t.id}_entry',
        entryTime: t.entryTime,
        entryPrice: t.entryPrice,
        direction: t.isLong ? Direction.long : Direction.short,
        quantity: t.quantity,
        leverage: t.leverage,
        isOpen: false,
        closePrice: t.closePrice,
        closeTime: t.closeTime,
      )).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _chartController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      if (widget.sessionTrades.isEmpty) {
         setState(() { _error = '没有交易记录'; _isLoading = false; });
         return;
      }
      
      final firstTrade = widget.sessionTrades.first;
      
      if (firstTrade.csvPath == null || firstTrade.csvPath!.isEmpty) {
        final timeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(firstTrade.trainingTime);
        setState(() { 
          _error = '该交易记录未关联有效数据文件\n(训练时间: $timeStr)\n\n可能是历史版本生成的记录，或缓存写入失败。'; 
          _isLoading = false; 
        });
        return;
      }

      final file = File(firstTrade.csvPath!);
      if (!await file.exists()) {
        setState(() { _error = '数据文件不存在:\n${firstTrade.csvPath}'; _isLoading = false; });
        return;
      }

      // Use DataService to load data (DB cache or CSV fallback)
      List<KlineModel> klines = [];
      try {
        // Need a DataService instance
        final dataService = DataService(); 
        klines = await dataService.loadWithCache(
          firstTrade.csvPath!, 
          firstTrade.instrumentCode, 
          forceRefresh: false
        );
      } catch (e) {
        debugPrint('DataService load error: $e');
        // Fallback to simple CSV read if DataService fails (unlikely if file exists)
        final bytes = await file.readAsBytes();
        String content;
        try { content = utf8.decode(bytes); } catch (_) { content = latin1.decode(bytes); }
        final rows = const CsvToListConverter(eol: '\n').convert(content);
        for (int i = 0; i < rows.length; i++) {
          var row = rows[i];
          if (row.isEmpty) continue;
          if (i == 0) { try { double.parse(row[1].toString()); } catch (_) { continue; } }
          try { klines.add(KlineModel.fromList(row)); } catch (_) {}
        }
      }

      if (klines.isEmpty) {
        setState(() { _error = '未能解析K线数据'; _isLoading = false; });
        return;
      }
      
      // Aggregate if period is known
      if (firstTrade.period != null) {
        try {
           final p = Period.values.firstWhere(
             (e) => e.code == firstTrade.period, 
             orElse: () => Period.m5 // Default fallback
           );
           
           if (p != Period.m1 && p != Period.m5) {
             final ds = DataService();
             klines = ds.aggregate(klines, p);
           }
        } catch (e) {
          debugPrint('Aggregation error: $e');
        }
      }

      klines = _trimKlinesAroundSessionTrades(
        klines,
        widget.sessionTrades,
        contextBars: 50,
      );

      // Load FULL data for the session review
      setState(() {
        _allData = klines;
        _isLoading = false;
        _updateIndicators();
      });
    } catch (e) {
      setState(() { _error = '加载数据失败: $e'; _isLoading = false; });
    }
  }

  void _updateIndicators() {
    if (_allData.isEmpty) return;
    _ma5 = _indicatorService.calculateMA(_allData, 5);
    _ma10 = _indicatorService.calculateMA(_allData, 10);
    _ma20 = _indicatorService.calculateMA(_allData, 20);
    _bollData = _indicatorService.calculateBOLL(_allData);
    _macdData = _indicatorService.calculateMACD(_allData);
    _kdjData = _indicatorService.calculateKDJ(_allData);
    _rsiData = _indicatorService.calculateRSI(_allData);
    _wrData = _indicatorService.calculateWR(_allData);
    _volMa5 = _indicatorService.calculateVolumeMA(_allData, 5);
    _volMa10 = _indicatorService.calculateVolumeMA(_allData, 10);
  }

  List<KlineModel> _trimKlinesAroundSessionTrades(
    List<KlineModel> klines,
    List<TradeRecord> trades, {
    int contextBars = 50,
  }) {
    if (klines.isEmpty || trades.isEmpty) return klines;

    DateTime startTime = trades.first.entryTime;
    DateTime endTime = trades.first.closeTime;
    for (final t in trades) {
      if (t.entryTime.isBefore(startTime)) {
        startTime = t.entryTime;
      }
      if (t.closeTime.isAfter(endTime)) {
        endTime = t.closeTime;
      }
    }

    int startIdx = klines.indexWhere(
      (k) => k.time.isAtSameMomentAs(startTime) || k.time.isAfter(startTime),
    );
    if (startIdx < 0) startIdx = 0;

    int endIdx = klines.indexWhere(
      (k) => k.time.isAtSameMomentAs(endTime) || k.time.isAfter(endTime),
    );
    if (endIdx < 0) endIdx = klines.length - 1;
    if (endIdx < startIdx) endIdx = startIdx;

    final from = (startIdx - contextBars).clamp(0, klines.length - 1);
    final to = (endIdx + contextBars).clamp(0, klines.length - 1);
    return klines.sublist(from, to + 1);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sessionTrades.isEmpty) return const SizedBox();
    final firstTrade = widget.sessionTrades.first;
    final title = 'K线训练营 - ${firstTrade.instrumentCode} 历史记录';
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: '历史AI分析',
            onPressed: _showHistoryAiReviews,
            icon: const Icon(Icons.psychology_alt, color: AppColors.textPrimary),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _buildErrorView()
              : _buildChartView(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.warning, size: 48),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 15), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
            child: const Text('返回', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildChartView() {
    return SafeArea(
      child: Column(
        children: [
          // 主图
          Expanded(flex: 5, child: _buildMainChart()),
          // 副图
          Expanded(flex: 2, child: _buildSubChart()),
          // 时间轴
          _buildTimeAxis(),
          // 指标切换栏
          _buildIndicatorTabs(),
        ],
      ),
    );
  }

  Widget _buildMainChart() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!_isInitialized && _allData.isNotEmpty && widget.sessionTrades.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // Find the index of the trade close time
            int targetIndex = _allData.length - 1;
            final lastTrade = widget.sessionTrades.last;
            final closeTime = lastTrade.closeTime;
            
            // Search for the close time index
            for (int i = 0; i < _allData.length; i++) {
              if (_allData[i].time.isAtSameMomentAs(closeTime) || _allData[i].time.isAfter(closeTime)) {
                targetIndex = i;
                break;
              }
            }
            
            // Add some padding (e.g., 20 bars) to show context after the trade
            targetIndex = (targetIndex + 20).clamp(0, _allData.length - 1);

            _chartController.initialize(
              constraints.maxWidth,
              _allData.length,
              targetIndex,
            );
            setState(() => _isInitialized = true);
          });
        }

        return GestureDetector(
          onHorizontalDragStart: (_) => _chartController.onDragStart(),
          onHorizontalDragUpdate: (d) {
            if (_chartController.isUserDragging) {
              _chartController.onDragUpdate(d.delta.dx);
            }
          },
          onHorizontalDragEnd: (_) => _chartController.onDragEnd(),
          onScaleUpdate: (details) {
            if (details.scale != 1.0) {
              _chartController.setScale(_chartController.scale * details.scale);
            }
          },
          child: ListenableBuilder(
            listenable: _chartController,
            builder: (context, _) {
              return Container(
                color: AppColors.bgOverlay,
                width: double.infinity,
                child: _isInitialized
                    ? CustomPaint(
                        painter: KlinePainter(
                          allData: _allData,
                          allTrades: _fakeTrades,
                          viewController: _chartController,
                          currentPrice: _allData.isNotEmpty ? _allData.last.close : 0,
                          ma5: _ma5,
                          ma10: _ma10,
                          ma20: _ma20,
                          bollData: _bollData,
                          mainIndicator: _mainIndicator,
                        ),
                      )
                    : const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSubChart() {
    return ListenableBuilder(
      listenable: _chartController,
      builder: (context, _) {
        if (!_isInitialized || _allData.isEmpty) {
          return Container(color: AppColors.bgOverlay);
        }

        switch (_subIndicator) {
          case _SubIndicator.vol:
            return Container(
              color: AppColors.bgOverlay,
              child: CustomPaint(
                painter: VolumePainter(
                  allData: _allData,
                  viewController: _chartController,
                  volMa5: _volMa5,
                  volMa10: _volMa10,
                ),
                size: Size.infinite,
              ),
            );
          case _SubIndicator.macd:
            return Container(
              color: AppColors.bgOverlay,
              child: CustomPaint(
                painter: MACDPainter(
                  macdData: _macdData,
                  viewController: _chartController,
                  dataLength: _allData.length,
                ),
                size: Size.infinite,
              ),
            );
          default:
            SubChartPainter painter;
            switch (_subIndicator) {
              case _SubIndicator.kdj:
                painter = createKDJPainter(kdjData: _kdjData, viewController: _chartController, dataLength: _allData.length);
                break;
              case _SubIndicator.rsi:
                painter = createRSIPainter(rsiData: _rsiData, viewController: _chartController, dataLength: _allData.length);
                break;
              case _SubIndicator.wr:
                painter = createWRPainter(wrData: _wrData, viewController: _chartController, dataLength: _allData.length);
                break;
              default:
                painter = createKDJPainter(kdjData: _kdjData, viewController: _chartController, dataLength: _allData.length);
            }
            return Container(
              color: AppColors.bgOverlay,
              child: CustomPaint(
                painter: painter,
                size: Size.infinite,
              ),
            );
        }
      },
    );
  }

  Widget _buildTimeAxis() {
    return ListenableBuilder(
      listenable: _chartController,
      builder: (context, _) {
        if (!_isInitialized || _allData.isEmpty) {
          return const SizedBox(height: 20);
        }

        int startIdx = _chartController.visibleStartIndex.clamp(0, _allData.length);
        int endIdx = _chartController.visibleEndIndex.clamp(0, _allData.length);
        if (startIdx >= endIdx) return const SizedBox(height: 20);

        final dateFormat = DateFormat('MM-dd HH:mm');
        final step = _chartController.step;
        const priceAxisWidth = 60.0;
        final plotWidth = MediaQuery.of(context).size.width - priceAxisWidth;
        final interval = ((endIdx - startIdx) / 3).ceil();

        return Container(
          height: 20,
          color: AppColors.bgOverlay,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: CustomPaint(
            painter: _TimeAxisPainter(
              data: _allData,
              startIdx: startIdx,
              endIdx: endIdx,
              step: step,
              plotWidth: plotWidth,
              interval: interval,
              dateFormat: dateFormat,
            ),
          ),
        );
      },
    );
  }

  Widget _buildIndicatorTabs() {
    return Container(
      height: 36,
      color: AppColors.bgOverlay,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            // 主图指标分隔
            _buildIndicatorTab('分时', false, () {}),
            Container(width: 1, height: 14, color: AppColors.border, margin: const EdgeInsets.symmetric(horizontal: 4)),
            _buildIndicatorTab('MA', _mainIndicator == MainIndicatorType.ma, () => setState(() => _mainIndicator = MainIndicatorType.ma)),
            _buildIndicatorTab('EMA', _mainIndicator == MainIndicatorType.ema, () => setState(() => _mainIndicator = MainIndicatorType.ema)),
            _buildIndicatorTab('BOLL', _mainIndicator == MainIndicatorType.boll, () => setState(() => _mainIndicator = MainIndicatorType.boll)),
            Container(width: 1, height: 14, color: AppColors.border, margin: const EdgeInsets.symmetric(horizontal: 4)),
            // 副图指标
            _buildIndicatorTab('VOL', _subIndicator == _SubIndicator.vol, () => setState(() => _subIndicator = _SubIndicator.vol)),
            _buildIndicatorTab('MACD', _subIndicator == _SubIndicator.macd, () => setState(() => _subIndicator = _SubIndicator.macd)),
            _buildIndicatorTab('KDJ', _subIndicator == _SubIndicator.kdj, () => setState(() => _subIndicator = _SubIndicator.kdj)),
            _buildIndicatorTab('RSI', _subIndicator == _SubIndicator.rsi, () => setState(() => _subIndicator = _SubIndicator.rsi)),
            _buildIndicatorTab('WR', _subIndicator == _SubIndicator.wr, () => setState(() => _subIndicator = _SubIndicator.wr)),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicatorTab(String label, bool isActive, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: isActive
              ? BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                )
              : null,
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? AppColors.primary : AppColors.textMuted,
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showHistoryAiReviews() async {
    final tradeIds = widget.sessionTrades.map((e) => e.id).toList();
    if (tradeIds.isEmpty) return;

    try {
      final reviews = await _databaseService.loadAiReviewsByTradeIds(tradeIds);
      if (!mounted) return;
      if (reviews.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前仓位暂无历史AI分析')),
        );
        return;
      }

      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.bgCard,
        builder: (ctx) => SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.all(12),
            itemCount: reviews.length,
            separatorBuilder: (_, __) => const Divider(color: AppColors.border),
            itemBuilder: (_, index) {
              final item = reviews[index];
              return ListTile(
                title: Text(
                  '${DateFormat('yyyy-MM-dd HH:mm').format(item.createdAt)}  ${item.score}分',
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                subtitle: Text(
                  item.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAiReviewDetail(item);
                },
              );
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('读取历史AI分析失败: $e')),
      );
    }
  }

  Future<void> _showAiReviewDetail(AiReviewRecord item) async {
    final text = StringBuffer()..writeln('总评: ${item.summary}');
    if (item.strengths.isNotEmpty) {
      text.writeln('\n优点:');
      for (final v in item.strengths) {
        text.writeln('- $v');
      }
    }
    if (item.risks.isNotEmpty) {
      text.writeln('\n问题:');
      for (final v in item.risks) {
        text.writeln('- $v');
      }
    }
    if (item.suggestions.isNotEmpty) {
      text.writeln('\n建议:');
      for (final v in item.suggestions) {
        text.writeln('- $v');
      }
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text(
          '历史AI分析 · ${item.score}分',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: SingleChildScrollView(
          child: Text(
            text.toString().trim(),
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
  }
}

/// 时间轴绘制
class _TimeAxisPainter extends CustomPainter {
  final List<KlineModel> data;
  final int startIdx;
  final int endIdx;
  final double step;
  final double plotWidth;
  final int interval;
  final DateFormat dateFormat;

  _TimeAxisPainter({
    required this.data,
    required this.startIdx,
    required this.endIdx,
    required this.step,
    required this.plotWidth,
    required this.interval,
    required this.dateFormat,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (int i = startIdx; i < endIdx; i += interval) {
      if (i < 0 || i >= data.length) continue;
      final x = (i - startIdx) * step + step / 2;
      if (x < 0 || x > plotWidth) continue;

      tp.text = TextSpan(
        text: dateFormat.format(data[i].time),
        style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
      );
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width / 2, 2));
    }
  }

  @override
  bool shouldRepaint(covariant _TimeAxisPainter old) => true;
}
