import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/patient.dart';
import '../models/medical_record.dart';
import '../models/todo_item.dart';
import '../providers/patients_provider.dart';
import '../providers/todos_provider.dart';
import '../services/database_service.dart';
import '../widgets/record_card.dart';
import '../widgets/add_patient_sheet.dart';
import 'record_edit_screen.dart';
import 'record_preview_screen.dart';

/// 患者详情页
/// 顶部信息卡 + TabBar 切换病历类型
class PatientDetailScreen extends ConsumerStatefulWidget {
  final int patientId;

  const PatientDetailScreen({
    super.key,
    required this.patientId,
  });

  @override
  ConsumerState<PatientDetailScreen> createState() =>
      _PatientDetailScreenState();
}

class _PatientDetailScreenState extends ConsumerState<PatientDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const List<String> _tabs = [
    '全部病历',
    '入院记录',
    '首次病程',
    '日常病程',
    '手术记录',
    '待办',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Patient? _findPatient(List<Patient> patients) {
    for (final p in patients) {
      if (p.id == widget.patientId) return p;
    }
    return null;
  }

  Future<void> _showDeleteConfirm(Patient patient) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除患者「${patient.name}」吗？\n该患者的所有病历记录将一并删除，此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(patientsProvider.notifier).deletePatient(patient.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientsAsync = ref.watch(patientsProvider);
    final recordsAsync = ref.watch(medicalRecordsProvider(widget.patientId));

    return patientsAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('患者详情')),
        body: Center(child: Text('加载失败：$error')),
      ),
      data: (patients) {
        final patient = _findPatient(patients);
        if (patient == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('患者详情')),
            body: const Center(child: Text('患者不存在')),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(patient.name),
            centerTitle: true,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: '编辑患者',
                onPressed: () {
                  AddPatientSheet.show(context, patient: patient);
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: '删除患者',
                onPressed: () => _showDeleteConfirm(patient),
              ),
            ],
          ),
          body: Column(
            children: [
              _buildPatientInfoCard(patient),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: const Color(0xFF1677FF),
                unselectedLabelColor: Colors.grey[600],
                indicatorColor: const Color(0xFF1677FF),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                tabs: _tabs
                    .map((t) => Tab(text: t))
                    .toList(),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: _tabs.map((tab) {
                    if (tab == '待办') {
                      return _buildTodoTab(patient);
                    }
                    final records = recordsAsync.value ?? [];
                    return _buildRecordsTab(records, patient, tab);
                  }).toList(),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              final currentTab = _tabs[_tabController.index];
              if (currentTab == '待办') {
                _showAddTodoSheet(patient.id);
              } else {
                final type = currentTab == '全部病历' ? '日常病程' : currentTab;
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecordEditScreen(
                      patientId: patient.id,
                      initialType: type,
                    ),
                  ),
                );
                if (result == true) {
                  ref.invalidate(medicalRecordsProvider(patient.id));
                }
              }
            },
            icon: const Icon(Icons.add),
            label: Text(
              _tabController.index == _tabs.length - 1
                  ? '新增待办'
                  : '新增病历',
            ),
            backgroundColor: const Color(0xFF1677FF),
            foregroundColor: Colors.white,
          ),
        );
      },
    );
  }

  Widget _buildPatientInfoCard(Patient patient) {
    final dateStr =
        DateFormat('yyyy-MM-dd').format(patient.admissionDate);
    final isInHospital = patient.status == '在院';
    final isPreDischarge = patient.status == '预出院';
    final isDischarged = patient.status == '出院';

    // 根据状态选择渐变色
    Color primaryColor;
    if (isPreDischarge) {
      primaryColor = const Color(0xFFFF8C00);
    } else if (isDischarged) {
      primaryColor = const Color(0xFF8C8C8C);
    } else {
      primaryColor = const Color(0xFF1677FF);
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor,
            primaryColor.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                patient.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: isInHospital
                      ? Colors.white.withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  patient.status,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildInfoRow(Icons.person_outline,
              '${patient.gender} · ${patient.age}岁'),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.local_hospital_outlined, patient.department),
          if (patient.bedNo != null && patient.bedNo!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow(Icons.bed_outlined, '${patient.bedNo} 床'),
          ],
          const SizedBox(height: 8),
          _buildInfoRow(Icons.event_outlined, '入院时间：$dateStr'),
          const SizedBox(height: 16),
          // 预出院/取消预出院按钮
          if (isInHospital) _buildPreDischargeButton(patient, true),
          if (isPreDischarge) _buildPreDischargeButton(patient, false),
        ],
      ),
    );
  }

  Widget _buildPreDischargeButton(Patient patient, bool isSetPreDischarge) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _togglePreDischarge(patient, isSetPreDischarge),
        icon: Icon(
          isSetPreDischarge ? Icons.logout : Icons.undo,
          size: 18,
          color: Colors.white,
        ),
        label: Text(
          isSetPreDischarge ? '标记为预出院' : '取消预出院',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.white70, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Future<void> _togglePreDischarge(Patient patient, bool isSetPreDischarge) async {
    final action = isSetPreDischarge ? '标记预出院' : '取消预出院';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('确认$action'),
        content: Text('确定要将患者「${patient.name}」$action吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final updated = Patient(
        id: patient.id,
        name: patient.name,
        gender: patient.gender,
        age: patient.age,
        bedNo: patient.bedNo,
        department: patient.department,
        admissionDate: patient.admissionDate,
        status: isSetPreDischarge ? '预出院' : '在院',
        createdAt: patient.createdAt,
      );
      await ref.read(patientsProvider.notifier).updatePatient(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$action成功')),
        );
      }
    }
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white70),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  /// 病历 Tab 内容
  Widget _buildRecordsTab(
    List<MedicalRecord> allRecords,
    Patient patient,
    String tab,
  ) {
    final type = tab == '全部病历' ? null : tab;
    final filtered = type == null
        ? allRecords
        : allRecords.where((r) => r.type == type).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 12),
            Text(
              '暂无$tab',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final record = filtered[index];
        return RecordCard(
          record: record,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RecordPreviewScreen(
                  record: record,
                  patientName: patient.name,
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 待办 Tab 内容
  Widget _buildTodoTab(Patient patient) {
    final todosAsync = ref.watch(patientTodosProvider(patient.id));

    return todosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('加载失败：$error')),
      data: (todos) {
        if (todos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.checklist_outlined,
                  size: 64,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 12),
                Text(
                  '暂无待办事项',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '点击右下角按钮添加',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: todos.length,
          itemBuilder: (context, index) {
            final todo = todos[index];
            return _buildTodoItem(todo);
          },
        );
      },
    );
  }

  Widget _buildTodoItem(TodoItem todo) {
    final isCompleted = todo.isCompleted;
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
                      _toggleTodo(todo);
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
                      Text(
                        DateFormat('MM-dd HH:mm').format(todo.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[400],
                        ),
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

  void _showAddTodoSheet(int patientId) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '新增待办',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: '输入待办内容...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final content = controller.text.trim();
                        if (content.isEmpty) return;
                        final todo = TodoItem(
                          patientId: patientId,
                          content: content,
                          createdAt: DateTime.now(),
                        );
                        final db = DatabaseService();
                        await db.addTodo(todo);
                        ref.invalidate(patientTodosProvider(patientId));
                        ref.invalidate(pendingTodoCountProvider);
                        ref.invalidate(todosProvider);
                        if (mounted && context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1677FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('添加'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
                _toggleTodo(todo);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteTodo(todo);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleTodo(TodoItem todo) async {
    final db = DatabaseService();
    final updated = TodoItem(
      id: todo.id,
      patientId: todo.patientId,
      content: todo.content,
      isCompleted: !todo.isCompleted,
      createdAt: todo.createdAt,
      completedAt: !todo.isCompleted ? DateTime.now() : null,
    );
    await db.updateTodo(updated);
    if (todo.patientId != null) {
      ref.invalidate(patientTodosProvider(todo.patientId!));
    }
    ref.invalidate(pendingTodoCountProvider);
    ref.invalidate(todosProvider);
  }

  Future<void> _deleteTodo(TodoItem todo) async {
    final db = DatabaseService();
    await db.deleteTodo(todo.id);
    if (todo.patientId != null) {
      ref.invalidate(patientTodosProvider(todo.patientId!));
    }
    ref.invalidate(pendingTodoCountProvider);
    ref.invalidate(todosProvider);
  }
}
