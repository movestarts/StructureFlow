import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/kline_model.dart';
import '../../models/period.dart';
import '../../engine/replay_engine.dart';
import '../../engine/trade_engine.dart';
import '../chart/kline_painter.dart';
import '../chart/chart_view_controller.dart';
import '../../models/trade_model.dart';

class MainScreen extends StatefulWidget {
  final List<KlineModel> allData;
  final int startIndex;
  final int? limit;

  const MainScreen({
    Key? key, 
    required this.allData, 
    required this.startIndex, 
    this.limit
  }) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late ReplayEngine _replayEngine;
  late TradeEngine _tradeEngine;
  late ChartViewController _chartController;
  Period _currentPeriod = Period.m5;
  
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _replayEngine = ReplayEngine(widget.allData, _currentPeriod, startIndex: widget.startIndex, limit: widget.limit);
    _tradeEngine = TradeEngine();
    _chartController = ChartViewController();
    
    _replayEngine.addListener(_onReplayUpdate);
  }
  
  @override
  void dispose() {
    _replayEngine.removeListener(_onReplayUpdate);
    super.dispose();
  }
  
  void _onReplayUpdate() {
    if (_isInitialized) {
      _chartController.updateDataLength(_replayEngine.displayKlines.length);
    }
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
        appBar: AppBar(
          title: const Text("期货复盘训练"),
          actions: [
            DropdownButton<Period>(
              value: _currentPeriod,
              dropdownColor: Colors.grey[800],
              style: const TextStyle(color: Colors.white),
              items: Period.values.map((p) => DropdownMenuItem(value: p, child: Text(p.label))).toList(),
              onChanged: (p) {
                if (p != null) {
                  int currentIdx = _replayEngine.currentProgress;
                  
                  // 移除旧监听器
                  _replayEngine.removeListener(_onReplayUpdate);
                  
                  setState(() {
                    _currentPeriod = p;
                    // 创建新引擎
                    _replayEngine = ReplayEngine(widget.allData, _currentPeriod, startIndex: currentIdx, limit: widget.limit);
                    // 添加新监听器
                    _replayEngine.addListener(_onReplayUpdate);
                    // 重置图表初始化状态
                    _isInitialized = false;
                  });
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.skip_next),
              tooltip: '跳转到最新',
              onPressed: () => _chartController.jumpToLatest(),
            ),
          ],
        ),
        body: Column(
          children: [
            // Chart Area
            Expanded(
              flex: 3,
              child: Consumer3<ReplayEngine, TradeEngine, ChartViewController>(
                builder: (context, replay, trade, chartCtrl, child) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      if (!_isInitialized && replay.displayKlines.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _chartController.initialize(
                            constraints.maxWidth,
                            replay.displayKlines.length,
                            replay.displayKlines.length - 1,
                          );
                          setState(() => _isInitialized = true);
                        });
                      }
                      
                      return Listener(
                        onPointerDown: (event) {
                          _chartController.onDragStart();
                        },
                        onPointerMove: (event) {
                          if (chartCtrl.isUserDragging) {
                            _chartController.onDragUpdate(event.delta.dx);
                          }
                        },
                        onPointerUp: (event) {
                          _chartController.onDragEnd();
                        },
                        child: Container(
                          color: Colors.black,
                          width: double.infinity,
                          child: _isInitialized
                              ? CustomPaint(
                                  painter: KlinePainter(
                                    allData: replay.displayKlines,
                                    allTrades: trade.allTrades,
                                    viewController: chartCtrl,
                                    currentPrice: replay.currentQuote?.close ?? 0,
                                  ),
                                )
                              : const Center(child: CircularProgressIndicator()),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            
            // Info Bar
            Consumer2<ReplayEngine, TradeEngine>(
              builder: (ctx, replay, trade, _) {
                 final quote = replay.currentQuote;
                 final price = quote?.close ?? 0;
                 return Container(
                   height: 40,
                   color: Colors.grey[900],
                   child: Row(
                     mainAxisAlignment: MainAxisAlignment.spaceAround,
                     children: [
                       Text("价格: ${price.toStringAsFixed(1)}", style: const TextStyle(color: Colors.white, fontSize: 16)),
                       Text("持仓: ${trade.activePositions.length}", style: const TextStyle(color: Colors.white)),
                       Text("浮盈: ${trade.calculateFloatingPnL(price).toStringAsFixed(0)}", 
                          style: TextStyle(color: trade.calculateFloatingPnL(price) >= 0 ? Colors.red : Colors.green)),
                       Text("权益: ${trade.totalEquity.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white)),
                     ],
                   ),
                 );
              }
            ),

            // Controls
            Expanded(
              flex: 1,
              child: Row(
                children: [
                  Expanded(
                    child: Consumer2<ReplayEngine, TradeEngine>(
                      builder: (ctx, replay, trade, _) {
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                    onPressed: () {
                                       trade.placeOrder(Direction.long, 1, replay.currentQuote?.close ?? 0, replay.currentQuote?.time ?? DateTime.now());
                                    },
                                    child: const Text("买多"),
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                    onPressed: () {
                                      trade.placeOrder(Direction.short, 1, replay.currentQuote?.close ?? 0, replay.currentQuote?.time ?? DateTime.now());
                                    },
                                    child: const Text("卖空"),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              ElevatedButton(
                                onPressed: () {
                                  trade.closeAll(replay.currentQuote?.close ?? 0, replay.currentQuote?.time ?? DateTime.now());
                                },
                                child: const Text("平仓"),
                              )
                            ],
                          ),
                        );
                      }
                    ),
                  ),
                  
                  Expanded(
                    child: Consumer<ReplayEngine>(
                      builder: (ctx, engine, _) {
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.play_arrow), 
                                  tooltip: '播放',
                                  onPressed: engine.play
                                ),
                                IconButton(
                                  icon: const Icon(Icons.pause), 
                                  tooltip: '暂停',
                                  onPressed: engine.pause
                                ),
                                IconButton(
                                  icon: const Icon(Icons.skip_next), 
                                  tooltip: '下一个5分钟',
                                  onPressed: engine.next
                                ),
                                IconButton(
                                  icon: const Icon(Icons.fast_forward), 
                                  tooltip: '下一根K线',
                                  onPressed: engine.nextBar,
                                  color: Colors.orange,
                                ),
                              ],
                            ),
                            Slider(
                                value: engine.currentSpeedMs.toDouble(),
                                min: 100, 
                                max: 2000, 
                                divisions: 19,
                                label: "${engine.currentSpeedMs}ms",
                                onChanged: (v) => engine.setSpeed(Duration(milliseconds: v.toInt()))
                            ),
                          ],
                        );
                      }
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
