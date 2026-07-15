import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../models/patient.dart';
import '../models/medical_record.dart';
import 'database_provider.dart';

/// 患者列表 Provider（异步，返回全部患者）
/// 筛选由各页面自行处理，避免全局状态互相影响
final patientsProvider =
    AsyncNotifierProvider<PatientsNotifier, List<Patient>>(
  PatientsNotifier.new,
);

class PatientsNotifier extends AsyncNotifier<List<Patient>> {
  @override
  Future<List<Patient>> build() async {
    final db = ref.read(databaseProvider);
    return db.getPatients();
  }

  /// 新增患者
  Future<Id> addPatient(Patient patient) async {
    final db = ref.read(databaseProvider);
    final id = await db.addPatient(patient);
    ref.invalidateSelf();
    return id;
  }

  /// 更新患者
  Future<Id> updatePatient(Patient patient) async {
    final db = ref.read(databaseProvider);
    final id = await db.updatePatient(patient);
    ref.invalidateSelf();
    return id;
  }

  /// 删除患者（级联删除病历）
  Future<void> deletePatient(int id) async {
    final db = ref.read(databaseProvider);
    await db.deletePatient(id);
    ref.invalidateSelf();
  }
}

/// 某患者的病历列表 Provider
/// 通过 family 传入 patientId
final medicalRecordsProvider =
    FutureProvider.family<List<MedicalRecord>, int>((ref, patientId) async {
  final db = ref.read(databaseProvider);
  return db.getRecordsByPatient(patientId);
});
