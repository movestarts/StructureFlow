import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../../models/trade_model.dart';

/// 下单面板 - 弹窗式下单界面
class OrderPanel extends StatefulWidget {
  final double currentPrice;
  final double availableMargin;
  final void Function(Direction direction, double quantity, int leverage) onSubmit;

  const OrderPanel({
    Key? key,
    required this.currentPrice,
    required this.availableMargin,
    required this.onSubmit,
  }) : super(key: key);

  @override
  State<OrderPanel> createState() => _OrderPanelState();
}

class _OrderPanelState extends State<OrderPanel> {
  int _orderTypeIndex = 1; // 0=全仓, 1=市价, 2=限价
  int _leverage = 7;
  String _quantityStr = '0';
  double _quickRatio = 0;

  double get _maxQuantity {
    if (widget.currentPrice <= 0) return 0;
    return (widget.availableMargin * _leverage) / widget.currentPrice;
  }

  double get _quantity => double.tryParse(_quantityStr) ?? 0;

  void _appendDigit(String digit) {
    setState(() {
      if (_quantityStr == '0' && digit != '.') {
        _quantityStr = digit;
      } else {
        // 防止多个小数点
        if (digit == '.' && _quantityStr.contains('.')) return;
        _quantityStr += digit;
      }
    });
  }

  void _backspace() {
    setState(() {
      if (_quantityStr.length <= 1) {
        _quantityStr = '0';
      } else {
        _quantityStr = _quantityStr.substring(0, _quantityStr.length - 1);
      }
    });
  }

  void _setQuickRatio(double ratio) {
    setState(() {
      _quickRatio = ratio;
      final qty = _maxQuantity * ratio;
      _quantityStr = qty.toStringAsFixed(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部：可用保证金 + 关闭按钮
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Text(
                  '可用保证金: ${widget.availableMargin.toStringAsFixed(2)}',
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 左侧：设置区域
                Expanded(
                  flex: 3,
                  child: _buildSettingsPanel(),
                ),
                const SizedBox(width: 12),
                // 右侧：数字键盘
                Expanded(
                  flex: 3,
                  child: _buildNumberPad(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildSettingsPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        // 订单类型切换
        _buildOrderTypeTabs(),
        const SizedBox(height: 16),

        // 杠杆倍数
        Row(
          children: [
            const Text('杠杆倍数', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const Spacer(),
            Text('${_leverage}x',
                style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: AppColors.bgSurface,
            thumbColor: AppColors.primary,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: _leverage.toDouble(),
            min: 1,
            max: 100,
            divisions: 99,
            onChanged: (v) => setState(() => _leverage = v.toInt()),
          ),
        ),
        const SizedBox(height: 12),

        // 数量
        const Text('数量', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.primary),
            borderRadius: BorderRadius.circular(8),
            color: AppColors.bgSurface,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _quantityStr,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 快捷比例
        const Text('快捷比例', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 8),
        Row(
          children: [0.25, 0.50, 0.75, 1.0].map((ratio) {
            final isSelected = (_quickRatio - ratio).abs() < 0.01;
            return Expanded(
              child: GestureDetector(
                onTap: () => _setQuickRatio(ratio),
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.borderLight,
                    ),
                    borderRadius: BorderRadius.circular(6),
                    color: isSelected ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
                  ),
                  child: Center(
                    child: Text(
                      '${(ratio * 100).toInt()}%',
                      style: TextStyle(
                        color: isSelected ? AppColors.primary : AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // 做多/做空按钮
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (_quantity <= 0) return;
                  widget.onSubmit(Direction.long, _quantity, _leverage);
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.bullish,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text('买入/做多',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (_quantity <= 0) return;
                  widget.onSubmit(Direction.short, _quantity, _leverage);
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.bearish,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text('卖出/做空',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOrderTypeTabs() {
    final labels = ['全仓', '市价', '限价'];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: List.generate(3, (i) {
          final isSelected = _orderTypeIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _orderTypeIndex = i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.bgCard : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: isSelected ? Border.all(color: AppColors.primary, width: 1) : null,
                ),
                child: Center(
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: isSelected ? AppColors.primary : AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNumberPad() {
    return Column(
      children: [
        const SizedBox(height: 8),
        // 3x4 数字键盘
        _buildNumRow(['1', '2', '3']),
        _buildNumRow(['4', '5', '6']),
        _buildNumRow(['7', '8', '9']),
        _buildNumRow(['.', '0', '⌫']),
      ],
    );
  }

  Widget _buildNumRow(List<String> keys) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: keys.map((key) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: GestureDetector(
                onTap: () {
                  if (key == '⌫') {
                    _backspace();
                  } else {
                    _appendDigit(key);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Center(
                    child: key == '⌫'
                        ? const Icon(Icons.backspace_outlined, color: AppColors.textSecondary, size: 18)
                        : Text(
                            key,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
