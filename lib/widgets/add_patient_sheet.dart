import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/patient.dart';
import '../providers/patients_provider.dart';

/// 新增/编辑患者底部弹窗
/// 支持新增和编辑两种模式，通过 [patient] 区分
class AddPatientSheet extends ConsumerStatefulWidget {
  final Patient? patient;

  const AddPatientSheet({
    super.key,
    this.patient,
  });

  static Future<void> show(BuildContext context, {Patient? patient}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddPatientSheet(patient: patient),
    );
  }

  @override
  ConsumerState<AddPatientSheet> createState() => _AddPatientSheetState();
}

class _AddPatientSheetState extends ConsumerState<AddPatientSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _bedNoController;
  late String _gender;
  late String _department;
  late DateTime _admissionDate;
  late String _status;
  bool _isSubmitting = false;

  bool get _isEdit => widget.patient != null;

  @override
  void initState() {
    super.initState();
    final p = widget.patient;
    _nameController = TextEditingController(text: p?.name ?? '');
    _ageController = TextEditingController(text: p?.age.toString() ?? '');
    _bedNoController = TextEditingController(text: p?.bedNo ?? '');
    _gender = p?.gender ?? '男';
    _department = p?.department ?? '内科';
    _admissionDate = p?.admissionDate ?? DateTime.now();
    _status = p?.status ?? '在院';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _bedNoController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _admissionDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _admissionDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final now = DateTime.now();
      if (_isEdit) {
        final updated = Patient(
          id: widget.patient!.id,
          name: _nameController.text.trim(),
          gender: _gender,
          age: int.parse(_ageController.text),
          bedNo: _bedNoController.text.trim().isEmpty
              ? null
              : _bedNoController.text.trim(),
          department: _department,
          admissionDate: _admissionDate,
          status: _status,
          createdAt: widget.patient!.createdAt,
        );
        await ref.read(patientsProvider.notifier).updatePatient(updated);
      } else {
        final patient = Patient(
          name: _nameController.text.trim(),
          gender: _gender,
          age: int.parse(_ageController.text),
          bedNo: _bedNoController.text.trim().isEmpty
              ? null
              : _bedNoController.text.trim(),
          department: _department,
          admissionDate: _admissionDate,
          status: _status,
          createdAt: now,
        );
        await ref.read(patientsProvider.notifier).addPatient(patient);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy-MM-dd').format(_admissionDate);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.6,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF5F7FA),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      _isEdit ? '编辑患者信息' : '新增患者',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    children: [
                      _buildSection('基本信息'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        label: '姓名',
                        controller: _nameController,
                        hintText: '请输入姓名',
                        validator: (v) =>
                            v?.isEmpty ?? true ? '请输入姓名' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdown(
                              label: '性别',
                              value: _gender,
                              items: const ['男', '女'],
                              onChanged: (v) =>
                                  setState(() => _gender = v!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              label: '年龄',
                              controller: _ageController,
                              hintText: '岁',
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v?.isEmpty ?? true) return '请输入年龄';
                                if (int.tryParse(v!) == null) return '请输入数字';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildDropdown(
                        label: '科室',
                        value: _department,
                        items: const ['内科', '外科', '儿科', '妇产科', '其他'],
                        onChanged: (v) =>
                            setState(() => _department = v!),
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        label: '床号（选填）',
                        controller: _bedNoController,
                        hintText: '例如：12',
                      ),
                      const SizedBox(height: 20),
                      _buildSection('住院信息'),
                      const SizedBox(height: 8),
                      _buildDateField(dateStr),
                      const SizedBox(height: 12),
                      _buildDropdown(
                        label: '状态',
                        value: _status,
                        items: const ['在院', '预出院', '出院'],
                        onChanged: (v) =>
                            setState(() => _status = v!),
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submit,
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _isEdit ? '保存修改' : '确认添加',
                                  style: const TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hintText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hintText,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildDateField(String dateStr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '入院日期',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 18, color: Color(0xFF1677FF)),
                const SizedBox(width: 10),
                Text(
                  dateStr,
                  style: const TextStyle(fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
