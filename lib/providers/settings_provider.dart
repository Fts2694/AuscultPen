import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 设置状态管理
/// 管理 API Key、多媒体配置、数据管理等所有持久化配置
class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(SettingsState());

  // ==================== Key 常量 ====================
  static const String _kDashScopeApiKey = 'dashscope_api_key';
  static const String _kDefaultModel = 'default_model';
  static const String _kImageQuality = 'image_quality';
  static const String _kAutoSaveDraft = 'auto_save_draft';
  static const String _kUserTitle = 'user_title';

  // ==================== 初始化 ====================
  /// 初始化，从 SharedPreferences 读取所有配置
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      dashScopeApiKey: prefs.getString(_kDashScopeApiKey) ?? '',
      defaultModel: prefs.getString(_kDefaultModel) ?? 'qwen-turbo',
      imageQuality: prefs.getInt(_kImageQuality) ?? 80,
      autoSaveDraft: prefs.getBool(_kAutoSaveDraft) ?? true,
      userTitle: prefs.getString(_kUserTitle) ?? '医生',
    );
  }

  // ==================== AI 服务配置 ====================
  /// 设置 DashScope API Key
  Future<void> setDashScopeApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDashScopeApiKey, key);
    state = state.copyWith(dashScopeApiKey: key);
  }

  /// 清除 API Key
  Future<void> clearApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kDashScopeApiKey);
    state = state.copyWith(dashScopeApiKey: '');
  }

  /// 设置默认病历模型
  Future<void> setDefaultModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDefaultModel, model);
    state = state.copyWith(defaultModel: model);
  }

  // ==================== 多媒体配置 ====================
  /// 设置图片压缩质量
  Future<void> setImageQuality(int quality) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kImageQuality, quality);
    state = state.copyWith(imageQuality: quality);
  }

  /// 设置自动保存草稿
  Future<void> setAutoSaveDraft(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoSaveDraft, value);
    state = state.copyWith(autoSaveDraft: value);
  }

  // ==================== 个性化配置 ====================
  /// 设置用户称呼
  Future<void> setUserTitle(String title) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserTitle, title);
    state = state.copyWith(userTitle: title);
  }
}

class SettingsState {
  // AI 服务配置
  final String dashScopeApiKey;
  final String defaultModel;

  // 多媒体配置
  final int imageQuality;
  final bool autoSaveDraft;

  // 个性化配置
  final String userTitle;

  SettingsState({
    this.dashScopeApiKey = '',
    this.defaultModel = 'qwen-turbo',
    this.imageQuality = 80,
    this.autoSaveDraft = true,
    this.userTitle = '医生',
  });

  SettingsState copyWith({
    String? dashScopeApiKey,
    String? defaultModel,
    int? imageQuality,
    bool? autoSaveDraft,
    String? userTitle,
  }) {
    return SettingsState(
      dashScopeApiKey: dashScopeApiKey ?? this.dashScopeApiKey,
      defaultModel: defaultModel ?? this.defaultModel,
      imageQuality: imageQuality ?? this.imageQuality,
      autoSaveDraft: autoSaveDraft ?? this.autoSaveDraft,
      userTitle: userTitle ?? this.userTitle,
    );
  }

  /// 是否已配置 API Key
  bool get hasApiKey => dashScopeApiKey.isNotEmpty;

  /// 可用的模型列表（阿里千问）
  static const List<String> availableModels = [
    'qwen-turbo',
    'qwen-plus',
    'qwen-max',
    'qwen3-turbo',
    'qwen3-plus',
    'qwen3-max',
  ];
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});
