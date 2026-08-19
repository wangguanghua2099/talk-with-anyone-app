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
    required this.confirmDeleteConversation,
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
    required this.customVoice,
    required this.settings,
    required this.llmSettings,
    required this.ttsEngine,
    required this.userSettings,
    required this.readAloud,
    required this.llmBackend,
    required this.backendLocal,
    required this.backendOpenai,
    required this.apiUrl,
    required this.apiKeyMasked,
    required this.model,
    required this.refreshModels,
    required this.selectModel,
    required this.saveLLM,
    required this.llmSaved,
    required this.language,
    required this.server,
    required this.disconnect,
    required this.phone,
    required this.currentCharacter,
    required this.avatar,
    required this.userName,
    required this.saveUserName,
    required this.userRolePrompt,
    required this.defaultUserRole,
    required this.saveUserRole,
    required this.saveUserVoice,
    required this.selectAvatar,
    required this.chooseFromDevice,
    required this.avatarUploaded,
    required this.enterUserName,
    required this.userNameSaved,
    required this.userRoleSaved,
    required this.userVoiceSaved,
    required this.saved,
    required this.characterName,
    required this.saveCharacterName,
    required this.characterAvatar,
    required this.aiRolePrompt,
    required this.saveAiRolePrompt,
    required this.characterVoice,
    required this.saveCharacterVoice,
    required this.addCharacter,
    required this.deleteCharacter,
    required this.confirmDeleteCharacter,
    required this.characterNameRequired,
    required this.characterCreated,
    required this.characterDeleted,
    required this.characterSaved,
    required this.aiAvatarSaved,
    // 通用
    required this.colon,
    required this.questionSuffix,
    required this.nameQuoteL,
    required this.nameQuoteR,
    required this.failedPrefix,
    required this.notConnected,
    required this.noVoices,
    required this.saveFailed,
    required this.deleteFailed,
    required this.stopReading,
    required this.noSpeechDetected,
    required this.webSaveUnsupported,
    required this.savedPathPrefix,
    required this.offlineModeBanner,
    required this.networkRequired,
    // 朗读工具箱
    required this.readWeb,
    required this.webUrlHint,
    required this.readText,
    required this.readTextHint,
    required this.enterWebUrl,
    required this.noWebContent,
    required this.fetchWebFailed,
    required this.enterReadText,
    required this.readFailed,
    // 语音转文本
    required this.sttDefaultStatus,
    required this.micOff,
    required this.micStartFailed,
    required this.transcribeDone,
    required this.transcribeFailed,
    required this.noTextToSave,
    required this.noTextToCopy,
    required this.copied,
    required this.sttRecognitionHint,
    required this.charCount,
    required this.saveTxt,
    required this.copy,
    required this.clear,
    required this.uploadAudio,
    required this.sttTimeHint,
    // 语音合成
    required this.switchEngineFailed,
    required this.voiceLoadFailed,
    required this.enterSynthText,
    required this.synthFailed,
    required this.audioSaved,
    required this.voiceLabel,
    required this.synthTextHint,
    required this.synthesize,
    required this.stop,
    required this.saveAudio,
    // TTS 引擎
    required this.switchEngineOk,
    required this.currentEnginePrefix,
    required this.voicesPrefix,
    required this.currentEngine,
    required this.voiceSep,
    // 头像/上传
    required this.imageProcessFailed,
    required this.uploadFailed,
    // 自定义音色
    required this.addCustomVoiceTitle,
    required this.voiceName,
    required this.voiceNameHint,
    required this.selectRefAudio,
    required this.selectedFilePrefix,
    required this.refTextLabel,
    required this.refTextHint,
    required this.enterVoiceName,
    required this.selectRefAudioRequired,
    required this.customVoiceAdded,
    required this.noCustomVoices,
    required this.addVoiceFailed,
    required this.deleteVoice,
    required this.deleteVoiceConfirmPre,
    required this.deleteVoiceConfirmSuf,
    // 电话页
    required this.callStartFailed,
    required this.pleaseSpeak,
    required this.callConnected,
    required this.listeningHint,
    required this.aiSpeakingHint,
    required this.diagSent,
    required this.diagConn,
    required this.connOk,
    required this.connFail,
    required this.diagRec,
    required this.recOn,
    required this.recOff,
    required this.userBubble,
    // 聊天页
    required this.sendFailed,
    required this.voiceDiagPrefix,
    required this.saveReadToggleFailed,
    required this.greeting,
    required this.readMessage,
    required this.noMicPermission,
    required this.startRecordFailed,
    required this.stopRecordFailed,
    required this.voiceRecFailed,
    // 聊天输入栏 / 电话栏
    required this.recognizingVoice,
    required this.speechHint,
    required this.inputHint,
    required this.toggleTtsOff,
    required this.toggleTtsOn,
    // 角色列表
    required this.selectCharacterFirst,
    required this.viewCharacter,
    // 抽屉
    required this.createFailed,
    // LLM 设置
    required this.apiUrlRequired,
    required this.llmModelsFailed,
    required this.llmSaveFailed,
    // 连接页
    required this.connectSubtitle,
    required this.serverUrlLabel,
    required this.accessTokenLabel,
    required this.accessTokenHint,
    required this.urlRequiredError,
    required this.connectFailed,
    required this.authFailed,
    required this.connectAndTest,
  });

  final String appName;
  final String newConversation;
  final String searchConversation;
  final String conversations;
  final String untitled;
  final String messageCount;
  final String rename;
  final String delete;
  final String confirmDeleteConversation;
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
  final String customVoice;
  final String settings;
  final String llmSettings;
  final String ttsEngine;
  final String userSettings;
  final String readAloud;
  final String llmBackend;
  final String backendLocal;
  final String backendOpenai;
  final String apiUrl;
  final String apiKeyMasked;
  final String model;
  final String refreshModels;
  final String selectModel;
  final String saveLLM;
  final String llmSaved;
  final String language;
  final String server;
  final String disconnect;
  final String phone;
  final String currentCharacter;
  final String avatar;
  final String userName;
  final String saveUserName;
  final String userRolePrompt;
  final String defaultUserRole;
  final String saveUserRole;
  final String saveUserVoice;
  final String selectAvatar;
  final String chooseFromDevice;
  final String avatarUploaded;
  final String enterUserName;
  final String userNameSaved;
  final String userRoleSaved;
  final String userVoiceSaved;
  final String saved;
  final String characterName;
  final String saveCharacterName;
  final String characterAvatar;
  final String aiRolePrompt;
  final String saveAiRolePrompt;
  final String characterVoice;
  final String saveCharacterVoice;
  final String addCharacter;
  final String deleteCharacter;
  final String confirmDeleteCharacter;
  final String characterNameRequired;
  final String characterCreated;
  final String characterDeleted;
  final String characterSaved;
  final String aiAvatarSaved;

  // 通用
  final String colon;
  final String questionSuffix;
  final String nameQuoteL;
  final String nameQuoteR;
  final String failedPrefix;
  final String notConnected;
  final String noVoices;
  final String saveFailed;
  final String deleteFailed;
  final String stopReading;
  final String noSpeechDetected;
  final String webSaveUnsupported;
  final String savedPathPrefix;
  final String offlineModeBanner;
  final String networkRequired;

  // 朗读工具箱
  final String readWeb;
  final String webUrlHint;
  final String readText;
  final String readTextHint;
  final String enterWebUrl;
  final String noWebContent;
  final String fetchWebFailed;
  final String enterReadText;
  final String readFailed;

  // 语音转文本
  final String sttDefaultStatus;
  final String micOff;
  final String micStartFailed;
  final String transcribeDone;
  final String transcribeFailed;
  final String noTextToSave;
  final String noTextToCopy;
  final String copied;
  final String sttRecognitionHint;
  final String charCount;
  final String saveTxt;
  final String copy;
  final String clear;
  final String uploadAudio;
  final String sttTimeHint;

  // 语音合成
  final String switchEngineFailed;
  final String voiceLoadFailed;
  final String enterSynthText;
  final String synthFailed;
  final String audioSaved;
  final String voiceLabel;
  final String synthTextHint;
  final String synthesize;
  final String stop;
  final String saveAudio;

  // TTS 引擎
  final String switchEngineOk;
  final String currentEnginePrefix;
  final String voicesPrefix;
  final String currentEngine;
  final String voiceSep;

  // 头像/上传
  final String imageProcessFailed;
  final String uploadFailed;

  // 自定义音色
  final String addCustomVoiceTitle;
  final String voiceName;
  final String voiceNameHint;
  final String selectRefAudio;
  final String selectedFilePrefix;
  final String refTextLabel;
  final String refTextHint;
  final String enterVoiceName;
  final String selectRefAudioRequired;
  final String customVoiceAdded;
  final String noCustomVoices;
  final String addVoiceFailed;
  final String deleteVoice;
  final String deleteVoiceConfirmPre;
  final String deleteVoiceConfirmSuf;

  // 电话页
  final String callStartFailed;
  final String pleaseSpeak;
  final String callConnected;
  final String listeningHint;
  final String aiSpeakingHint;
  final String diagSent;
  final String diagConn;
  final String connOk;
  final String connFail;
  final String diagRec;
  final String recOn;
  final String recOff;
  final String userBubble;

  // 聊天页
  final String sendFailed;
  final String voiceDiagPrefix;
  final String saveReadToggleFailed;
  final String greeting;
  final String readMessage;
  final String noMicPermission;
  final String startRecordFailed;
  final String stopRecordFailed;
  final String voiceRecFailed;

  // 聊天输入栏 / 电话栏
  final String recognizingVoice;
  final String speechHint;
  final String inputHint;
  final String toggleTtsOff;
  final String toggleTtsOn;

  // 角色列表
  final String selectCharacterFirst;
  final String viewCharacter;

  // 抽屉
  final String createFailed;

  // LLM 设置
  final String apiUrlRequired;
  final String llmModelsFailed;
  final String llmSaveFailed;

  // 连接页
  final String connectSubtitle;
  final String serverUrlLabel;
  final String accessTokenLabel;
  final String accessTokenHint;
  final String urlRequiredError;
  final String connectFailed;
  final String authFailed;
  final String connectAndTest;

  /// 已切换到「名字」/ Switched to "name"
  String charSwitchOk(String name) =>
      '$switchedToCharacter$nameQuoteL$name$nameQuoteR';

  /// 已切换到「名字」失败：e / Switched to "name" failed: e
  String charSwitchFailed(String name, Object e) =>
      '$charSwitchOk(name)$failedPrefix$e';

  /// 删除角色「名字」？/ Delete character "name"?
  String deleteCharacterTitle(String name) =>
      '$deleteCharacter$nameQuoteL$name$nameQuoteR$questionSuffix';

  /// 确定删除音色「名字」吗？/ Delete voice "name"?
  String confirmDeleteVoiceMsg(String name) =>
      '$deleteVoiceConfirmPre$nameQuoteL$name$nameQuoteR$deleteVoiceConfirmSuf';

  static const zh = AppStrings(
    appName: 'Talk With Anyone',
    newConversation: '新建对话',
    searchConversation: '搜索会话',
    conversations: '会话',
    untitled: '（未命名）',
    messageCount: '条消息',
    rename: '重命名',
    delete: '删除',
    confirmDeleteConversation: '确定删除该对话吗？',
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
    customVoice: '自定义音色',
    settings: '设置',
    llmSettings: 'LLM 设置',
    ttsEngine: 'TTS 引擎',
    userSettings: '用户设置',
    readAloud: '朗读工具箱',
    llmBackend: '后端',
    backendLocal: '本地 (llama-server)',
    backendOpenai: 'OpenAI 兼容',
    apiUrl: 'API 地址',
    apiKeyMasked: 'API Key',
    model: '模型',
    refreshModels: '刷新模型列表',
    selectModel: '请选择模型',
    saveLLM: '保存 LLM 设置',
    llmSaved: 'LLM 设置已保存',
    language: '语言',
    server: '当前服务器',
    disconnect: '断开连接',
    phone: '电话',
    currentCharacter: '当前角色',
    avatar: '头像',
    userName: '用户名称',
    saveUserName: '保存名称',
    userRolePrompt: '用户角色设定',
    defaultUserRole: '你是一个真实的人类用户',
    saveUserRole: '保存角色设定',
    saveUserVoice: '确认音色',
    selectAvatar: '选择头像',
    chooseFromDevice: '从手机选择图片',
    avatarUploaded: '头像已上传',
    enterUserName: '请输入用户名称',
    userNameSaved: '用户名称已保存',
    userRoleSaved: '用户角色设定已保存',
    userVoiceSaved: '用户音色已保存',
    saved: '已保存',
    characterName: '角色名称',
    saveCharacterName: '保存名称',
    characterAvatar: '角色头像',
    aiRolePrompt: 'AI 角色设定',
    saveAiRolePrompt: '保存角色设定',
    characterVoice: '角色音色',
    saveCharacterVoice: '确认音色',
    addCharacter: '新增角色',
    deleteCharacter: '删除角色',
    confirmDeleteCharacter: '确定删除该角色吗？',
    characterNameRequired: '请输入角色名称',
    characterCreated: '角色已创建',
    characterDeleted: '角色已删除',
    characterSaved: '角色已保存',
    aiAvatarSaved: '角色头像已上传',
    colon: '：',
    questionSuffix: '？',
    nameQuoteL: '「',
    nameQuoteR: '」',
    failedPrefix: '失败：',
    notConnected: '未连接到服务器',
    noVoices: '暂无可用音色',
    saveFailed: '保存失败：',
    deleteFailed: '删除失败：',
    stopReading: '停止朗读',
    noSpeechDetected: '未识别到语音内容',
    webSaveUnsupported: '网页调试版不支持保存到手机，请用手机 App 使用该功能',
    savedPathPrefix: '已保存：',
    offlineModeBanner: '离线模式（内容为最近一次同步，修改需服务器连接）',
    networkRequired: '该操作需要联接服务器',
    readWeb: '朗读网页',
    webUrlHint: '输入网页地址...',
    readText: '朗读文本',
    readTextHint: '输入要朗读的文本...',
    enterWebUrl: '请输入网页地址',
    noWebContent: '未获取到网页内容',
    fetchWebFailed: '获取网页内容失败：',
    enterReadText: '请输入要朗读的文本',
    readFailed: '朗读失败：',
    sttDefaultStatus: '点击麦克风开始语音输入，说一句自动识别一句',
    micOff: '麦克风已关闭',
    micStartFailed: '开启麦克风失败：',
    transcribeDone: '转写完成',
    transcribeFailed: '转写失败：',
    noTextToSave: '没有可保存的文字',
    noTextToCopy: '没有可复制的文字',
    copied: '已复制',
    sttRecognitionHint: '识别的文字会显示在这里，也可以上传音频文件转成文字...',
    charCount: '字',
    saveTxt: '保存 txt',
    copy: '复制',
    clear: '清空',
    uploadAudio: '上传音频',
    sttTimeHint: '⏱ 耗时≈音频时长一半（1小时约30分钟），建议1小时以内',
    switchEngineFailed: '切换引擎失败：',
    voiceLoadFailed: '音色加载失败：',
    enterSynthText: '请输入要合成的文本',
    synthFailed: '合成失败：',
    audioSaved: '音频已保存',
    voiceLabel: '音色',
    synthTextHint: '请输入要合成的文本内容...',
    synthesize: '语音合成',
    stop: '停止',
    saveAudio: '保存音频',
    switchEngineOk: '已切换 TTS 引擎：',
    currentEnginePrefix: '当前引擎：',
    voicesPrefix: '音色：',
    currentEngine: '当前引擎',
    voiceSep: '、',
    imageProcessFailed: '图片处理失败',
    uploadFailed: '上传失败：',
    addCustomVoiceTitle: '添加自定义音色',
    voiceName: '音色名称',
    voiceNameHint: '例如：我的声音',
    selectRefAudio: '选择参考音频',
    selectedFilePrefix: '已选择：',
    refTextLabel: '参考文本（可选）',
    refTextHint: '参考音频对应的文字内容',
    enterVoiceName: '请输入音色名称',
    selectRefAudioRequired: '请选择参考音频',
    customVoiceAdded: '自定义音色已添加',
    noCustomVoices: '还没有自定义音色',
    addVoiceFailed: '添加失败：',
    deleteVoice: '删除音色',
    deleteVoiceConfirmPre: '确定删除音色',
    deleteVoiceConfirmSuf: '吗？',
    callStartFailed: '启动通话失败：',
    pleaseSpeak: '请说话',
    callConnected: '通话已连接',
    listeningHint: '正在听你说…',
    aiSpeakingHint: 'AI 正在说话…',
    diagSent: '诊断: 已发音频 ',
    diagConn: ' · 连接',
    connOk: '正常',
    connFail: '未通',
    diagRec: ' · 录音',
    recOn: '中',
    recOff: '停',
    userBubble: '我',
    sendFailed: '发送失败：',
    voiceDiagPrefix: '语音诊断：',
    saveReadToggleFailed: '保存朗读开关失败：',
    greeting: '和 AI 打个招呼吧',
    readMessage: '朗读',
    noMicPermission: '未获得麦克风权限',
    startRecordFailed: '开始录音失败：',
    stopRecordFailed: '停止录音失败：',
    voiceRecFailed: '语音识别失败：',
    recognizingVoice: '正在识别语音…',
    speechHint: '松开结束，说话输入文字',
    inputHint: '输入消息…',
    toggleTtsOff: '关闭朗读',
    toggleTtsOn: '开启朗读',
    selectCharacterFirst: '请先选中一个角色',
    viewCharacter: '查看角色',
    createFailed: '创建失败：',
    apiUrlRequired: '请先填写 API 地址',
    llmModelsFailed: '获取模型列表失败：',
    llmSaveFailed: '保存 LLM 设置失败：',
    connectSubtitle: '连接到你的电脑上的服务器',
    serverUrlLabel: '服务器地址',
    accessTokenLabel: '访问口令（可选）',
    accessTokenHint: '与服务器 config.json 的 access_token 一致',
    urlRequiredError: '请输入服务器地址，例如 https://192.168.1.100:7862',
    connectFailed: '连接失败：',
    authFailed: '访问口令错误或无权访问',
    connectAndTest: '连接并测试',
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
    confirmDeleteConversation: 'Delete this conversation?',
    cancel: 'Cancel',
    save: 'Save',
    retry: 'Retry',
    loadFailed: 'Failed to load',
    noConversations: 'No conversations yet',
    characters: 'Characters',
    noCharacters: 'No characters yet',
    switchedToCharacter: 'Switched to ',
    tools: 'Tools',
    ttsStudio: 'TTS Studio',
    sttStudio: 'STT Studio',
    customVoice: 'Custom Voice',
    settings: 'Settings',
    llmSettings: 'LLM Settings',
    ttsEngine: 'TTS Engine',
    userSettings: 'User Settings',
    readAloud: 'Read Aloud',
    llmBackend: 'Backend',
    backendLocal: 'Local (llama-server)',
    backendOpenai: 'OpenAI compatible',
    apiUrl: 'API URL',
    apiKeyMasked: 'API Key',
    model: 'Model',
    refreshModels: 'Refresh model list',
    selectModel: 'Select a model',
    saveLLM: 'Save LLM Settings',
    llmSaved: 'LLM settings saved',
    language: 'Language',
    server: 'Server',
    disconnect: 'Disconnect',
    phone: 'Call',
    currentCharacter: 'Current character',
    avatar: 'Avatar',
    userName: 'User name',
    saveUserName: 'Save name',
    userRolePrompt: 'User role prompt',
    defaultUserRole: 'You are a real human user',
    saveUserRole: 'Save role prompt',
    saveUserVoice: 'Confirm voice',
    selectAvatar: 'Select avatar',
    chooseFromDevice: 'Choose image from device',
    avatarUploaded: 'Avatar uploaded',
    enterUserName: 'Please enter user name',
    userNameSaved: 'User name saved',
    userRoleSaved: 'User role prompt saved',
    userVoiceSaved: 'User voice saved',
    saved: 'Saved',
    characterName: 'Character name',
    saveCharacterName: 'Save name',
    characterAvatar: 'Character avatar',
    aiRolePrompt: 'AI role prompt',
    saveAiRolePrompt: 'Save role prompt',
    characterVoice: 'Character voice',
    saveCharacterVoice: 'Confirm voice',
    addCharacter: 'Add character',
    deleteCharacter: 'Delete character',
    confirmDeleteCharacter: 'Delete this character?',
    characterNameRequired: 'Please enter character name',
    characterCreated: 'Character created',
    characterDeleted: 'Character deleted',
    characterSaved: 'Character saved',
    aiAvatarSaved: 'Character avatar uploaded',
    colon: ': ',
    questionSuffix: '?',
    nameQuoteL: '"',
    nameQuoteR: '"',
    failedPrefix: ' failed: ',
    notConnected: 'Not connected to server',
    noVoices: 'No voices available',
    saveFailed: 'Save failed: ',
    deleteFailed: 'Delete failed: ',
    stopReading: 'Stop reading',
    noSpeechDetected: 'No speech detected',
    webSaveUnsupported:
        'Saving to phone is not supported in the web debug version. Please use the mobile app.',
    savedPathPrefix: 'Saved to: ',
    offlineModeBanner: 'Offline mode (content from last sync; Edits require server)',
    networkRequired: 'This action requires a server connection',
    readWeb: 'Read webpage',
    webUrlHint: 'Enter a web address...',
    readText: 'Read text',
    readTextHint: 'Enter text to read aloud...',
    enterWebUrl: 'Please enter a web address',
    noWebContent: 'No web content found',
    fetchWebFailed: 'Failed to fetch web content: ',
    enterReadText: 'Please enter text to read aloud',
    readFailed: 'Failed to read aloud: ',
    sttDefaultStatus:
        'Tap the mic to start voice input, and each sentence will be recognized automatically.',
    micOff: 'Microphone off',
    micStartFailed: 'Failed to start microphone: ',
    transcribeDone: 'Transcription complete',
    transcribeFailed: 'Transcription failed: ',
    noTextToSave: 'No text to save',
    noTextToCopy: 'No text to copy',
    copied: 'Copied',
    sttRecognitionHint:
        'Recognized text appears here. You can also upload an audio file to transcribe it...',
    charCount: 'chars',
    saveTxt: 'Save txt',
    copy: 'Copy',
    clear: 'Clear',
    uploadAudio: 'Upload audio',
    sttTimeHint:
        '⏱ Transcription takes about half the audio length (1h ≈ 30min). Keep it under 1 hour.',
    switchEngineFailed: 'Failed to switch engine: ',
    voiceLoadFailed: 'Failed to load voices: ',
    enterSynthText: 'Please enter text to synthesize',
    synthFailed: 'Synthesis failed: ',
    audioSaved: 'Audio saved',
    voiceLabel: 'Voice',
    synthTextHint: 'Enter text to synthesize...',
    synthesize: 'Synthesize',
    stop: 'Stop',
    saveAudio: 'Save audio',
    switchEngineOk: 'Switched to TTS engine: ',
    currentEnginePrefix: 'Current engine: ',
    voicesPrefix: 'Voices: ',
    currentEngine: 'Current engine',
    voiceSep: ', ',
    imageProcessFailed: 'Image processing failed',
    uploadFailed: 'Upload failed: ',
    addCustomVoiceTitle: 'Add custom voice',
    voiceName: 'Voice name',
    voiceNameHint: 'e.g. My voice',
    selectRefAudio: 'Select reference audio',
    selectedFilePrefix: 'Selected: ',
    refTextLabel: 'Reference text (optional)',
    refTextHint: 'Text content of the reference audio',
    enterVoiceName: 'Please enter a voice name',
    selectRefAudioRequired: 'Please select reference audio',
    customVoiceAdded: 'Custom voice added',
    noCustomVoices: 'No custom voices yet',
    addVoiceFailed: 'Add failed: ',
    deleteVoice: 'Delete voice',
    deleteVoiceConfirmPre: 'Delete voice ',
    deleteVoiceConfirmSuf: '?',
    callStartFailed: 'Failed to start the call: ',
    pleaseSpeak: 'Speak now',
    callConnected: 'Call connected',
    listeningHint: 'Listening to you…',
    aiSpeakingHint: 'AI is speaking…',
    diagSent: 'Diag: sent audio ',
    diagConn: ' · conn ',
    connOk: 'OK',
    connFail: 'fail',
    diagRec: ' · rec ',
    recOn: 'on',
    recOff: 'off',
    userBubble: 'Me',
    sendFailed: 'Send failed: ',
    voiceDiagPrefix: 'Voice diagnostics: ',
    saveReadToggleFailed: 'Failed to save read-aloud setting: ',
    greeting: 'Say hi to the AI!',
    readMessage: 'Read',
    noMicPermission: 'Microphone permission not granted',
    startRecordFailed: 'Failed to start recording: ',
    stopRecordFailed: 'Failed to stop recording: ',
    voiceRecFailed: 'Voice recognition failed: ',
    recognizingVoice: 'Recognizing speech…',
    speechHint: 'Release to stop, speak to type',
    inputHint: 'Type a message…',
    toggleTtsOff: 'Disable read-aloud',
    toggleTtsOn: 'Enable read-aloud',
    selectCharacterFirst: 'Please select a character first',
    viewCharacter: 'View character',
    createFailed: 'Create failed: ',
    apiUrlRequired: 'Please enter the API URL first',
    llmModelsFailed: 'Failed to fetch model list: ',
    llmSaveFailed: 'Failed to save LLM settings: ',
    connectSubtitle: 'Connect to the server on your computer',
    serverUrlLabel: 'Server address',
    accessTokenLabel: 'Access token (optional)',
    accessTokenHint: 'Must match access_token in the server config.json',
    urlRequiredError:
        'Please enter a server address, e.g. https://192.168.1.100:7862',
    connectFailed: 'Connection failed: ',
    authFailed: 'Wrong access token or no permission',
    connectAndTest: 'Connect & Test',
  );
}

extension AppStringsCtx on BuildContext {
  AppStrings get strs {
    final isEn = watch<AppState>().isEn;
    return isEn ? AppStrings.en : AppStrings.zh;
  }
}