// Provider สำหรับจัดการ Chat กับ AI Coach
// ใช้ StateNotifier สำหรับจัดการ chat messages และเรียก AI service

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/user_service.dart';
import '../../points/services/points_service.dart';
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

  /// ระดับความลึกของสาเหตุ (1-5) จาก AI
  /// 1=อาการ, 2=สาเหตุตรง, 3=ปัจจัยร่วม, 4=เชิงระบบ, 5=รากเหง้า
  final int? rootCauseDepth;

  /// หมวด Fishbone ที่สำรวจแล้ว เช่น ["คน", "กระบวนการ"]
  final List<String> exploredCategories;

  /// คุณภาพการวิเคราะห์: "shallow", "moderate", "deep"
  final String? analysisQuality;

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
    this.rootCauseDepth,
    this.exploredCategories = const [],
    this.analysisQuality,
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
    int? rootCauseDepth,
    bool clearRootCauseDepth = false,
    List<String>? exploredCategories,
    String? analysisQuality,
    bool clearAnalysisQuality = false,
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
      rootCauseDepth:
          clearRootCauseDepth ? null : (rootCauseDepth ?? this.rootCauseDepth),
      exploredCategories: exploredCategories ?? this.exploredCategories,
      analysisQuality:
          clearAnalysisQuality ? null : (analysisQuality ?? this.analysisQuality),
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

  /// Flag ว่า incident เสร็จแล้วตั้งแต่ตอน load มา (ไม่ได้เสร็จใน session นี้)
  /// true = เปิดดู incident ที่เสร็จแล้ว (ครั้งที่ 2+) → ไม่แสดง coin overlay
  /// false = เพิ่งเสร็จใน session นี้ หรือยังไม่เสร็จ → แสดง coin ได้
  bool _wasAlreadyCompleteOnLoad = false;
  bool get wasAlreadyCompleteOnLoad => _wasAlreadyCompleteOnLoad;

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

    // จำไว้ว่า incident เสร็จแล้วตั้งแต่ตอน load มาหรือเปล่า
    // ถ้าเสร็จแล้ว = เปิดดูครั้งที่ 2+ → ไม่ต้องแสดง coin overlay
    _wasAlreadyCompleteOnLoad = pillarsProgress.isComplete;

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
  /// ใช้ effectiveUserId เพื่อรองรับ impersonation
  Future<void> _loadUserName() async {
    try {
      final supabase = Supabase.instance.client;
      // ใช้ effectiveUserId เพื่อรองรับ impersonation
      // ถ้า impersonate อยู่ จะดึงชื่อของ user ที่ impersonate
      final userId = UserService().effectiveUserId;

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
          // อัพเดต depth tracking (v24)
          rootCauseDepth: response.rootCauseDepth,
          exploredCategories: response.exploredCategories,
          analysisQuality: response.analysisQuality,
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
          // ไม่ set shouldShowSummaryPopup ตรงนี้!
          // ให้ _generateSummaryForPopup() เป็นคน set หลัง summary พร้อมแล้ว
          // เพื่อให้ listener ตรวจจับ change ได้ถูกต้อง
          showCoreValuePicker: response.showCoreValuePicker,
          availableCoreValues: response.availableCoreValues,
          currentPillar: response.currentPillar,
          // อัพเดต depth tracking (v24)
          rootCauseDepth: response.rootCauseDepth,
          exploredCategories: response.exploredCategories,
          analysisQuality: response.analysisQuality,
        );

        // บันทึก chat history
        await _saveChatHistory();

        // บันทึก pillar content ลง database ทันที (ถ้ามี)
        if (response.pillarContent != null &&
            response.pillarContent!.hasAnyContent) {
          await _savePillarContent(response.pillarContent!);
        }

        // ถ้าครบ 4 Pillars → ให้คะแนนคืนทันที + generate summary สำหรับ popup
        if (shouldTriggerPopup) {
          debugPrint('ChatNotifier: 4 Pillars complete! Giving bonus + generating summary...');

          // คืนคะแนน 50% ทันที (ไม่ต้องรอ user กด "ยืนยัน" ใน popup)
          // duplicate check ใน recordIncidentReflectionBonus ป้องกันให้ซ้ำไม่ได้
          _lastBonusAwarded = await _giveReflectionBonus();
          debugPrint('ChatNotifier: bonus awarded = $_lastBonusAwarded');

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
        // บันทึกสรุปลง DB ทันที (ไม่ต้องรอ user กด confirm)
        await _incidentService.saveReflectionSummary(
          _currentIncident!.id,
          summary,
        );
        debugPrint('ChatNotifier: summary saved to DB');

        state = state.copyWith(
          isGeneratingSummary: false,
          isComplete: true,
          currentSummary: summary,
          shouldShowSummaryPopup: true,
        );

        // Refresh list เพื่อให้หน้า list อัพเดตสถานะ
        _ref.invalidate(myIncidentsProvider);
        debugPrint('ChatNotifier: summary generated + saved for popup');
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

  /// บันทึก summary แบบ manual (ไม่ใช้แล้วจาก auto-popup flow)
  /// ยังเก็บไว้เป็น fallback สำหรับ edge case
  /// bonus ถูกให้ตอน auto-complete ใน sendMessage() แล้ว
  Future<int> confirmAndSaveSummary() async {
    debugPrint('📝 confirmAndSaveSummary: START');

    if (_currentIncident == null) return -1;
    if (state.currentSummary == null) return -1;

    try {
      await _incidentService.saveReflectionSummary(
        _currentIncident!.id,
        state.currentSummary!,
      );

      state = state.copyWith(
        isComplete: true,
        shouldShowSummaryPopup: false,
      );

      _ref.invalidate(myIncidentsProvider);
      debugPrint('📝 confirmAndSaveSummary: DONE');
      return _lastBonusAwarded;
    } catch (e) {
      debugPrint('❌ confirmAndSaveSummary: ERROR: $e');
      return -1;
    }
  }

  /// คะแนนที่ได้คืนล่าสุด (per person) — ใช้แสดง UI หลังถอดบทเรียนเสร็จ
  int _lastBonusAwarded = 0;
  int get lastBonusAwarded => _lastBonusAwarded;

  /// เคลียร์ bonus ที่แสดงไปแล้ว (เรียกหลัง coin overlay แสดงเสร็จ)
  /// ป้องกัน coin overlay ซ้ำเมื่อกด banner อีกครั้ง
  void clearBonusAwarded() {
    _lastBonusAwarded = 0;
  }

  /// คืนคะแนน 50% หลังถอดบทเรียนเสร็จ
  /// return คะแนนที่คืนต่อคน — **always return expected amount** เพื่อแสดง UI
  /// แม้ insert Point_Transaction จะ fail ก็ยังแสดง overlay ให้ user เห็น
  Future<int> _giveReflectionBonus() async {
    debugPrint('🎁 _giveReflectionBonus: START');

    if (_currentIncident == null) {
      debugPrint('🎁 _giveReflectionBonus: _currentIncident is null → return 0');
      return 0;
    }

    final incident = _currentIncident!;
    // คำนวณ expected bonus จาก severity (ใช้แสดง UI เสมอ)
    final perPerson = PointsConfig.incidentReflectionBonus(incident.severity.value);
    debugPrint(
      '🎁 _giveReflectionBonus: severity=${incident.severity.value}, '
      'perPerson=$perPerson, staffIds=${incident.staffIds}, '
      'nhId=${incident.nursinghomeId}',
    );

    if (perPerson <= 0) {
      debugPrint('🎁 _giveReflectionBonus: perPerson <= 0 → return 0');
      return 0;
    }

    // พยายาม record bonus ลง DB (best-effort — ไม่ block UI)
    try {
      final pointsService = PointsService();
      final totalBonus = await pointsService.recordIncidentReflectionBonus(
        incidentId: incident.id,
        severity: incident.severity.value,
        staffIds: incident.staffIds,
        nursinghomeId: incident.nursinghomeId,
      );
      debugPrint('🎁 _giveReflectionBonus: DB record result totalBonus=$totalBonus');
    } catch (e) {
      debugPrint('⚠️ _giveReflectionBonus: DB record failed: $e');
      // ไม่ return 0 — ยังคงแสดง UI overlay ให้ user เห็น
    }

    debugPrint('🎁 _giveReflectionBonus: returning perPerson=$perPerson');
    return perPerson;
  }


  /// สร้างสรุป 4 Pillars จาก AI
  Future<ReflectionSummary?> generateSummary() async {
    debugPrint('📋 generateSummary: START');
    if (_currentIncident == null) {
      debugPrint('📋 generateSummary: _currentIncident is null');
      return null;
    }
    if (state.isGeneratingSummary) {
      debugPrint('📋 generateSummary: already generating');
      return null;
    }

    state = state.copyWith(isGeneratingSummary: true, clearError: true);

    try {
      debugPrint('📋 generateSummary: calling AI...');
      final summary = await _aiService.generateSummary(
        incidentId: _currentIncident!.id,
        chatHistory: state.messages.where((m) => !m.isLoading).toList(),
      );

      if (summary != null) {
        debugPrint('📋 generateSummary: AI returned summary, saving to DB...');
        // บันทึกสรุปลง database (เปลี่ยน reflection_status → completed)
        await _incidentService.saveReflectionSummary(
          _currentIncident!.id,
          summary,
        );
        debugPrint('📋 generateSummary: saved to DB OK');

        state = state.copyWith(
          isGeneratingSummary: false,
          isComplete: true,
        );

        // Invalidate incidents provider เพื่อ refresh list
        _ref.invalidate(myIncidentsProvider);

        // คืนคะแนน 50% ให้ staff — await เพื่อเก็บ bonus สำหรับแสดง UI
        debugPrint('📋 generateSummary: calling _giveReflectionBonus...');
        _lastBonusAwarded = await _giveReflectionBonus();

        debugPrint('ChatNotifier: summary generated and saved, bonus: $_lastBonusAwarded');
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
    _lastBonusAwarded = 0;
    _wasAlreadyCompleteOnLoad = false;
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
