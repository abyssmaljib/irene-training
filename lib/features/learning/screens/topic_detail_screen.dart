import 'package:flutter/material.dart' hide Badge;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/services/user_service.dart';
import '../models/topic_with_progress.dart';
import '../models/topic_detail.dart';
import '../models/quiz_history_item.dart';
import '../models/quiz_session.dart';
import '../models/badge.dart';
import '../models/thinking_skill_data.dart';
import '../services/badge_service.dart';
import '../widgets/content_tab.dart';
import '../widgets/quiz_tab.dart';
import '../widgets/badge_earned_dialog.dart';
import '../../../core/widgets/irene_app_bar.dart';
import 'quiz_screen.dart';
import 'quiz_result_screen.dart';
import '../../../core/widgets/shimmer_loading.dart';

class TopicDetailScreen extends StatefulWidget {
  final TopicWithProgress topic;

  const TopicDetailScreen({
    super.key,
    required this.topic,
  });

  @override
  State<TopicDetailScreen> createState() => _TopicDetailScreenState();
}

class _TopicDetailScreenState extends State<TopicDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  TopicDetail? _topicDetail;
  List<QuizHistoryItem> _quizHistory = [];
  ThinkingSkillsData? _skillsData;
  bool _isLoading = true;
  bool _isHistoryLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadTopicDetail(),
      _loadQuizHistory(),
      _loadThinkingSkills(),
    ]);
  }

  Future<void> _loadThinkingSkills() async {
    try {
      final userId = UserService().effectiveUserId;
      if (userId == null) return;

      // Get active season
      final seasonResponse = await Supabase.instance.client
          .from('training_seasons')
          .select('id')
          .eq('is_active', true)
          .maybeSingle();

      if (seasonResponse == null) return;
      final seasonId = seasonResponse['id'] as String;

      final response = await Supabase.instance.client
          .from('training_v_thinking_analysis_by_topic')
          .select()
          .eq('user_id', userId)
          .eq('topic_id', widget.topic.topicId)
          .eq('season_id', seasonId);

      if (mounted && (response as List).isNotEmpty) {
        final Map<String, dynamic> breakdown = {};
        for (final row in response) {
          breakdown[row['thinking_type'] as String] = {
            'total': row['total_questions'],
            'correct': row['correct_count'],
            'percent': row['percent_correct'],
          };
        }

        setState(() {
          _skillsData = ThinkingSkillsData.fromThinkingBreakdown(breakdown);
        });
      }
    } catch (e) {
      debugPrint('Thinking skills error: $e');
    }
  }

  Future<void> _loadTopicDetail() async {
    try {
      final userId = UserService().effectiveUserId;
      if (userId == null) {
        setState(() {
          _error = 'กรุณาเข้าสู่ระบบก่อน';
          _isLoading = false;
        });
        return;
      }

      // DEBUG: ทดสอบดึงข้อมูลทั้งหมดของ topic นี้ก่อน
      final allRows = await Supabase.instance.client
          .from('training_v_topic_detail')
          .select()
          .eq('topic_id', widget.topic.topicId);
      debugPrint('=== DEBUG training_v_topic_detail ===');
      debugPrint('Current userId: $userId');
      debugPrint('Topic ID: ${widget.topic.topicId}');
      debugPrint('All rows count: ${allRows.length}');
      for (var i = 0; i < allRows.length; i++) {
        final row = allRows[i];
        debugPrint('Row $i: user_id=${row['user_id']}, content_id=${row['content_id']}, content_title=${row['content_title']}');
      }
      debugPrint('=====================================');

      final response = await Supabase.instance.client
          .from('training_v_topic_detail')
          .select()
          .eq('topic_id', widget.topic.topicId)
          .or('user_id.eq.$userId,user_id.is.null')
          .maybeSingle();

      debugPrint('After filter - response: $response');

      if (mounted) {
        debugPrint('Topic detail response: $response');
        setState(() {
          if (response != null) {
            _topicDetail = TopicDetail.fromJson(response);
            debugPrint('hasQuestions: ${_topicDetail!.hasQuestions}, questionCount: ${_topicDetail!.questionCount}');
          } else {
            // Fallback to basic info from topic
            _topicDetail = TopicDetail(
              topicId: widget.topic.topicId,
              topicName: widget.topic.topicName,
              notionUrl: widget.topic.notionUrl,
              coverImageUrl: widget.topic.coverImageUrl,
            );
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadQuizHistory() async {
    try {
      final userId = UserService().effectiveUserId;
      if (userId == null) return;

      debugPrint('Loading quiz history for topic: ${widget.topic.topicId}, user: $userId');

      final response = await Supabase.instance.client
          .from('training_v_quiz_history')
          .select()
          .eq('topic_id', widget.topic.topicId)
          .eq('user_id', userId)
          .order('completed_at', ascending: false);

      debugPrint('Quiz history response: $response');

      if (mounted) {
        setState(() {
          _quizHistory = (response as List)
              .map((json) => QuizHistoryItem.fromJson(json))
              .toList();
          _isHistoryLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Quiz history error: $e');
      if (mounted) {
        setState(() => _isHistoryLoading = false);
      }
    }
  }

  void _onMarkAsRead() {
    _loadTopicDetail();
  }

  /// Select questions with balanced thinking_type and difficulty
  List<String> _selectBalancedQuestions(
    List<Map<String, dynamic>> allQuestions,
    int targetCount,
  ) {
    if (allQuestions.length <= targetCount) {
      final ids = allQuestions.map((q) => q['id'] as String).toList();
      ids.shuffle();
      return ids;
    }

    // Group questions by thinking_type
    final byThinkingType = <String, List<Map<String, dynamic>>>{};
    for (final q in allQuestions) {
      final type = (q['thinking_type'] as String?) ?? 'unknown';
      byThinkingType.putIfAbsent(type, () => []).add(q);
    }

    // Sort each group by difficulty to help distribute
    for (final group in byThinkingType.values) {
      group.shuffle(); // Shuffle first for randomness within same difficulty
      group.sort((a, b) => (a['difficulty'] as int).compareTo(b['difficulty'] as int));
    }

    final selected = <String>[];
    final usedIds = <String>{};

    // Round-robin selection across thinking types
    // This ensures we pick from different types evenly
    final types = byThinkingType.keys.toList()..shuffle();
    final typeIndices = <String, int>{for (final t in types) t: 0};

    // Track difficulty distribution
    final difficultyCount = <int, int>{1: 0, 2: 0, 3: 0};
    final targetPerDifficulty = targetCount ~/ 3; // Aim for equal distribution

    int typeIndex = 0;
    while (selected.length < targetCount) {
      final type = types[typeIndex % types.length];
      final questions = byThinkingType[type]!;
      final currentIdx = typeIndices[type]!;

      if (currentIdx < questions.length) {
        final question = questions[currentIdx];
        final qId = question['id'] as String;
        final difficulty = question['difficulty'] as int;

        // Check if we should skip this question for better difficulty balance
        bool shouldAdd = true;
        if (difficultyCount[difficulty]! >= targetPerDifficulty + 1) {
          // This difficulty is over-represented, try to find another
          // But only skip if there are more questions in this type to try
          if (currentIdx + 1 < questions.length) {
            shouldAdd = false;
          }
        }

        if (shouldAdd && !usedIds.contains(qId)) {
          selected.add(qId);
          usedIds.add(qId);
          difficultyCount[difficulty] = (difficultyCount[difficulty] ?? 0) + 1;
        }

        typeIndices[type] = currentIdx + 1;
      }

      typeIndex++;

      // Safety check: if we've gone through all types multiple times
      // and still haven't filled, just take any remaining questions
      if (typeIndex > types.length * allQuestions.length) {
        for (final q in allQuestions) {
          if (selected.length >= targetCount) break;
          final qId = q['id'] as String;
          if (!usedIds.contains(qId)) {
            selected.add(qId);
            usedIds.add(qId);
          }
        }
        break;
      }
    }

    // Final shuffle to randomize order
    selected.shuffle();
    return selected;
  }

  Future<void> _startQuiz() async {
    final userId = UserService().effectiveUserId;
    if (userId == null) return;

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      // Get active season
      final seasonResponse = await Supabase.instance.client
          .from('training_seasons')
          .select('id')
          .eq('is_active', true)
          .single();
      final seasonId = seasonResponse['id'] as String;

      // Ensure progress record exists (upsert)
      final progressResponse = await Supabase.instance.client
          .from('training_user_progress')
          .upsert(
            {
              'user_id': userId,
              'topic_id': widget.topic.topicId,
              'season_id': seasonId,
            },
            onConflict: 'user_id,topic_id,season_id',
          )
          .select('id')
          .single();
      final progressId = progressResponse['id'] as String;

      // Fetch all questions with thinking_type and difficulty
      final questionsResponse = await Supabase.instance.client
          .from('training_questions')
          .select('id, thinking_type, difficulty')
          .eq('topic_id', widget.topic.topicId)
          .eq('is_active', true);

      final allQuestions = (questionsResponse as List)
          .map((q) => {
                'id': q['id'] as String,
                'thinking_type': q['thinking_type'] as String?,
                'difficulty': q['difficulty'] as int? ?? 2,
              })
          .toList();

      if (allQuestions.isEmpty) {
        if (mounted) {
          Navigator.pop(context); // Close loading
          AppSnackbar.warning(context, 'ไม่มีคำถามในหัวข้อนี้');
        }
        return;
      }

      // Select questions with balanced thinking_type and difficulty
      final questionIds = _selectBalancedQuestions(allQuestions, 10);

      // Get attempt number
      final attemptNumber = _quizHistory
              .where((h) => h.quizType == 'posttest')
              .length +
          1;

      // Create quiz session
      final sessionResponse = await Supabase.instance.client
          .from('training_quiz_sessions')
          .insert({
            'user_id': userId,
            'topic_id': widget.topic.topicId,
            'season_id': seasonId,
            'progress_id': progressId,
            'quiz_type': 'posttest',
            'attempt_number': attemptNumber,
            'total_questions': questionIds.length,
            'passing_score': 8,
            'time_limit_seconds': 600,
            'question_ids': questionIds,
          })
          .select()
          .single();

      final session = QuizSession.fromJson(sessionResponse);

      if (mounted) {
        Navigator.pop(context); // Close loading

        // Navigate to quiz screen
        final result = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(
            builder: (_) => QuizScreen(
              session: session,
              topicName: widget.topic.topicName,
            ),
          ),
        );

        // Show result screen if quiz was completed
        if (result != null && mounted) {
          // ตรวจสอบและแจก badge
          final sessionId = result['sessionId'] as String?;
          final badgeService = BadgeService();
          final earnedBadges = sessionId != null
              ? await badgeService.checkAndAwardBadges(sessionId: sessionId)
              : <Badge>[];

          if (mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => QuizResultScreen(
                  topicName: widget.topic.topicName,
                  score: result['score'] as int,
                  totalQuestions: result['totalQuestions'] as int,
                  passingScore: result['passingScore'] as int,
                  isPassed: result['isPassed'] as bool,
                  onBackToTopic: () => Navigator.pop(context),
                  onTryAgain: !(result['isPassed'] as bool) ? _startQuiz : null,
                ),
              ),
            );

            // แสดง badge ที่ได้รับใหม่
            if (earnedBadges.isNotEmpty && mounted) {
              await BadgeEarnedDialog.show(context, earnedBadges);
            }
          }
        }

        // Refresh data after quiz
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        AppSnackbar.error(context, 'เกิดข้อผิดพลาด: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: IreneSecondaryAppBar(
        title: widget.topic.topicName,
        toolbarHeight: 72,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.secondaryText,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: AppTypography.label.copyWith(
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: AppTypography.label.copyWith(
            fontWeight: FontWeight.w400,
          ),
          tabs: const [
            Tab(text: 'อ่าน'),
            Tab(text: 'สอบ'),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ShimmerWrapper(
        isLoading: true,
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: List.generate(3, (_) => const SkeletonCard()),
          ),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('เกิดข้อผิดพลาด'),
            AppSpacing.verticalGapSm,
            Text(_error!, style: AppTypography.bodySmall.copyWith(color: AppColors.error)),
            AppSpacing.verticalGapMd,
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadData();
              },
              child: const Text('ลองใหม่'),
            ),
          ],
        ),
      );
    }

    if (_topicDetail == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/not_found.webp',
              width: 240,
              height: 240,
            ),
            AppSpacing.verticalGapMd,
            Text(
              'ไม่พบข้อมูล',
              style: AppTypography.body.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        ContentTab(
          topicDetail: _topicDetail!,
          onMarkAsRead: _onMarkAsRead,
        ),
        QuizTab(
          topicDetail: _topicDetail!,
          quizHistory: _quizHistory,
          isLoading: _isHistoryLoading,
          onStartQuiz: _startQuiz,
          skillsData: _skillsData,
        ),
      ],
    );
  }
}
