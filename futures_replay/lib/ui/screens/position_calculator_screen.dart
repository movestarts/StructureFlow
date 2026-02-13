import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 仓位计算器
class PositionCalculatorScreen extends StatefulWidget {
  const PositionCalculatorScreen({super.key});

  @override
  State<PositionCalculatorScreen> createState() =>
      _PositionCalculatorScreenState();
}

class _PositionCalculatorScreenState extends State<PositionCalculatorScreen> {
  // 计算模式: 0=盈亏比计算, 1=止盈价计算
  int _calcMode = 0;

  // 输入字段
  final _entryPriceCtrl = TextEditingController(text: '50.0');
  final _totalCapitalCtrl = TextEditingController(text: '1000.0');
  final _takeProfitCtrl = TextEditingController(text: '60.0');
  final _stopLossCtrl = TextEditingController(text: '45.0');
  final _maxLossCtrl = TextEditingController(text: '100.0');

  // 模式2额外字段: 盈亏比输入
  final _targetRatioCtrl = TextEditingController(text: '2.0');

  // 计算结果
  bool _hasResult = false;
  double _plRatio = 0; // 盈亏比
  int _positionSize = 0; // 应开仓位 (手)
  double _riskAmount = 0; // 风险金额
  double _positionValue = 0; // 仓位价值

  // 详情
  double _entryPrice = 0;
  double _takeProfitPrice = 0;
  double _stopLossPrice = 0;
  double _maxLoss = 0;
  double _potentialProfit = 0;
  double _potentialLoss = 0;
  double _positionRatio = 0; // 仓位占比 %
  double _totalCapital = 0;

  @override
  void dispose() {
    _entryPriceCtrl.dispose();
    _totalCapitalCtrl.dispose();
    _takeProfitCtrl.dispose();
    _stopLossCtrl.dispose();
    _maxLossCtrl.dispose();
    _targetRatioCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final entry = double.tryParse(_entryPriceCtrl.text) ?? 0;
    final capital = double.tryParse(_totalCapitalCtrl.text) ?? 0;
    final sl = double.tryParse(_stopLossCtrl.text) ?? 0;
    final maxLoss = double.tryParse(_maxLossCtrl.text) ?? 0;

    if (entry <= 0 || capital <= 0 || sl <= 0 || maxLoss <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的正数值'), backgroundColor: AppColors.error),
      );
      return;
    }

    final lossPerUnit = (entry - sl).abs();
    if (lossPerUnit == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('买入价和止损价不能相同'), backgroundColor: AppColors.error),
      );
      return;
    }

    double tp;
    if (_calcMode == 0) {
      // 盈亏比计算模式：从输入读取止盈价
      tp = double.tryParse(_takeProfitCtrl.text) ?? 0;
      if (tp <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请输入有效的止盈价'), backgroundColor: AppColors.error),
        );
        return;
      }
    } else {
      // 止盈价计算模式：根据目标盈亏比反算止盈价
      final targetRatio = double.tryParse(_targetRatioCtrl.text) ?? 0;
      if (targetRatio <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请输入有效的目标盈亏比'), backgroundColor: AppColors.error),
        );
        return;
      }
      // 如果做多 (entry > sl): tp = entry + lossPerUnit * targetRatio
      // 如果做空 (entry < sl): tp = entry - lossPerUnit * targetRatio
      if (entry > sl) {
        tp = entry + lossPerUnit * targetRatio;
      } else {
        tp = entry - lossPerUnit * targetRatio;
      }
      _takeProfitCtrl.text = tp.toStringAsFixed(2);
    }

    final profitPerUnit = (tp - entry).abs();
    final ratio = profitPerUnit / lossPerUnit;
    final posSize = (maxLoss / lossPerUnit).floor();
    final posValue = posSize * entry;
    final posRatio = capital > 0 ? (posValue / capital * 100) : 0.0;

    setState(() {
      _hasResult = true;
      _plRatio = ratio;
      _positionSize = posSize;
      _riskAmount = maxLoss;
      _positionValue = posValue;

      _entryPrice = entry;
      _takeProfitPrice = tp;
      _stopLossPrice = sl;
      _maxLoss = maxLoss;
      _totalCapital = capital;
      _potentialProfit = profitPerUnit * posSize;
      _potentialLoss = lossPerUnit * posSize;
      _positionRatio = posRatio;
    });
  }

  void _reset() {
    setState(() {
      _entryPriceCtrl.text = '50.0';
      _totalCapitalCtrl.text = '1000.0';
      _takeProfitCtrl.text = '60.0';
      _stopLossCtrl.text = '45.0';
      _maxLossCtrl.text = '100.0';
      _targetRatioCtrl.text = '2.0';
      _hasResult = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.lightTextPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '仓位计算器',
          style: TextStyle(
            color: AppColors.lightTextPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.lightTextPrimary),
            onPressed: _reset,
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 计算模式选择
                _buildModeSelector(),
                const SizedBox(height: 16),

                // 模式标题
                Center(
                  child: Text(
                    _calcMode == 0 ? '模式1: 盈亏比计算' : '模式2: 止盈价计算',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 输入区域
                _buildInputFields(),
                const SizedBox(height: 28),

                // 计算结果
                if (_hasResult) ...[
                  _buildResultsSection(),
                  const SizedBox(height: 20),
                  _buildDetailsList(),
                ],
              ],
            ),
          ),

          // 底部浮动栏
          if (_hasResult) _buildBottomBar(),
        ],
      ),
    );
  }

  // ===== 计算模式选择器 =====
  Widget _buildModeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题条
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.futuresHeaderBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Text(
              '计算模式',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // 选项
          _buildModeOption(
            0,
            '盈亏比计算',
            '已知止盈止损，计算盈亏比和仓位',
          ),
          Divider(height: 1, color: AppColors.lightDivider, indent: 16, endIndent: 16),
          _buildModeOption(
            1,
            '止盈价计算',
            '已知盈亏比，计算止盈价和仓位',
          ),
        ],
      ),
    );
  }

  Widget _buildModeOption(int mode, String title, String subtitle) {
    final isSelected = _calcMode == mode;
    return InkWell(
      onTap: () => setState(() {
        _calcMode = mode;
        _hasResult = false;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.05) : Colors.transparent,
          borderRadius: mode == 1
              ? const BorderRadius.vertical(bottom: Radius.circular(12))
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? AppColors.lightTextPrimary : AppColors.lightTextSecondary,
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppColors.lightTextMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  // ===== 输入字段 =====
  Widget _buildInputFields() {
    return Column(
      children: [
        // 第一行: 买入价 + 总资金
        Row(
          children: [
            Expanded(child: _buildInputField('买入价', _entryPriceCtrl, '元')),
            const SizedBox(width: 16),
            Expanded(child: _buildInputField('总资金', _totalCapitalCtrl, '元')),
          ],
        ),
        const SizedBox(height: 16),
        // 第二行: 止盈价/目标盈亏比 + 止损价
        Row(
          children: [
            Expanded(
              child: _calcMode == 0
                  ? _buildInputField('止盈价', _takeProfitCtrl, '元')
                  : _buildInputField('目标盈亏比', _targetRatioCtrl, ':1'),
            ),
            const SizedBox(width: 16),
            Expanded(child: _buildInputField('止损价', _stopLossCtrl, '元')),
          ],
        ),
        const SizedBox(height: 16),
        // 第三行: 最大亏损
        _buildInputField('最大亏损', _maxLossCtrl, '元'),
        const SizedBox(height: 8),
        Center(
          child: Text(
            '单次交易最大损失承受的百分比金额',
            style: TextStyle(
              color: AppColors.lightTextMuted,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 20),
        // 计算按钮
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _calculate,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              '开始计算',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, String suffix) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.lightTextPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(
            color: AppColors.lightTextPrimary,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            suffixText: suffix,
            suffixStyle: TextStyle(
              color: AppColors.lightTextMuted,
              fontSize: 14,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.lightBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.lightBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // ===== 计算结果卡片 =====
  Widget _buildResultsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.grid_view_rounded, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              '计算结果',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 2x2 结果卡片网格
        Row(
          children: [
            Expanded(
              child: _buildResultCard(
                icon: Icons.trending_up,
                iconColor: AppColors.primary,
                label: '盈亏比',
                value: '${_plRatio.toStringAsFixed(2)}:1',
                valueColor: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildResultCard(
                icon: Icons.inventory_2_outlined,
                iconColor: AppColors.lightTextSecondary,
                label: '应开仓位',
                value: '$_positionSize手',
                valueColor: AppColors.lightTextPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildResultCard(
                icon: Icons.warning_amber_rounded,
                iconColor: AppColors.error,
                label: '风险金额',
                value: '${_riskAmount.toStringAsFixed(2)}元',
                valueColor: AppColors.error,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildResultCard(
                icon: Icons.attach_money,
                iconColor: AppColors.success,
                label: '仓位价值',
                value: '${_positionValue.toStringAsFixed(2)}元',
                valueColor: AppColors.success,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResultCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.lightTextSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ===== 详情列表 =====
  Widget _buildDetailsList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildDetailRow('买入价格', '${_entryPrice.toStringAsFixed(2)}元'),
          _buildDivider(),
          _buildDetailRow('止盈价格', '${_takeProfitPrice.toStringAsFixed(2)}元'),
          _buildDivider(),
          _buildDetailRow('止损价格', '${_stopLossPrice.toStringAsFixed(2)}元'),
          _buildDivider(),
          _buildDetailRow('最大损失', '${_maxLoss.toStringAsFixed(2)}元'),
          _buildDivider(),
          _buildDetailRow('潜在盈利', '${_potentialProfit.toStringAsFixed(2)}元',
              valueColor: AppColors.success),
          _buildDivider(),
          _buildDetailRow('潜在亏损', '${_potentialLoss.toStringAsFixed(2)}元',
              valueColor: AppColors.error),
          _buildDivider(),
          _buildDetailRow('仓位占比', '${_positionRatio.toStringAsFixed(2)}%'),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.lightTextPrimary,
              fontSize: 15,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.lightTextPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, color: AppColors.lightDivider, indent: 20, endIndent: 20);
  }

  // ===== 底部浮动栏 =====
  Widget _buildBottomBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          children: [
            // 盈亏比
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '盈亏比',
                  style: TextStyle(
                    color: AppColors.lightTextMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_plRatio.toStringAsFixed(2)}:1',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 24),
            // 仓位
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '仓位',
                  style: TextStyle(
                    color: AppColors.lightTextMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$_positionSize手',
                  style: const TextStyle(
                    color: AppColors.lightTextPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Spacer(),
            // 重新计算按钮
            ElevatedButton.icon(
              onPressed: _calculate,
              icon: const Icon(Icons.grid_view_rounded, color: Colors.white, size: 18),
              label: const Text(
                '重新计算',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
