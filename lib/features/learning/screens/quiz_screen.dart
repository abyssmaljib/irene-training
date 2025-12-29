import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../models/question.dart';
import '../models/quiz_session.dart';
import '../models/quiz_answer.dart';
import '../widgets/question_card.dart';
import '../widgets/explanation_card.dart';

class QuizScreen extends StatefulWidget {
  final QuizSession session;
  final String topicName;

  const QuizScreen({
    super.key,
    required this.session,
    required this.topicName,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List<Question> _questions = [];
  bool _isLoading = true;
  String? _error;

  int _currentIndex = 0;
  String? _selectedChoice;
  bool _isAnswered = false;
  int _score = 0;

  int _elapsedSeconds = 0;
  Timer? _timer;
  DateTime? _questionStartTime;

  final Map<String, QuizAnswer> _answers = {};

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    try {
      final response = await Supabase.instance.client
          .from('training_questions')
          .select()
          .inFilter('id', widget.session.questionIds)
          .eq('is_active', true);

      final questions = (response as List)
          .map((json) => Question.fromJson(json))
          .toList();

      // Sort by the order in questionIds
      final orderMap = <String, int>{};
      for (var i = 0; i < widget.session.questionIds.length; i++) {
        orderMap[widget.session.questionIds[i]] = i;
      }
      questions.sort((a, b) =>
          (orderMap[a.id] ?? 0).compareTo(orderMap[b.id] ?? 0));

      if (mounted) {
        setState(() {
          _questions = questions;
          _isLoading = false;
        });
        _startTimer();
        _questionStartTime = DateTime.now();
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

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _elapsedSeconds++);
    });
  }

  String get _formattedTime {
    final minutes = _elapsedSeconds ~/ 60;
    final seconds = _elapsedSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // สีตามเวลาที่ใช้
  // 0-10 นาที: เขียว, 10-15 นาที: ส้ม, >15 นาที: แดง
  Color get _timerBackgroundColor {
    if (_elapsedSeconds < 600) {
      return AppColors.tagPassedBg; // เขียว (0-10 นาที)
    } else if (_elapsedSeconds < 900) {
      return AppColors.tagPendingBg; // ส้ม (10-15 นาที)
    } else {
      return AppColors.tagFailedBg; // แดง (>15 นาที)
    }
  }

  Color get _timerTextColor {
    if (_elapsedSeconds < 600) {
      return AppColors.tagPassedText; // เขียว
    } else if (_elapsedSeconds < 900) {
      return AppColors.tagPendingText; // ส้ม
    } else {
      return AppColors.error; // แดง
    }
  }

  double get _progress => _questions.isEmpty
      ? 0
      : (_currentIndex + (_isAnswered ? 1 : 0)) / _questions.length;

  Question get _currentQuestion => _questions[_currentIndex];

  void _selectChoice(String key) {
    if (_isAnswered) return;
    setState(() => _selectedChoice = key);
  }

  Future<void> _confirmAnswer() async {
    if (_selectedChoice == null || _isAnswered) return;

    final question = _currentQuestion;
    final isCorrect = question.isCorrectAnswer(_selectedChoice!);
    final answerTime = _questionStartTime != null
        ? DateTime.now().difference(_questionStartTime!).inSeconds
        : null;

    final answer = QuizAnswer(
      sessionId: widget.session.id,
      questionId: question.id,
      selectedChoice: _selectedChoice!,
      isCorrect: isCorrect,
      answerTimeSeconds: answerTime,
    );

    setState(() {
      _isAnswered = true;
      if (isCorrect) _score++;
      _answers[question.id] = answer;
    });

    // Save answer to database
    try {
      await Supabase.instance.client
          .from('training_quiz_answers')
          .insert(answer.toJson());
    } catch (e) {
      debugPrint('Failed to save quiz answer: $e');
    }
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedChoice = null;
        _isAnswered = false;
        _questionStartTime = DateTime.now();
      });
    } else {
      _submitQuiz();
    }
  }

  Future<void> _submitQuiz() async {
    _timer?.cancel();

    final now = DateTime.now().toIso8601String();
    final isPassed = _score >= widget.session.passingScore;

    try {
      debugPrint('Submitting quiz: session=${widget.session.id}, score=$_score');

      // Update session with final score
      await Supabase.instance.client
          .from('training_quiz_sessions')
          .update({
            'score': _score,
            'completed_at': now,
          })
          .eq('id', widget.session.id);

      // Update training_user_progress
      final progressUpdate = <String, dynamic>{
        'posttest_score': _score,
        'posttest_last_attempt_at': now,
      };

      // ถ้าเป็น posttest และผ่าน ให้ set posttest_completed_at
      if (widget.session.quizType == 'posttest' && isPassed) {
        progressUpdate['posttest_completed_at'] = now;
      }

      // ถ้าเป็น review ให้ update review fields
      if (widget.session.quizType == 'review') {
        progressUpdate['last_review_score'] = _score;
        progressUpdate['last_review_at'] = now;
      }

      // ดึง current attempts ก่อน แล้ว increment
      final currentProgress = await Supabase.instance.client
          .from('training_user_progress')
          .select('posttest_attempts, review_count')
          .eq('id', widget.session.progressId)
          .single();

      final currentAttempts = currentProgress['posttest_attempts'] as int? ?? 0;
      final currentReviewCount = currentProgress['review_count'] as int? ?? 0;

      // เพิ่ม attempts/review_count ตาม quiz type
      if (widget.session.quizType == 'posttest') {
        progressUpdate['posttest_attempts'] = currentAttempts + 1;
      } else if (widget.session.quizType == 'review') {
        progressUpdate['review_count'] = currentReviewCount + 1;
      }

      await Supabase.instance.client
          .from('training_user_progress')
          .update(progressUpdate)
          .eq('id', widget.session.progressId);

      debugPrint('Quiz submitted successfully');
    } catch (e) {
      debugPrint('Error submitting quiz: $e');
    }

    if (mounted) {
      // Pop back to TopicDetailScreen
      Navigator.of(context).pop({
        'score': _score,
        'totalQuestions': _questions.length,
        'passingScore': widget.session.passingScore,
        'isPassed': _score >= widget.session.passingScore,
        'sessionId': widget.session.id,
      });
    }
  }

  Future<bool> _onWillPop() async {
    final shouldExit = await ConfirmDialog.show(
      context,
      type: ConfirmDialogType.exitQuiz,
    );

    if (shouldExit) {
      _timer?.cancel();
      // Delete incomplete session
      try {
        await Supabase.instance.client
            .from('training_quiz_sessions')
            .delete()
            .eq('id', widget.session.id);
      } catch (e) {
        debugPrint('Failed to delete incomplete session: $e');
      }
    }

    return shouldExit;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          navigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.primaryBackground,
        appBar: AppBar(
          backgroundColor: AppColors.secondaryBackground,
          automaticallyImplyLeading: false,
          toolbarHeight: 72,
          titleSpacing: 0,
          leading: IconButton(
            icon: const Icon(Iconsax.close_square),
            onPressed: () async {
              final navigator = Navigator.of(context);
              final shouldPop = await _onWillPop();
              if (shouldPop && mounted) {
                navigator.pop();
              }
            },
          ),
          title: Text(
            widget.topicName,
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm + 4, vertical: 6),
              decoration: BoxDecoration(
                color: _timerBackgroundColor,
                borderRadius: AppRadius.mediumRadius,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Iconsax.timer_1,
                    size: 16,
                    color: _timerTextColor,
                  ),
                  AppSpacing.horizontalGapXs,
                  Text(
                    _formattedTime,
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: _timerTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
          centerTitle: false,
          elevation: 0,
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('เกิดข้อผิดพลาด', style: AppTypography.body),
            AppSpacing.verticalGapSm,
            Text(_error!, style: AppTypography.body.copyWith(color: AppColors.error)),
            AppSpacing.verticalGapMd,
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadQuestions();
              },
              child: Text('ลองใหม่'),
            ),
          ],
        ),
      );
    }

    if (_questions.isEmpty) {
      return Center(
        child: Text(
          'ไม่พบคำถาม',
          style: AppTypography.body,
        ),
      );
    }

    return Column(
      children: [
        // Progress bar
        LinearProgressIndicator(
          value: _progress,
          backgroundColor: AppColors.alternate,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          minHeight: 4,
        ),

        // Question card
        Expanded(
          child: QuestionCard(
            question: _currentQuestion,
            questionNumber: _currentIndex + 1,
            totalQuestions: _questions.length,
            selectedChoice: _selectedChoice,
            isAnswered: _isAnswered,
            onChoiceSelected: _selectChoice,
          ),
        ),

        // Confirm button or Explanation
        if (!_isAnswered)
          Container(
            width: double.infinity,
            padding: AppSpacing.paddingMd,
            child: SafeArea(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _selectedChoice != null ? _confirmAnswer : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.alternate,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.smallRadius,
                    ),
                  ),
                  child: Text(
                    'ยืนยันคำตอบ',
                    style: AppTypography.button.copyWith(
                      color: AppColors.surface,
                    ),
                  ),
                ),
              ),
            ),
          )
        else
          ExplanationCard(
            isCorrect: _currentQuestion.isCorrectAnswer(_selectedChoice!),
            correctAnswer: _currentQuestion.correctChoice.text,
            explanation: _currentQuestion.explanation,
            explanationImageUrl: _currentQuestion.explanationImageUrl,
            onNext: _nextQuestion,
            isLastQuestion: _currentIndex == _questions.length - 1,
          ),
      ],
    );
  }
}
