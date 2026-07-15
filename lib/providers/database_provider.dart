import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/database_service.dart';

/// 数据库服务 Provider
/// 在应用中通过 ref.read(databaseProvider) 获取 DatabaseService 单例
final databaseProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});
