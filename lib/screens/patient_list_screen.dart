import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/patients_provider.dart';
import '../widgets/patient_card.dart';
import '../widgets/add_patient_sheet.dart';
import 'patient_detail_screen.dart';

/// 患者列表页
/// 单列卡片列表 + SegmentedButton 筛选 + FAB 新增
class PatientListScreen extends ConsumerStatefulWidget {
  const PatientListScreen({super.key});

  @override
  ConsumerState<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends ConsumerState<PatientListScreen> {
  String _filter = '全部';

  @override
  Widget build(BuildContext context) {
    final patientsAsync = ref.watch(patientsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('患者库'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: '全部', label: Text('全部')),
                ButtonSegment(value: '在院', label: Text('在院')),
                ButtonSegment(value: '预出院', label: Text('预出院')),
                ButtonSegment(value: '出院', label: Text('出院')),
              ],
              selected: {_filter},
              onSelectionChanged: (Set<String> selected) {
                setState(() {
                  _filter = selected.first;
                });
              },
            ),
          ),
          Expanded(
            child: patientsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, stack) => Center(
                child: Text('加载失败：$error'),
              ),
              data: (patients) {
                // 本地筛选
                final filtered = _filter == '全部'
                    ? patients
                    : patients.where((p) => p.status == _filter).toList();

                if (filtered.isEmpty) {
                  return _buildEmptyState();
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(patientsProvider);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final patient = filtered[index];
                      return PatientCard(
                        patient: patient,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PatientDetailScreen(patientId: patient.id),
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          AddPatientSheet.show(context);
        },
        backgroundColor: const Color(0xFF1677FF),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            '暂无患者记录',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右下角 + 添加患者',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }
}
