// 轻量 i18n：中英两套字典，避免引入代码生成
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

class AppStrings {
  const AppStrings({
    required this.appName,
    required this.newConversation,
    required this.searchConversation,
    required this.conversations,
    required this.untitled,
    required this.messageCount,
    required this.rename,
    required this.delete,
    required this.cancel,
    required this.save,
    required this.retry,
    required this.loadFailed,
    required this.noConversations,
    required this.characters,
    required this.noCharacters,
    required this.switchedToCharacter,
    required this.tools,
    required this.ttsStudio,
    required this.sttStudio,
    required this.settings,
    required this.llmSettings,
    required this.ttsEngine,
    required this.userSettings,
    required this.readAloud,
    required this.accessToken,
    required this.language,
    required this.debugLogs,
    required this.server,
    required this.disconnect,
    required this.phone,
    required this.comingSoon,
    required this.currentCharacter,
    required this.avatar,
  });

  final String appName;
  final String newConversation;
  final String searchConversation;
  final String conversations;
  final String untitled;
  final String messageCount;
  final String rename;
  final String delete;
  final String cancel;
  final String save;
  final String retry;
  final String loadFailed;
  final String noConversations;
  final String characters;
  final String noCharacters;
  final String switchedToCharacter;
  final String tools;
  final String ttsStudio;
  final String sttStudio;
  final String settings;
  final String llmSettings;
  final String ttsEngine;
  final String userSettings;
  final String readAloud;
  final String accessToken;
  final String language;
  final String debugLogs;
  final String server;
  final String disconnect;
  final String phone;
  final String comingSoon;
  final String currentCharacter;
  final String avatar;

  static const zh = AppStrings(
    appName: 'Talk With Anyone',
    newConversation: '新建对话',
    searchConversation: '搜索会话',
    conversations: '会话',
    untitled: '（未命名）',
    messageCount: '条消息',
    rename: '重命名',
    delete: '删除',
    cancel: '取消',
    save: '保存',
    retry: '重试',
    loadFailed: '加载失败',
    noConversations: '还没有会话',
    characters: '角色',
    noCharacters: '还没有角色',
    switchedToCharacter: '已切换到',
    tools: '工具',
    ttsStudio: '语音合成',
    sttStudio: '语音转文本',
    settings: '设置',
    llmSettings: 'LLM 设置',
    ttsEngine: 'TTS 引擎',
    userSettings: '用户设置',
    readAloud: '朗读工具箱',
    accessToken: '访问口令',
    language: '语言',
    debugLogs: '调试日志',
    server: '当前服务器',
    disconnect: '断开连接',
    phone: '电话',
    comingSoon: '该功能即将推出',
    currentCharacter: '当前角色',
    avatar: '头像',
  );

  static const en = AppStrings(
    appName: 'Talk With Anyone',
    newConversation: 'New Chat',
    searchConversation: 'Search chats',
    conversations: 'Conversations',
    untitled: '(Untitled)',
    messageCount: 'messages',
    rename: 'Rename',
    delete: 'Delete',
    cancel: 'Cancel',
    save: 'Save',
    retry: 'Retry',
    loadFailed: 'Failed to load',
    noConversations: 'No conversations yet',
    characters: 'Characters',
    noCharacters: 'No characters yet',
    switchedToCharacter: 'Switched to',
    tools: 'Tools',
    ttsStudio: 'TTS Studio',
    sttStudio: 'STT Studio',
    settings: 'Settings',
    llmSettings: 'LLM Settings',
    ttsEngine: 'TTS Engine',
    userSettings: 'User Settings',
    readAloud: 'Read Aloud',
    accessToken: 'Access Token',
    language: 'Language',
    debugLogs: 'Debug Logs',
    server: 'Server',
    disconnect: 'Disconnect',
    phone: 'Call',
    comingSoon: 'Coming soon',
    currentCharacter: 'Current character',
    avatar: 'Avatar',
  );
}

extension AppStringsCtx on BuildContext {
  AppStrings get strs {
    final isEn = watch<AppState>().isEn;
    return isEn ? AppStrings.en : AppStrings.zh;
  }
}
