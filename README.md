# AuscultPen 听诊笔

AuscultPen（听诊笔）是一款专为住院医师打造的智能病历管理APP。基于Flutter与Material 3设计，支持语音生成大病历与首程、拍照上传病历、AI解析检验检查及待办事项管理，助力临床工作高效完成。应用采用本地存储机制，严格保障患者隐私安全。旨在解放医生双手，简化文书负担，让住院医师更专注于诊疗本身。

## 功能特性

- **首页仪表盘** — 在院 / 预出院 / 出院患者统计、最近动态、快捷操作入口
- **患者库管理** — 患者信息增删改查、按状态筛选、床位号管理
- **添加记录** — 支持手动输入、语音录入、拍照识别三种方式
- **AI 处理**
  - 生成病历 — 根据口语化描述生成结构化病历
  - 润色内容 — 规范医学术语，优化表达
  - 解析报告 — 解析检验检查图片，提取结构化结果
- **语音转文字** — 录音实时转写，基于阿里云 Paraformer-v2 模型
- **拍照识别** — 拍摄病历 / 检查结果，AI 自动识别并智能匹配患者
- **待办事项** — 按患者关联的待办管理，支持状态排序与时间显示
- **多模态附件** — 支持音频、图片附件，附件预览与 AI 解析

## 技术栈

| 分类 | 技术 |
|------|------|
| 框架 | Flutter |
| 本地数据库 | Isar |
| AI 服务 | 阿里通义千问大模型 |

## 项目结构

```
lib/
├── main.dart                    # 应用入口、主题配置
├── models/                      # 数据模型
│   ├── patient.dart
│   ├── medical_record.dart
│   └── todo_item.dart
├── providers/                   # Riverpod 状态管理
│   ├── patients_provider.dart
│   ├── settings_provider.dart
│   ├── todos_provider.dart
│   └── database_provider.dart
├── services/                    # 业务服务层
│   ├── ai_service.dart          # AI 接口调用
│   ├── database_service.dart    # Isar 数据库操作
│   └── media_service.dart       # 音频/图片媒体服务
├── screens/                     # 页面
│   ├── dashboard_screen.dart    # 首页仪表盘
│   ├── patient_list_screen.dart # 患者库
│   ├── patient_detail_screen.dart
│   ├── record_edit_screen.dart  # 添加/编辑记录
│   ├── record_preview_screen.dart
│   ├── attachment_preview_screen.dart
│   ├── todo_screen.dart         # 待办事项
│   ├── settings_screen.dart     # 设置
│   └── home_screen.dart         # 底部导航框架
└── widgets/                     # 可复用组件
    ├── patient_card.dart
    ├── record_card.dart
    └── add_patient_sheet.dart
```

## 快速开始

### 环境要求

- Flutter 3.x（建议 3.12+）
- Dart 3.x
- Android SDK（构建 Android 版本）
- JDK 17+

### 配置 AI 服务

首次使用前，请在应用内 **设置** 页面配置阿里云 DashScope API Key：

1. 前往 [阿里云百炼控制台](https://dashscope.console.aliyun.com/) 获取 API Key
2. 打开应用 → 设置 → 填入 API Key
3. 可选：在设置中选择默认使用的通义千问模型

> 注：API Key 仅存储在本地 SharedPreferences 中，不会上传到服务器。

## 使用说明

1. **添加患者** — 在「患者库」中点击添加，填写姓名、床位号、科室、状态
2. **创建记录** — 点击底部「添加记录」，选择或新建患者后开始记录
3. **语音录入** — 点击麦克风图标开始录音，再次点击停止，可转写为文字
4. **拍照识别** — 点击相机图标拍照或选择图片，AI 自动识别内容
5. **AI 处理** — 在记录编辑页点击「AI 处理」，选择生成病历 / 润色 / 解析报告
6. **待办管理** — 在患者详情中创建待办事项，首页仪表盘汇总展示

## 平台支持

目前本项目仅提供Android版本，可在Release中下载，Windows/iOS版本可自行构建。

## 开源许可

本项目基于 [Apache License 2.0](LICENSE) 开源。

Copyright © 2016-2026 Torway Studio. All rights reserved.

## 免责声明

本应用生成的所有内容（包括但不限于病历文本、检验报告解析、语音转写等）均由人工智能大模型自动生成，仅供参考。请结合临床实际情况和专业知识进行判断和修改，开发者（Torway Studio）不对此承担责任，使用者需对最终内容承担责任。
为保证隐私安全，本应用数据库存储于设备本地，不会上传到服务器。