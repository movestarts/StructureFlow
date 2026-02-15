import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/llm_profile.dart';
import '../../services/settings_service.dart';
import '../theme/app_theme.dart';

class LlmModelManagementScreen extends StatefulWidget {
  const LlmModelManagementScreen({super.key});

  @override
  State<LlmModelManagementScreen> createState() =>
      _LlmModelManagementScreenState();
}

class _LlmModelManagementScreenState extends State<LlmModelManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;
    final cardBg = isDark ? AppColors.bgCard : Colors.white;

    return Scaffold(
      appBar: AppBar(title: const Text('大模型管理')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('新增模型'),
      ),
      body: Consumer<SettingsService>(
        builder: (context, settings, _) {
          final profiles = settings.llmProfiles;
          if (profiles.isEmpty) {
            return const Center(child: Text('暂无模型配置'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: profiles.length,
            itemBuilder: (_, i) {
              final p = profiles[i];
              final isVisionBound = p.id == settings.llmVisionProfileId;
              final isTextBound = p.id == settings.llmTextProfileId;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.name,
                            style: TextStyle(
                              color: textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (isVisionBound)
                          _pill('图像绑定', const Color(0xFF06B6D4)),
                        if (isTextBound)
                          _pill('文本绑定', const Color(0xFF84CC16)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${p.provider} · ${p.model}\n${p.endpoint}',
                      style: TextStyle(color: textMuted, height: 1.35),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _pill(
                          p.supportsVision ? '视觉: 是' : '视觉: 否',
                          p.supportsVision
                              ? const Color(0xFF10B981)
                              : const Color(0xFF6B7280),
                        ),
                        _pill(
                          p.supportsText ? '文本: 是' : '文本: 否',
                          p.supportsText
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFF6B7280),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => _openEditor(context, existing: p),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('编辑'),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () => _confirmDelete(context, p),
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: AppColors.error,
                          ),
                          label: const Text(
                            '删除',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, LlmProfile profile) async {
    final settings = context.read<SettingsService>();
    if (settings.llmProfiles.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('至少保留一个模型配置')),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除模型'),
        content: Text('确认删除 "${profile.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;
    settings.removeLlmProfile(profile.id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已删除')),
    );
  }

  Future<void> _openEditor(
    BuildContext context, {
    LlmProfile? existing,
  }) async {
    final result = await showDialog<LlmProfile>(
      context: context,
      builder: (_) => _LlmProfileEditorDialog(existing: existing),
    );
    if (result == null || !context.mounted) return;
    context.read<SettingsService>().upsertLlmProfile(result);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(existing == null ? '已新增模型' : '已保存修改')),
    );
  }
}

class _LlmProfileEditorDialog extends StatefulWidget {
  final LlmProfile? existing;

  const _LlmProfileEditorDialog({this.existing});

  @override
  State<_LlmProfileEditorDialog> createState() => _LlmProfileEditorDialogState();
}

class _LlmProfileEditorDialogState extends State<_LlmProfileEditorDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _apiKeyCtrl;
  late final TextEditingController _endpointCtrl;
  late final TextEditingController _modelCtrl;
  late String _provider;
  bool _supportsVision = true;
  bool _supportsText = true;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _apiKeyCtrl = TextEditingController(text: p?.apiKey ?? '');
    _endpointCtrl = TextEditingController(
      text: p?.endpoint ??
          'https://open.bigmodel.cn/api/paas/v4/chat/completions',
    );
    _modelCtrl = TextEditingController(text: p?.model ?? 'glm-4.6v');
    _provider = p?.provider ?? 'zhipu';
    _supportsVision = p?.supportsVision ?? true;
    _supportsText = p?.supportsText ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _apiKeyCtrl.dispose();
    _endpointCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? '新增模型' : '编辑模型'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: '名称'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _provider,
              decoration: const InputDecoration(labelText: 'Provider'),
              items: const [
                DropdownMenuItem(value: 'zhipu', child: Text('智谱')),
                DropdownMenuItem(value: 'openai', child: Text('OpenAI')),
                DropdownMenuItem(value: 'custom', child: Text('自定义')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _provider = v);
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _apiKeyCtrl,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'API Key',
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _endpointCtrl,
              decoration: const InputDecoration(labelText: 'Endpoint'),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _provider == 'zhipu'
                  ? const ['glm-4.6v', 'glm-4.6v-flash', 'glm-5', 'glm-5-flash']
                      .map(
                        (m) => ChoiceChip(
                          label: Text(m),
                          selected: _modelCtrl.text.trim() == m,
                          onSelected: (_) => setState(() => _modelCtrl.text = m),
                        ),
                      )
                      .toList()
                  : const [],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _modelCtrl,
              decoration: const InputDecoration(labelText: 'Model'),
            ),
            const SizedBox(height: 10),
            CheckboxListTile(
              value: _supportsVision,
              title: const Text('支持视觉'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (v) => setState(() => _supportsVision = v ?? false),
            ),
            CheckboxListTile(
              value: _supportsText,
              title: const Text('支持文本'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (v) => setState(() => _supportsText = v ?? false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('保存'),
        ),
      ],
    );
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    final endpoint = _endpointCtrl.text.trim();
    final model = _modelCtrl.text.trim();
    if (name.isEmpty || endpoint.isEmpty || model.isEmpty) {
      setState(() => _error = '名称、Endpoint、Model 不能为空');
      return;
    }
    if (!_supportsVision && !_supportsText) {
      setState(() => _error = '至少选择一个能力（视觉/文本）');
      return;
    }

    final id =
        widget.existing?.id ?? 'llm_${DateTime.now().microsecondsSinceEpoch}';
    Navigator.pop(
      context,
      LlmProfile(
        id: id,
        name: name,
        provider: _provider,
        apiKey: _apiKeyCtrl.text.trim(),
        endpoint: endpoint,
        model: model,
        supportsVision: _supportsVision,
        supportsText: _supportsText,
      ),
    );
  }
}
