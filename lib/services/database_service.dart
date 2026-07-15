import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../models/patient.dart';
import '../models/medical_record.dart';
import '../models/todo_item.dart';

/// 数据库服务（单例模式）
/// 封装 Isar 数据库的所有操作，包括患者和病历的增删改查
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  late Isar _isar;
  bool _initialized = false;

  /// 获取 Isar 实例
  Isar get isar {
    if (!_initialized) {
      throw StateError('DatabaseService 尚未初始化，请先调用 init()');
    }
    return _isar;
  }

  /// 初始化 Isar 数据库
  /// 注册 Patient 和 MedicalRecord Schema
  Future<void> init() async {
    if (_initialized) return;

    // Web 平台使用默认目录，原生平台使用应用文档目录
    String dirPath = '';
    if (!kIsWeb) {
      final dir = await getApplicationDocumentsDirectory();
      dirPath = dir.path;
    }

    _isar = await Isar.open(
      [PatientSchema, MedicalRecordSchema, TodoItemSchema],
      directory: dirPath,
    );
    _initialized = true;
  }

  // ==================== 患者相关操作 ====================

  /// 新增患者
  /// 返回新增记录的自增 ID
  Future<Id> addPatient(Patient patient) async {
    return await _isar.writeTxn(() async {
      return await _isar.patients.put(patient);
    });
  }

  /// 获取患者列表
  /// [status] 可选状态筛选（在院/出院），不传则返回全部
  Future<List<Patient>> getPatients({String? status}) async {
    return await _isar.txn(() async {
      if (status != null) {
        return await _isar.patients
            .filter()
            .statusEqualTo(status)
            .sortByCreatedAtDesc()
            .findAll();
      }
      return await _isar.patients.where().sortByCreatedAtDesc().findAll();
    });
  }

  /// 更新患者信息
  /// 传入已存在的 Patient 对象（需包含 id）即可更新
  Future<Id> updatePatient(Patient patient) async {
    return await _isar.writeTxn(() async {
      return await _isar.patients.put(patient);
    });
  }

  /// 删除患者（级联删除其所有病历记录）
  /// [id] 患者 ID
  Future<void> deletePatient(int id) async {
    await _isar.writeTxn(() async {
      // 先删除该患者的所有病历记录
      await _isar.medicalRecords.filter().patientIdEqualTo(id).deleteAll();
      // 再删除患者本身
      await _isar.patients.delete(id);
    });
  }

  // ==================== 病历相关操作 ====================

  /// 新增病历记录
  /// 返回新增记录的自增 ID
  Future<Id> addMedicalRecord(MedicalRecord record) async {
    return await _isar.writeTxn(() async {
      return await _isar.medicalRecords.put(record);
    });
  }

  /// 获取某患者的所有病历记录（按创建时间倒序）
  /// [patientId] 患者 ID
  Future<List<MedicalRecord>> getRecordsByPatient(int patientId) async {
    return await _isar.txn(() async {
      return await _isar.medicalRecords
          .filter()
          .patientIdEqualTo(patientId)
          .sortByCreatedAtDesc()
          .findAll();
    });
  }

  // ==================== 待办事项相关操作 ====================

  /// 新增待办事项
  Future<Id> addTodo(TodoItem todo) async {
    return await _isar.writeTxn(() async {
      return await _isar.todoItems.put(todo);
    });
  }

  /// 更新待办事项
  Future<Id> updateTodo(TodoItem todo) async {
    return await _isar.writeTxn(() async {
      return await _isar.todoItems.put(todo);
    });
  }

  /// 删除待办事项
  Future<void> deleteTodo(int id) async {
    await _isar.writeTxn(() async {
      await _isar.todoItems.delete(id);
    });
  }

  /// 获取待办列表
  /// [completed] 可选筛选：true=已完成，false=未完成，null=全部
  Future<List<TodoItem>> getTodos({bool? completed}) async {
    return await _isar.txn(() async {
      final all = await _isar.todoItems.where().findAll();
      if (completed == null) {
        // 未完成在前，已完成在后；同组内按创建时间倒序
        all.sort((a, b) {
          if (a.isCompleted != b.isCompleted) {
            return a.isCompleted ? 1 : -1;
          }
          return b.createdAt.compareTo(a.createdAt);
        });
        return all;
      }
      final filtered = all.where((t) => t.isCompleted == completed).toList();
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return filtered;
    });
  }

  /// 获取某患者关联的待办事项
  Future<List<TodoItem>> getTodosByPatient(int patientId) async {
    return await _isar.txn(() async {
      final all = await _isar.todoItems.where().findAll();
      final filtered = all.where((t) => t.patientId == patientId).toList();
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return filtered;
    });
  }

  /// 获取未完成待办数量
  Future<int> getPendingTodoCount() async {
    return await _isar.txn(() async {
      final all = await _isar.todoItems.where().findAll();
      return all.where((t) => !t.isCompleted).length;
    });
  }
}
