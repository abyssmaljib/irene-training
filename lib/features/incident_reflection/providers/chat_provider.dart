// Provider สำหรับจัดการ Chat กับ AI Coach
// ใช้ StateNotifier สำหรับจัดการ chat messages และเรียก AI service

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_message.dart';
import '../models/incident.dart';
import '../models/reflection_pillars.dart';
import '../services/ai_chat_service.dart' show AiChatService, AvailableCoreValue, PillarContent;
import '../services/incident_service.dart';
import 'incident_provider.dart';

/// State สำหรับ Chat screen
class ChatState {
  /// รายการข้อความทั้งหมด
  final List<ChatMessage> messages;

  /// กำลังส่งข้อความอยู่หรือไม่
  final bool isSending;

  /// กำลังสร้างสรุปอยู่หรือไม่
  final bool isGeneratingSummary;

  /// ความคืบหน้าของ 4 Pillars
  final ReflectionPillars pillarsProgress;

  /// ถอดบทเรียนเสร็จแล้วหรือยัง (ครบ 4 Pillars)
  final bool isComplete;

  /// Error message (ถ้ามี)
  final String? error;

  /// Flag บอกว่าควรแสดง Summary Popup หรือไม่
  /// จะเป็น true เมื่อครบ 4 Pillars เป็นครั้งแรก และยังไม่เคยแสดง popup
  final bool shouldShowSummaryPopup;

  /// สรุปผลที่ได้จาก AI (เก็บไว้แสดงใน popup)
  final ReflectionSummary? currentSummary;

  /// Flag บอกว่าต้องแสดง Core Value picker หรือไม่
  /// เมื่อเป็น true จะแสดง UI ให้ user เลือก Core Values แทนช่องพิมพ์
  final bool showCoreValuePicker;

  /// รายการ Core Values ที่สามารถเลือกได้ (สำหรับแสดงใน picker)
  final List<AvailableCoreValue> availableCoreValues;

  /// Pillar ที่กำลังถามอยู่ (1-4)
  /// 1 = ความสำคัญ, 2 = สาเหตุ, 3 = Core Values, 4 = การป้องกัน
  /// null = ไม่ได้ถามเรื่องใดเฉพาะ (ทักทาย/ปิดสนทนา)
  final int? currentPillar;

  /// ข้อความที่ส่งไม่สำเร็จ (สำหรับ retry)
  /// เก็บไว้เพื่อให้ user กด "ส่งอีกครั้ง" ได้
  final String? failedMessage;

  const ChatState({
    this.messages = const [],
    this.isSending = false,
    this.isGeneratingSummary = false,
    this.pillarsProgress = const ReflectionPillars(),
    this.isComplete = false,
    this.error,
    this.shouldShowSummaryPopup = false,
    this.currentSummary,
    this.showCoreValuePicker = false,
    this.availableCoreValues = const [],
    this.currentPillar,
    this.failedMessage,
  });

  /// สร้าง copy พร้อมเปลี่ยนค่าบางส่วน
  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isSending,
    bool? isGeneratingSummary,
    ReflectionPillars? pillarsProgress,
    bool? isComplete,
    String? error,
    bool clearError = false,
    bool? shouldShowSummaryPopup,
    ReflectionSummary? currentSummary,
    bool clearSummary = false,
    bool? showCoreValuePicker,
    List<AvailableCoreValue>? availableCoreValues,
    int? currentPillar,
    bool clearCurrentPillar = false,
    String? failedMessage,
    bool clearFailedMessage = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      isGeneratingSummary: isGeneratingSummary ?? this.isGeneratingSummary,
      pillarsProgress: pillarsProgress ?? this.pillarsProgress,
      isComplete: isComplete ?? this.isComplete,
      error: clearError ? null : (error ?? this.error),
      shouldShowSummaryPopup:
          shouldShowSummaryPopup ?? this.shouldShowSummaryPopup,
      currentSummary:
          clearSummary ? null : (currentSummary ?? this.currentSummary),
      showCoreValuePicker: showCoreValuePicker ?? this.showCoreValuePicker,
      availableCoreValues: availableCoreValues ?? this.availableCoreValues,
      currentPillar:
          clearCurrentPillar ? null : (currentPillar ?? this.currentPillar),
      failedMessage:
          clearFailedMessage ? null : (failedMessage ?? this.failedMessage),
    );
  }
}

/// StateNotifier สำหรับจัดการ Chat state
class ChatNotifier extends StateNotifier<ChatState> {
  final AiChatService _aiService;
  final IncidentService _incidentService;
  final Ref _ref;

  /// Incident ที่กำลังถอดบทเรียน
  Incident? _currentIncident;

  /// ชื่อเล่น/ชื่อจริงของ user สำหรับให้ AI เรียก
  String? _userName;

  /// Flag ว่าเคยแสดง Summary Popup แล้วหรือยัง (ใน session นี้)
  /// ใช้เพื่อแสดง popup แค่ครั้งแรกเท่านั้น
  bool _hasShownSummaryPopup = false;

  ChatNotifier(this._ref)
      : _aiService = AiChatService.instance,
        _incidentService = IncidentService.instance,
        super(const ChatState());

  /// โหลด chat history จาก incident และเริ่มการถอดบทเรียน
  Future<void> loadFromIncident(Incident incident) async {
    _currentIncident = incident;

    // ดึงชื่อเล่น/ชื่อจริงของ user สำหรับให้ AI เรียก
    await _loadUserName();

    // โหลด chat history จาก incident (ถ้ามี)
    final messages = incident.chatHistory;

    // คำนวณ pillars progress จาก incident
    final pillarsProgress = incident.pillarsProgress;

    state = ChatState(
      messages: messages,
      pillarsProgress: pillarsProgress,
      isComplete: pillarsProgress.isComplete,
    );

    // ถ้ายังไม่เคยเริ่ม ให้เริ่มการถอดบทเรียน
    if (incident.isPendingReflection) {
      await _incidentService.startReflection(incident.id);
    }

    // ถ้าไม่มีข้อความเริ่มต้น ให้ AI ทักทายก่อน
    if (messages.isEmpty) {
      await _sendGreeting();
    }

    debugPrint(
        'ChatNotifier: loaded ${messages.length} messages for incident ${incident.id}');
  }

  /// ดึงชื่อเล่น/ชื่อจริงของ user จาก user_info table
  /// ใช้ nickname เป็นหลัก ถ้าไม่มีให้ใช้ full_name
  Future<void> _loadUserName() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        debugPrint('ChatNotifier._loadUserName: no current user');
        return;
      }

      // Query user_info table เพื่อดึง nickname และ full_name
      final response = await supabase
          .from('user_info')
          .select('nickname, full_name')
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        // ใช้ nickname เป็นหลัก ถ้าไม่มีให้ใช้ full_name
        final nickname = response['nickname'] as String?;
        final fullName = response['full_name'] as String?;

        _userName = (nickname?.isNotEmpty == true)
            ? nickname
            : fullName;

        debugPrint('ChatNotifier._loadUserName: userName=$_userName');
      }
    } catch (e) {
      debugPrint('ChatNotifier._loadUserName error: $e');
      // ไม่ต้อง throw - ถ้าดึงไม่ได้ก็ให้ AI ใช้ "คุณ" แทน
    }
  }

  /// ส่งคำทักทายจาก AI (ข้อความเริ่มต้น)
  Future<void> _sendGreeting() async {
    if (_currentIncident == null) {
      debugPrint('ChatNotifier._sendGreeting: _currentIncident is null');
      return;
    }

    debugPrint('ChatNotifier._sendGreeting: starting for incident ${_currentIncident!.id}');

    // เพิ่ม loading message
    state = state.copyWith(
      messages: [...state.messages, ChatMessage.loading()],
      isSending: true,
    );

    try {
      debugPrint('ChatNotifier._sendGreeting: calling _aiService.sendMessage...');

      // เรียก AI โดยไม่ส่งข้อความ (ให้ AI ทักทายก่อน)
      // ส่ง userName ไปด้วยเพื่อให้ AI เรียกชื่อผู้ใช้ได้ถูกต้อง
      final response = await _aiService.sendMessage(
        incidentId: _currentIncident!.id,
        message: '[START]', // Special message to trigger greeting
        chatHistory: [],
        incidentTitle: _currentIncident!.title,
        incidentDescription: _currentIncident!.description,
        userName: _userName,
      );

      debugPrint('ChatNotifier._sendGreeting: response received = ${response != null}');

      if (response != null) {
        // ลบ loading message และเพิ่มข้อความจาก AI
        final newMessage = ChatMessage.assistant(response.message);
        final updatedMessages = [
          ...state.messages.where((m) => !m.isLoading),
          newMessage,
        ];

        state = state.copyWith(
          messages: updatedMessages,
          isSending: false,
          pillarsProgress: response.pillarsProgress,
          isComplete: response.isComplete,
          clearError: true,
          // อัพเดต Core Value picker state
          showCoreValuePicker: response.showCoreValuePicker,
          availableCoreValues: response.availableCoreValues,
          // อัพเดต current pillar ที่กำลังถามอยู่
          currentPillar: response.currentPillar,
        );

        // บันทึก chat history
        await _saveChatHistory();
      } else {
        // ลบ loading message และแสดง error
        debugPrint('ChatNotifier._sendGreeting: response is null - AI connection failed');
        state = state.copyWith(
          messages: state.messages.where((m) => !m.isLoading).toList(),
          isSending: false,
          error: 'ไม่สามารถเชื่อมต่อ AI ได้ กรุณาลองใหม่',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('ChatNotifier._sendGreeting error: $e');
      debugPrint('Stack trace: $stackTrace');
      state = state.copyWith(
        messages: state.messages.where((m) => !m.isLoading).toList(),
        isSending: false,
        error: 'เกิดข้อผิดพลาด: $e',
      );
    }
  }

  /// ส่งข้อความไปยัง AI
  Future<void> sendMessage(String content) async {
    if (_currentIncident == null) return;
    if (content.trim().isEmpty) return;
    if (state.isSending) return;

    // เพิ่มข้อความจาก user
    final userMessage = ChatMessage.user(content);
    final loadingMessage = ChatMessage.loading();

    state = state.copyWith(
      messages: [...state.messages, userMessage, loadingMessage],
      isSending: true,
      clearError: true,
    );

    try {
      // ส่งข้อความไปยัง AI พร้อม userName เพื่อให้ AI เรียกชื่อผู้ใช้ได้ถูกต้อง
      final response = await _aiService.sendMessage(
        incidentId: _currentIncident!.id,
        message: content,
        chatHistory: state.messages.where((m) => !m.isLoading).toList(),
        incidentTitle: _currentIncident!.title,
        incidentDescription: _currentIncident!.description,
        userName: _userName,
      );

      if (response != null) {
        // ลบ loading message และเพิ่มข้อความจาก AI
        final aiMessage = ChatMessage.assistant(response.message);
        final updatedMessages = [
          ...state.messages.where((m) => !m.isLoading),
          aiMessage,
        ];

        // ตรวจสอบว่าครบ 4 Pillars เป็นครั้งแรกหรือไม่
        // ถ้าครบและยังไม่เคยแสดง popup → trigger popup
        final shouldTriggerPopup = response.pillarsProgress.isComplete &&
            !_hasShownSummaryPopup &&
            !state.isComplete;

        state = state.copyWith(
          messages: updatedMessages,
          isSending: false,
          pillarsProgress: response.pillarsProgress,
          isComplete: response.isComplete,
          // Trigger popup ถ้าครบครั้งแรก
          shouldShowSummaryPopup: shouldTriggerPopup,
          // อัพเดต Core Value picker state
          showCoreValuePicker: response.showCoreValuePicker,
          availableCoreValues: response.availableCoreValues,
          // อัพเดต current pillar ที่กำลังถามอยู่
          currentPillar: response.currentPillar,
        );

        // บันทึก chat history
        await _saveChatHistory();

        // บันทึก pillar content ลง database ทันที (ถ้ามี)
        if (response.pillarContent != null &&
            response.pillarContent!.hasAnyContent) {
          await _savePillarContent(response.pillarContent!);
        }

        // ถ้า trigger popup แล้ว ให้ generate summary ทันที
        if (shouldTriggerPopup) {
          debugPrint('ChatNotifier: 4 Pillars complete! Generating summary...');
          await _generateSummaryForPopup();
        }

        debugPrint(
            'ChatNotifier: message sent, progress: ${response.pillarsProgress.completedCount}/4, showPicker: ${response.showCoreValuePicker}');
      } else {
        // ลบ loading message และ user message ที่ส่งไม่สำเร็จ แล้วแสดง error
        // เก็บ content ไว้ใน failedMessage เพื่อให้ retry ได้
        state = state.copyWith(
          messages: state.messages
              .where((m) => !m.isLoading && m.content != content)
              .toList(),
          isSending: false,
          error: 'ไม่สามารถส่งข้อความได้',
          failedMessage: content,
        );
      }
    } catch (e) {
      // ลบ loading message และ user message ที่ส่งไม่สำเร็จ
      // เก็บ content ไว้ใน failedMessage เพื่อให้ retry ได้
      state = state.copyWith(
        messages: state.messages
            .where((m) => !m.isLoading && m.content != content)
            .toList(),
        isSending: false,
        error: 'เกิดข้อผิดพลาด กรุณาลองใหม่',
        failedMessage: content,
      );
    }
  }

  /// บันทึก chat history ลง database
  Future<void> _saveChatHistory() async {
    if (_currentIncident == null) return;

    final messagesWithoutLoading =
        state.messages.where((m) => !m.isLoading).toList();

    await _incidentService.updateChatHistory(
      _currentIncident!.id,
      messagesWithoutLoading,
    );
  }

  /// บันทึก pillar content ลง database ทันที
  /// เรียกหลังจาก AI ตอบกลับมาและมี content ใหม่
  Future<void> _savePillarContent(PillarContent content) async {
    if (_currentIncident == null) return;

    await _incidentService.updatePillarContent(
      _currentIncident!.id,
      whyItMatters: content.whyItMatters,
      rootCause: content.rootCause,
      coreValueAnalysis: content.coreValueAnalysis,
      violatedCoreValues: content.violatedCoreValues.isNotEmpty
          ? content.violatedCoreValues
          : null,
      preventionPlan: content.preventionPlan,
    );

    debugPrint('ChatNotifier: pillar content saved to database');
  }

  /// Generate summary สำหรับแสดงใน popup
  /// เรียกอัตโนมัติเมื่อครบ 4 Pillars เป็นครั้งแรก
  Future<void> _generateSummaryForPopup() async {
    if (_currentIncident == null) return;

    state = state.copyWith(isGeneratingSummary: true);

    try {
      final summary = await _aiService.generateSummary(
        incidentId: _currentIncident!.id,
        chatHistory: state.messages.where((m) => !m.isLoading).toList(),
      );

      if (summary != null) {
        state = state.copyWith(
          isGeneratingSummary: false,
          currentSummary: summary,
          shouldShowSummaryPopup: true,
        );
        debugPrint('ChatNotifier: summary generated for popup');
      } else {
        state = state.copyWith(
          isGeneratingSummary: false,
          shouldShowSummaryPopup: false,
          error: 'ไม่สามารถสร้างสรุปได้ กรุณาลองใหม่',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isGeneratingSummary: false,
        shouldShowSummaryPopup: false,
        error: 'เกิดข้อผิดพลาด: $e',
      );
    }
  }

  /// เรียกเมื่อ user เห็น popup แล้ว (ปิด popup)
  /// จะ mark ว่าเคยแสดงแล้ว และไม่แสดงอีก
  void dismissSummaryPopup() {
    _hasShownSummaryPopup = true;
    state = state.copyWith(shouldShowSummaryPopup: false);
    debugPrint('ChatNotifier: summary popup dismissed');
  }

  /// บันทึก summary และจบการถอดบทเรียน
  /// เรียกเมื่อ user กด "ยืนยันและบันทึก" ใน popup
  Future<bool> confirmAndSaveSummary() async {
    if (_currentIncident == null) return false;
    if (state.currentSummary == null) return false;

    try {
      // บันทึกสรุปลง database
      await _incidentService.saveReflectionSummary(
        _currentIncident!.id,
        state.currentSummary!,
      );

      state = state.copyWith(
        isComplete: true,
        shouldShowSummaryPopup: false,
      );

      // Invalidate incidents provider เพื่อ refresh list
      _ref.invalidate(myIncidentsProvider);

      debugPrint('ChatNotifier: summary confirmed and saved');
      return true;
    } catch (e) {
      state = state.copyWith(
        error: 'ไม่สามารถบันทึกได้: $e',
      );
      return false;
    }
  }

  /// สร้างสรุป 4 Pillars จาก AI
  Future<ReflectionSummary?> generateSummary() async {
    if (_currentIncident == null) return null;
    if (state.isGeneratingSummary) return null;

    state = state.copyWith(isGeneratingSummary: true, clearError: true);

    try {
      final summary = await _aiService.generateSummary(
        incidentId: _currentIncident!.id,
        chatHistory: state.messages.where((m) => !m.isLoading).toList(),
      );

      if (summary != null) {
        // บันทึกสรุปลง database
        await _incidentService.saveReflectionSummary(
          _currentIncident!.id,
          summary,
        );

        state = state.copyWith(
          isGeneratingSummary: false,
          isComplete: true,
        );

        // Invalidate incidents provider เพื่อ refresh list
        _ref.invalidate(myIncidentsProvider);

        debugPrint('ChatNotifier: summary generated and saved');
        return summary;
      } else {
        state = state.copyWith(
          isGeneratingSummary: false,
          error: 'ไม่สามารถสร้างสรุปได้ กรุณาลองใหม่',
        );
        return null;
      }
    } catch (e) {
      state = state.copyWith(
        isGeneratingSummary: false,
        error: 'เกิดข้อผิดพลาด: $e',
      );
      return null;
    }
  }

  /// ล้าง error และ failed message
  void clearError() {
    state = state.copyWith(clearError: true, clearFailedMessage: true);
  }

  /// ส่งข้อความที่ส่งไม่สำเร็จอีกครั้ง
  /// ใช้เมื่อ user กดปุ่ม "ส่งอีกครั้ง"
  Future<void> retryFailedMessage() async {
    final failedMsg = state.failedMessage;
    if (failedMsg == null || failedMsg.isEmpty) return;

    // ล้าง error และ failedMessage ก่อน แล้วส่งใหม่
    state = state.copyWith(clearError: true, clearFailedMessage: true);

    // ส่งข้อความอีกครั้ง
    await sendMessage(failedMsg);
  }

  /// ส่ง Core Values ที่ user เลือก
  /// **สำคัญ**: บันทึกลง DB โดยตรงก่อน แล้วค่อยส่งข้อความให้ AI
  /// ไม่พึ่งพา AI parse เพราะอาจพลาดได้
  Future<void> sendCoreValuesSelection(List<String> selectedValues) async {
    if (_currentIncident == null || selectedValues.isEmpty) return;

    debugPrint('ChatNotifier: saving Core Values directly: $selectedValues');

    // 1. บันทึก Core Values ลง DB โดยตรง (ไม่รอ AI)
    await _incidentService.updatePillarContent(
      _currentIncident!.id,
      violatedCoreValues: selectedValues,
    );

    debugPrint('ChatNotifier: Core Values saved to DB');

    // 2. ส่งข้อความไปให้ AI (เพื่อให้ AI ตอบกลับ)
    final message = 'ฉันคิดว่าเกี่ยวข้องกับ: ${selectedValues.join(', ')}';
    await sendMessage(message);
  }

  /// Reset state (เมื่อออกจากหน้า chat)
  void reset() {
    _currentIncident = null;
    _hasShownSummaryPopup = false;
    state = const ChatState();
  }

  /// Reset บทสนทนา (ลบ chat history และเริ่มใหม่)
  /// ใช้เมื่อ user ต้องการเริ่มถอดบทเรียนใหม่ตั้งแต่ต้น
  Future<void> resetConversation() async {
    if (_currentIncident == null) return;

    final incidentId = _currentIncident!.id;

    // Reset state และ flag ก่อน
    _hasShownSummaryPopup = false;
    state = const ChatState();

    try {
      // ลบ chat history ใน database
      await _incidentService.updateChatHistory(incidentId, []);

      // Reset reflection status กลับเป็น in_progress
      await _incidentService.resetReflectionProgress(incidentId);

      // เริ่มใหม่โดยให้ AI ทักทาย
      await _sendGreeting();

      debugPrint('ChatNotifier: conversation reset for incident $incidentId');
    } catch (e) {
      state = state.copyWith(
        error: 'ไม่สามารถ reset บทสนทนาได้: $e',
      );
    }
  }
}

/// Provider สำหรับ AiChatService (Singleton)
final aiChatServiceProvider = Provider<AiChatService>((ref) {
  return AiChatService.instance;
});

/// Provider สำหรับ ChatNotifier
final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref);
});

/// Provider สำหรับตรวจสอบว่าสามารถสร้างสรุปได้หรือยัง
/// ต้องคุยครบ 4 Pillars ก่อน
final canGenerateSummaryProvider = Provider<bool>((ref) {
  final chatState = ref.watch(chatProvider);
  return chatState.pillarsProgress.isComplete && !chatState.isComplete;
});

/// Provider สำหรับ progress percentage (0.0 - 1.0)
final chatProgressProvider = Provider<double>((ref) {
  final chatState = ref.watch(chatProvider);
  return chatState.pillarsProgress.progress;
});
