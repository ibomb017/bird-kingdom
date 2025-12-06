import 'package:flutter/material.dart';

import '../../models/encyclopedia.dart';
import '../../services/api_service.dart';
import 'voice_recognition_page.dart';

class EncyclopediaPage extends StatefulWidget {
  const EncyclopediaPage({super.key});

  @override
  State<EncyclopediaPage> createState() => _EncyclopediaPageState();
}

enum _EncyclopediaMode { encyclopedia, color, symptom }

class _EncyclopediaPageState extends State<EncyclopediaPage> {
  final ApiService _api = ApiService();
  _EncyclopediaMode _mode = _EncyclopediaMode.encyclopedia;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<BirdEncyclopedia> _birds = [];
  List<SymptomInfo> _symptoms = [];
  List<ColorGene> _colorGenes = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.getEncyclopediaBirds(),
        _api.getSymptoms(),
        _api.getColorGenes(),
      ]);
      setState(() {
        _birds = results[0] as List<BirdEncyclopedia>;
        _symptoms = results[1] as List<SymptomInfo>;
        _colorGenes = results[2] as List<ColorGene>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('加载失败', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(_error!, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadData, child: const Text('重试')),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _buildSearchBar(),
        const SizedBox(height: 16),
        _buildModeSwitcher(),
        const SizedBox(height: 20),
        _buildContent(),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _searchQuery = value),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        hintText: '搜索鸟种、症状或关键词',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildModeSwitcher() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildModeButton(
              '鸟类百科', Icons.menu_book_rounded, _EncyclopediaMode.encyclopedia),
          const SizedBox(width: 8),
          _buildModeButton('语音识别', Icons.graphic_eq_rounded, null),
          const SizedBox(width: 8),
          _buildModeButton(
              '配色预测', Icons.palette_rounded, _EncyclopediaMode.color),
          const SizedBox(width: 8),
          _buildModeButton(
              '症状查询', Icons.medical_services_rounded, _EncyclopediaMode.symptom),
        ],
      ),
    );
  }

  Widget _buildModeButton(
      String label, IconData icon, _EncyclopediaMode? mode) {
    final isSelected = mode != null && _mode == mode;
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color:
          isSelected ? colorScheme.primary.withOpacity(0.12) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (mode == null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const BirdVoiceRecognitionPage()),
            );
          } else {
            setState(() => _mode = mode);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 18,
                  color: isSelected ? colorScheme.primary : Colors.grey[600]),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: isSelected ? colorScheme.primary : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_mode) {
      case _EncyclopediaMode.encyclopedia:
        return _buildBirdList();
      case _EncyclopediaMode.color:
        return _buildColorPredict();
      case _EncyclopediaMode.symptom:
        return _buildSymptomList();
    }
  }

  // ==================== 鸟类百科 ====================

  Widget _buildBirdList() {
    final filtered = _searchQuery.isEmpty
        ? _birds
        : _birds.where((b) {
            final q = _searchQuery.toLowerCase();
            return b.name.toLowerCase().contains(q) ||
                (b.category?.toLowerCase().contains(q) ?? false) ||
                b.tags.any((t) => t.toLowerCase().contains(q));
          }).toList();

    if (filtered.isEmpty) {
      return _buildEmptyState('未找到相关鸟类');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('鸟类图鉴',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            Text('共 ${filtered.length} 种',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey[600])),
          ],
        ),
        const SizedBox(height: 12),
        ...filtered.map((bird) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _BirdCard(bird: bird),
            )),
      ],
    );
  }

  // ==================== 症状查询 ====================

  Widget _buildSymptomList() {
    final filtered = _searchQuery.isEmpty
        ? _symptoms
        : _symptoms.where((s) {
            final q = _searchQuery.toLowerCase();
            return s.name.toLowerCase().contains(q) ||
                (s.description?.toLowerCase().contains(q) ?? false) ||
                s.possibleCauses.any((c) => c.toLowerCase().contains(q));
          }).toList();

    if (filtered.isEmpty) {
      return _buildEmptyState('未找到相关症状');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.medical_services_rounded,
                color: Colors.red[400], size: 24),
            const SizedBox(width: 8),
            Text('症状速查',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        Text('点击症状查看详细信息',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey[600])),
        const SizedBox(height: 16),
        ...filtered.map((symptom) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SymptomCard(symptom: symptom),
            )),
        Card(
          color: Colors.red[50],
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.red[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '以上信息仅供参考，如症状严重请及时就医',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.red[900]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==================== 配色预测 ====================

  Widget _buildColorPredict() {
    return _ColorPredictWidget(colorGenes: _colorGenes);
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(message,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}

// ==================== 鸟类卡片 ====================

class _BirdCard extends StatelessWidget {
  const _BirdCard({required this.bird});
  final BirdEncyclopedia bird;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showDetail(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [bird.color, bird.color.withOpacity(0.6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.flutter_dash_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(bird.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Text(bird.category ?? '',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.grey[600])),
                      ],
                    ),
                    if (bird.scientificName != null)
                      Text(bird.scientificName!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey[500])),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: bird.tags
                          .take(3)
                          .map((tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                    color: bird.color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4)),
                                child: Text(tag,
                                    style: TextStyle(
                                        fontSize: 10, color: bird.color)),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [bird.color, bird.color.withOpacity(0.6)]),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.flutter_dash_rounded,
                        color: Colors.white, size: 40),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(bird.name,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        if (bird.scientificName != null)
                          Text(bird.scientificName!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey[600])),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                  spacing: 6,
                  children: bird.tags
                      .map((t) => Chip(
                          label: Text(t),
                          labelStyle: const TextStyle(fontSize: 12),
                          backgroundColor: bird.color.withOpacity(0.1),
                          side: BorderSide.none))
                      .toList()),
              const SizedBox(height: 20),
              if (bird.description != null)
                _DetailSection(
                    icon: Icons.info_outline,
                    title: '简介',
                    content: bird.description!,
                    color: bird.color),
              if (bird.feedingTips != null) ...[
                const SizedBox(height: 12),
                _DetailSection(
                    icon: Icons.restaurant,
                    title: '喂养要点',
                    content: bird.feedingTips!,
                    color: bird.color)
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  if (bird.habitat != null)
                    Expanded(
                        child: _InfoTile(
                            icon: Icons.public,
                            label: '原产地',
                            value: bird.habitat!,
                            color: bird.color)),
                  if (bird.lifespan != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                        child: _InfoTile(
                            icon: Icons.timer_outlined,
                            label: '平均寿命',
                            value: '${bird.lifespan} 年',
                            color: bird.color))
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== 症状卡片 ====================

class _SymptomCard extends StatelessWidget {
  const _SymptomCard({required this.symptom});
  final SymptomInfo symptom;

  Color get _severityColor {
    switch (symptom.severity) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  String get _severityText {
    switch (symptom.severity) {
      case 'high':
        return '需关注';
      case 'medium':
        return '一般';
      default:
        return '轻微';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetail(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: _severityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.healing_rounded, color: _severityColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(symptom.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: _severityColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4)),
                          child: Text(_severityText,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: _severityColor,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                    if (symptom.description != null)
                      Text(symptom.description!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        minChildSize: 0.4,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24))),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                          color: _severityColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14)),
                      child: Icon(Icons.healing_rounded,
                          color: _severityColor, size: 28)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(symptom.name,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: _severityColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4)),
                          child: Text('严重程度：$_severityText',
                              style: TextStyle(
                                  fontSize: 12, color: _severityColor)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (symptom.description != null) ...[
                const SizedBox(height: 16),
                Text(symptom.description!,
                    style: Theme.of(context).textTheme.bodyLarge)
              ],
              if (symptom.possibleCauses.isNotEmpty) ...[
                const SizedBox(height: 20),
                _ListSection(
                    icon: Icons.help_outline,
                    title: '可能原因',
                    items: symptom.possibleCauses,
                    color: Colors.blue)
              ],
              if (symptom.suggestions.isNotEmpty) ...[
                const SizedBox(height: 16),
                _ListSection(
                    icon: Icons.lightbulb_outline,
                    title: '处理建议',
                    items: symptom.suggestions,
                    color: Colors.green)
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== 配色预测 ====================

class _ColorPredictWidget extends StatefulWidget {
  const _ColorPredictWidget({required this.colorGenes});
  final List<ColorGene> colorGenes;

  @override
  State<_ColorPredictWidget> createState() => _ColorPredictWidgetState();
}

class _ColorPredictWidgetState extends State<_ColorPredictWidget> {
  ColorGene? _father;
  ColorGene? _mother;
  List<ColorPrediction>? _predictions;
  bool _isPredicting = false;

  Future<void> _predict() async {
    if (_father == null || _mother == null) return;
    setState(() => _isPredicting = true);
    try {
      final results =
          await ApiService().predictColor(_father!.code!, _mother!.code!);
      setState(() {
        _predictions = results;
        _isPredicting = false;
      });
    } catch (e) {
      setState(() => _isPredicting = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('预测失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('牡丹鹦鹉配色预测',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('选择父母羽色，预测后代可能的羽色',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey[600])),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: _ColorSelector(
                    label: '父亲羽色',
                    icon: Icons.male,
                    selected: _father,
                    genes: widget.colorGenes,
                    onSelect: (g) {
                      setState(() => _father = g);
                      _predict();
                    })),
            const SizedBox(width: 12),
            Expanded(
                child: _ColorSelector(
                    label: '母亲羽色',
                    icon: Icons.female,
                    selected: _mother,
                    genes: widget.colorGenes,
                    onSelect: (g) {
                      setState(() => _mother = g);
                      _predict();
                    })),
          ],
        ),
        const SizedBox(height: 20),
        if (_isPredicting)
          const Center(child: CircularProgressIndicator())
        else if (_predictions != null && _predictions!.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.auto_awesome,
                        color: Theme.of(context).colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text('预测结果',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600))
                  ]),
                  const SizedBox(height: 16),
                  ..._predictions!.map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                    color: p.color,
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: Colors.grey[300]!))),
                            const SizedBox(width: 12),
                            Expanded(child: Text(p.name)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(999)),
                              child: Text('${p.percentage}%',
                                  style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.palette_outlined,
                        size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text('请选择父母羽色',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.grey[600])),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Card(
          color: Colors.amber[50],
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                    child: Text('实际遗传结果受多种基因影响，此预测仅供参考',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.amber[900]))),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ColorSelector extends StatelessWidget {
  const _ColorSelector(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.genes,
      required this.onSelect});
  final String label;
  final IconData icon;
  final ColorGene? selected;
  final List<ColorGene> genes;
  final ValueChanged<ColorGene> onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showPicker(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(label,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey[600]))
              ]),
              const SizedBox(height: 12),
              if (selected != null)
                Column(children: [
                  Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: selected!.color,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!))),
                  const SizedBox(height: 6),
                  Text(selected!.name,
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center),
                ])
              else
                Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.add, color: Colors.grey[500])),
            ],
          ),
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('选择$label',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: genes
                  .map((g) => InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          onSelect(g);
                          Navigator.pop(context);
                        },
                        child: Column(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: g.color,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: selected == g
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.grey[300]!,
                                    width: selected == g ? 2 : 1),
                              ),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                                width: 60,
                                child: Text(g.name,
                                    style:
                                        Theme.of(context).textTheme.labelSmall,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ==================== 通用组件 ====================

class _DetailSection extends StatelessWidget {
  const _DetailSection(
      {required this.icon,
      required this.title,
      required this.content,
      required this.color});
  final IconData icon;
  final String title;
  final String content;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600, color: color))
          ]),
          const SizedBox(height: 8),
          Text(content,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(height: 1.5)),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ListSection extends StatelessWidget {
  const _ListSection(
      {required this.icon,
      required this.title,
      required this.items,
      required this.color});
  final IconData icon;
  final String title;
  final List<String> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600, color: color))
          ]),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        margin: const EdgeInsets.only(top: 6),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                            color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(item,
                            style: Theme.of(context).textTheme.bodyMedium)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
