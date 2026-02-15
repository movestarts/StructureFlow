import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/settings_service.dart';
import '../theme/app_theme.dart';

class LlmSettingsScreen extends StatefulWidget {
  const LlmSettingsScreen({super.key});

  @override
  State<LlmSettingsScreen> createState() => _LlmSettingsScreenState();
}

class _LlmSettingsScreenState extends State<LlmSettingsScreen> {
  late String _provider;
  late TextEditingController _apiKeyCtrl;
  late TextEditingController _endpointCtrl;
  late TextEditingController _modelCtrl;
  bool _obscureApiKey = true;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _cardBg => _isDark ? AppColors.bgCard : Colors.white;
  Color get _textPrimary =>
      _isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
  Color get _textSecondary =>
      _isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
  Color get _borderClr => _isDark ? AppColors.borderLight : AppColors.lightBorder;
  Color get _inputFill => _isDark ? AppColors.bgSurface : Colors.white;

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsService>();
    _provider = s.llmProvider;
    _apiKeyCtrl = TextEditingController(text: s.llmApiKey);
    _endpointCtrl = TextEditingController(text: s.llmEndpoint);
    _modelCtrl = TextEditingController(text: s.llmModel);
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _endpointCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  void _applyProviderPreset(String provider) {
    if (provider == 'zhipu') {
      _endpointCtrl.text = 'https://open.bigmodel.cn/api/paas/v4/chat/completions';
      if (_modelCtrl.text.trim().isEmpty || _modelCtrl.text.startsWith('gpt-')) {
        _modelCtrl.text = 'glm-4.6v-flash';
      }
    } else if (provider == 'openai') {
      _endpointCtrl.text = 'https://api.openai.com/v1/chat/completions';
      if (_modelCtrl.text.trim().isEmpty || _modelCtrl.text.startsWith('glm-')) {
        _modelCtrl.text = 'gpt-4o-mini';
      }
    }
  }

  List<String> _modelOptionsForProvider(String provider) {
    if (provider == 'zhipu') {
      return const [
        'glm-4.6v',
        'glm-4.6v-flash',
        'glm-4v-flash',
      ];
    }
    if (provider == 'openai') {
      return const ['gpt-4o', 'gpt-4o-mini'];
    }
    return const [];
  }

  void _save() {
    final s = context.read<SettingsService>();
    s.llmProvider = _provider;
    s.llmApiKey = _apiKeyCtrl.text.trim();
    s.llmEndpoint = _endpointCtrl.text.trim();
    s.llmModel = _modelCtrl.text.trim();
    s.save();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDark ? AppColors.bgDark : AppColors.lightBg,
      appBar: AppBar(
        title: Text('大模型配置', style: TextStyle(color: _textPrimary)),
        iconTheme: IconThemeData(color: _textPrimary),
        backgroundColor: _cardBg,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('模型提供商', style: TextStyle(color: _textSecondary)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _provider,
                    decoration: _inputDecoration(),
                    items: const [
                      DropdownMenuItem(value: 'zhipu', child: Text('智谱 (默认)')),
                      DropdownMenuItem(value: 'openai', child: Text('OpenAI')),
                      DropdownMenuItem(value: 'custom', child: Text('自定义')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _provider = v;
                        _applyProviderPreset(v);
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  Text('API Key', style: TextStyle(color: _textSecondary)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _apiKeyCtrl,
                    obscureText: _obscureApiKey,
                    decoration: _inputDecoration().copyWith(
                      hintText: '输入你的 API Key',
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _obscureApiKey = !_obscureApiKey),
                        icon: Icon(
                          _obscureApiKey
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Endpoint', style: TextStyle(color: _textSecondary)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _endpointCtrl,
                    decoration: _inputDecoration().copyWith(
                      hintText: '模型接口地址',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Model', style: TextStyle(color: _textSecondary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _modelOptionsForProvider(_provider).map((m) {
                      return ChoiceChip(
                        label: Text(m),
                        selected: _modelCtrl.text.trim() == m,
                        onSelected: (_) => setState(() => _modelCtrl.text = m),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _modelCtrl,
                    decoration: _inputDecoration().copyWith(
                      hintText: '例如 glm-4.6v-flash',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '默认优先使用这里的配置；若为空则回退到 --dart-define 的配置。',
              style: TextStyle(color: _textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderClr),
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: _inputFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _borderClr),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _borderClr),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
    );
  }
}
