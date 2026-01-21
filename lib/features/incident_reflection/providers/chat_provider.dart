// Provider สำหรับจัดการ Chat กับ AI Coach
// ใช้ StateNotifier สำหรับจัดการ chat messages และเรียก AI service

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_message.dart';
import '../models/incident.dart';
import '../models/reflection_pillars.dart';
import '../services/ai_chat_service.dart' show AiChatService, PillarContent;
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

  const ChatState({
    this.messages = const [],
    this.isSending = false,
    this.isGeneratingSummary = false,
    this.pillarsProgress = const ReflectionPillars(),
    this.isComplete = false,
    this.error,
    this.shouldShowSummaryPopup = false,
    this.currentSummary,
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
            'ChatNotifier: message sent, progress: ${response.pillarsProgress.completedCount}/4');
      } else {
        // ลบ loading message และแสดง error
        state = state.copyWith(
          messages: state.messages.where((m) => !m.isLoading).toList(),
          isSending: false,
          error: 'ไม่สามารถส่งข้อความได้ กรุณาลองใหม่',
        );
      }
    } catch (e) {
      state = state.copyWith(
        messages: state.messages.where((m) => !m.isLoading).toList(),
        isSending: false,
        error: 'เกิดข้อผิดพลาด: $e',
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

  /// ล้าง error
  void clearError() {
    state = state.copyWith(clearError: true);
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
