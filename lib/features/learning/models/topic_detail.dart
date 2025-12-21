class TopicDetail {
  final String topicId;
  final String topicName;
  final String? notionUrl;
  final String? coverImageUrl;
  final int? displayOrder;
  final String? contentId;
  final String? contentTitle;
  final String? contentMarkdown;
  final String? contentSummary;
  final int? readingTimeMinutes;
  final DateTime? contentSyncedAt;
  final int? contentVersion;
  final int? contentVersionRead;
  final bool hasContentUpdate;
  final String? userId;
  final String? seasonId;
  final String? progressId;
  final bool isRead;
  final int readCount;
  final bool isPassed;
  final String quizStatus;
  final int? posttestScore;
  final int? lastReviewScore;
  final int posttestAttempts;
  final int reviewCount;
  final String masteryLevel;
  final DateTime? contentReadAt;
  final DateTime? posttestCompletedAt;
  final DateTime? posttestLastAttemptAt;
  final DateTime? lastReviewAt;
  final DateTime? nextReviewAt;
  final int questionCount;

  const TopicDetail({
    required this.topicId,
    required this.topicName,
    this.notionUrl,
    this.coverImageUrl,
    this.displayOrder,
    this.contentId,
    this.contentTitle,
    this.contentMarkdown,
    this.contentSummary,
    this.readingTimeMinutes,
    this.contentSyncedAt,
    this.contentVersion,
    this.contentVersionRead,
    this.hasContentUpdate = false,
    this.userId,
    this.seasonId,
    this.progressId,
    this.isRead = false,
    this.readCount = 0,
    this.isPassed = false,
    this.quizStatus = 'not_started',
    this.posttestScore,
    this.lastReviewScore,
    this.posttestAttempts = 0,
    this.reviewCount = 0,
    this.masteryLevel = 'beginner',
    this.contentReadAt,
    this.posttestCompletedAt,
    this.posttestLastAttemptAt,
    this.lastReviewAt,
    this.nextReviewAt,
    this.questionCount = 0,
  });

  factory TopicDetail.fromJson(Map<String, dynamic> json) {
    return TopicDetail(
      topicId: json['topic_id'] as String,
      topicName: json['topic_name'] as String,
      notionUrl: json['notion_url'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      displayOrder: json['display_order'] as int?,
      contentId: json['content_id'] as String?,
      contentTitle: json['content_title'] as String?,
      contentMarkdown: json['content_markdown'] as String?,
      contentSummary: json['content_summary'] as String?,
      readingTimeMinutes: json['reading_time_minutes'] as int?,
      contentSyncedAt: json['content_synced_at'] != null
          ? DateTime.parse(json['content_synced_at'] as String)
          : null,
      contentVersion: json['content_version'] as int?,
      contentVersionRead: json['content_version_read'] as int?,
      hasContentUpdate: json['has_content_update'] == true,
      userId: json['user_id'] as String?,
      seasonId: json['season_id'] as String?,
      progressId: json['progress_id'] as String?,
      isRead: json['is_read'] == true,
      readCount: json['read_count'] as int? ?? 0,
      isPassed: json['is_passed'] == true,
      quizStatus: json['quiz_status'] as String? ?? 'not_started',
      posttestScore: json['posttest_score'] as int?,
      lastReviewScore: json['last_review_score'] as int?,
      posttestAttempts: json['posttest_attempts'] as int? ?? 0,
      reviewCount: json['review_count'] as int? ?? 0,
      masteryLevel: json['mastery_level'] as String? ?? 'beginner',
      contentReadAt: json['content_read_at'] != null
          ? DateTime.parse(json['content_read_at'] as String)
          : null,
      posttestCompletedAt: json['posttest_completed_at'] != null
          ? DateTime.parse(json['posttest_completed_at'] as String)
          : null,
      posttestLastAttemptAt: json['posttest_last_attempt_at'] != null
          ? DateTime.parse(json['posttest_last_attempt_at'] as String)
          : null,
      lastReviewAt: json['last_review_at'] != null
          ? DateTime.parse(json['last_review_at'] as String)
          : null,
      nextReviewAt: json['next_review_at'] != null
          ? DateTime.parse(json['next_review_at'] as String)
          : null,
      questionCount: json['question_count'] as int? ?? 0,
    );
  }

  bool get hasContent => contentMarkdown != null && contentMarkdown!.isNotEmpty;
  bool get hasQuestions => questionCount > 0;

  /// คำนวณว่าอยู่ใน cooldown หรือไม่ (12 ชม. หลังทำข้อสอบ)
  bool get isInCooldown {
    if (posttestLastAttemptAt == null) return false;
    final cooldownEnd = posttestLastAttemptAt!.add(const Duration(hours: 12));
    return DateTime.now().isBefore(cooldownEnd);
  }

  /// เวลาที่เหลือก่อน cooldown จะหมด
  Duration? get cooldownRemaining {
    if (posttestLastAttemptAt == null) return null;
    final cooldownEnd = posttestLastAttemptAt!.add(const Duration(hours: 12));
    final remaining = cooldownEnd.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }

  /// แสดง cooldown เป็นข้อความ (เช่น "23 ชม." หรือ "45 นาที")
  String? get cooldownRemainingText {
    final remaining = cooldownRemaining;
    if (remaining == null) return null;

    if (remaining.inHours >= 1) {
      return '${remaining.inHours} ชม.';
    } else if (remaining.inMinutes >= 1) {
      return '${remaining.inMinutes} นาที';
    } else {
      return 'ไม่กี่วินาที';
    }
  }
}
