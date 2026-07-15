import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/todo_item.dart';
import '../models/patient.dart';
import '../providers/todos_provider.dart';
import '../providers/patients_provider.dart';
import 'patient_detail_screen.dart';

/// 待办事项页
class TodoScreen extends ConsumerStatefulWidget {
  const TodoScreen({super.key});

  @override
  ConsumerState<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends ConsumerState<TodoScreen> {
  final _textController = TextEditingController();
  int? _selectedPatientId;
  final List<String> _filterOptions = const ['全部', '未完成', '已完成'];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Patient? _findPatientById(List<Patient> patients, int? id) {
    if (id == null) return null;
    for (final p in patients) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> _addTodo() async {
    final content = _textController.text.trim();
    if (content.isEmpty) return;

    final todo = TodoItem(
      patientId: _selectedPatientId,
      content: content,
      createdAt: DateTime.now(),
    );

    await ref.read(todosProvider.notifier).addTodo(todo);
    _textController.clear();
    setState(() => _selectedPatientId = null);
  }

  void _showPatientPicker() {
    final patientsAsync = ref.read(patientsProvider);
    patientsAsync.when(
      data: (patients) {
        showModalBottomSheet(
          context: context,
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.public),
                  title: const Text('通用待办（不关联患者）'),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _selectedPatientId = null);
                  },
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: patients.length,
                    itemBuilder: (ctx, index) {
                      final patient = patients[index];
                      return ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(patient.name),
                        subtitle:
                            Text('${patient.department} · ${patient.status}'),
                        onTap: () {
                          Navigator.pop(ctx);
                          setState(() => _selectedPatientId = patient.id);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () {},
      error: (_, _) {},
    );
  }

  void _showTodoMenu(TodoItem todo) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                todo.isCompleted ? Icons.undo : Icons.check_circle_outline,
              ),
              title: Text(todo.isCompleted ? '标记为未完成' : '标记为已完成'),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(todosProvider.notifier).toggleComplete(todo);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title:
                  const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(todosProvider.notifier).deleteTodo(todo.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final todosAsync = ref.watch(todosProvider);
    final filter = ref.watch(todoFilterProvider);
    final patientsAsync = ref.watch(patientsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('待办事项'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildQuickAddBar(),
          _buildFilterBar(filter),
          Expanded(
            child: todosAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('加载失败：$error')),
              data: (todos) {
                if (todos.isEmpty) {
                  return _buildEmptyState(filter);
                }
                return patientsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => _buildTodoList(todos, const []),
                  data: (patients) => _buildTodoList(todos, patients),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAddBar() {
    final patientsAsync = ref.watch(patientsProvider);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: const Color(0xFFF5F7FA),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: '输入待办内容，回车添加',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    onSubmitted: (_) => _addTodo(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _addTodo,
                icon: const Icon(Icons.add_circle,
                    color: Color(0xFF1677FF), size: 32),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              GestureDetector(
                onTap: _showPatientPicker,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _selectedPatientId != null
                        ? const Color(0xFF1677FF).withValues(alpha: 0.1)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 16,
                        color: _selectedPatientId != null
                            ? const Color(0xFF1677FF)
                            : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      patientsAsync.when(
                        data: (patients) {
                          final patient =
                              _findPatientById(patients, _selectedPatientId);
                          return Text(
                            patient?.name ?? '关联患者（可选）',
                            style: TextStyle(
                              fontSize: 12,
                              color: _selectedPatientId != null
                                  ? const Color(0xFF1677FF)
                                  : Colors.grey[600],
                            ),
                          );
                        },
                        loading: () => Text(
                          '加载中...',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        error: (_, _) => Text(
                          '关联患者（可选）',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_drop_down,
                        size: 18,
                        color: Colors.grey[500],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(String currentFilter) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SegmentedButton<String>(
        segments: _filterOptions
            .map((e) => ButtonSegment<String>(value: e, label: Text(e)))
            .toList(),
        selected: {currentFilter},
        onSelectionChanged: (Set<String> newSelection) {
          ref.read(todoFilterProvider.notifier).state = newSelection.first;
        },
        style: SegmentedButton.styleFrom(
          foregroundColor: Colors.grey[700],
          selectedForegroundColor: const Color(0xFF1677FF),
          selectedBackgroundColor:
              const Color(0xFF1677FF).withValues(alpha: 0.1),
        ),
      ),
    );
  }

  Widget _buildTodoList(List<TodoItem> todos, List<Patient> patients) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: todos.length,
      itemBuilder: (context, index) {
        final todo = todos[index];
        final patient = _findPatientById(patients, todo.patientId);
        return _buildTodoItem(todo, patient);
      },
    );
  }

  /// 格式化已过去的时间
  String _formatElapsedTime(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';
    if (diff.inDays < 365) return '${diff.inDays ~/ 30}个月前';
    return '${diff.inDays ~/ 365}年前';
  }

  Widget _buildTodoItem(TodoItem todo, Patient? patient) {
    final isCompleted = todo.isCompleted;

    // 患者状态颜色
    Color patientBadgeColor = const Color(0xFF1677FF);
    Color patientBadgeBg = const Color(0xFF1677FF).withValues(alpha: 0.1);
    String patientLabel = '';
    if (patient != null) {
      final bedNo = patient.bedNo;
      patientLabel = bedNo != null && bedNo.isNotEmpty
          ? '$bedNo床 ${patient.name}'
          : patient.name;
      switch (patient.status) {
        case '在院':
          patientBadgeColor = const Color(0xFF1677FF);
          patientBadgeBg = const Color(0xFF1677FF).withValues(alpha: 0.1);
          break;
        case '预出院':
          patientBadgeColor = const Color(0xFFFF8C00);
          patientBadgeBg = const Color(0xFFFF8C00).withValues(alpha: 0.1);
          break;
        case '出院':
          patientBadgeColor = const Color(0xFF8C8C8C);
          patientBadgeBg = const Color(0xFF8C8C8C).withValues(alpha: 0.12);
          break;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onLongPress: () => _showTodoMenu(todo),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: isCompleted,
                    onChanged: (_) {
                      ref.read(todosProvider.notifier).toggleComplete(todo);
                    },
                    activeColor: const Color(0xFF1677FF),
                    shape: const CircleBorder(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        todo.content,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: isCompleted
                              ? Colors.grey[500]
                              : Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            _formatElapsedTime(todo.createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[400],
                            ),
                          ),
                          if (patient != null) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PatientDetailScreen(
                                      patientId: patient.id,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: patientBadgeBg,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  patientLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: patientBadgeColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String filter) {
    String message;
    IconData icon;
    if (filter == '全部') {
      message = '暂无待办事项\n点击上方输入框添加';
      icon = Icons.check_circle_outline;
    } else if (filter == '未完成') {
      message = '没有未完成的待办\n太棒了！';
      icon = Icons.celebration_outlined;
    } else {
      message = '还没有已完成的待办';
      icon = Icons.inventory_2_outlined;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
