class TopicWithProgress {
  final String topicId;
  final String topicName;
  final String? topicType;
  final String? notionUrl;
  final String? coverImageUrl;
  final int? displayOrder;

  // Progress fields (from view)
  final String? progressId;
  final String? userId;
  final String? seasonId;
  final bool isRead;
  final int readCount;
  final DateTime? contentReadAt;
  final int? contentVersion;
  final int? contentVersionRead;
  final bool hasContentUpdate;
  final bool isPassed;
  final String quizStatus;
  final int? posttestScore;
  final int? lastReviewScore;
  final int posttestAttempts;
  final int reviewCount;
  final String masteryLevel;
  final DateTime? posttestCompletedAt;
  final DateTime? posttestLastAttemptAt;
  final DateTime? lastReviewAt;
  final DateTime? nextReviewAt;
  final DateTime? progressUpdatedAt;
  final int progressPercent;

  TopicWithProgress({
    required this.topicId,
    required this.topicName,
    this.topicType,
    this.notionUrl,
    this.coverImageUrl,
    this.displayOrder,
    this.progressId,
    this.userId,
    this.seasonId,
    this.isRead = false,
    this.readCount = 0,
    this.contentReadAt,
    this.contentVersion,
    this.contentVersionRead,
    this.hasContentUpdate = false,
    this.isPassed = false,
    this.quizStatus = 'not_started',
    this.posttestScore,
    this.lastReviewScore,
    this.posttestAttempts = 0,
    this.reviewCount = 0,
    this.masteryLevel = 'beginner',
    this.posttestCompletedAt,
    this.posttestLastAttemptAt,
    this.lastReviewAt,
    this.nextReviewAt,
    this.progressUpdatedAt,
    this.progressPercent = 0,
  });

  factory TopicWithProgress.fromJson(Map<String, dynamic> json) {
    return TopicWithProgress(
      topicId: json['topic_id'] as String,
      topicName: json['topic_name'] as String,
      topicType: json['topic_type'] as String?,
      notionUrl: json['notion_url'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      displayOrder: json['display_order'] as int?,
      progressId: json['progress_id'] as String?,
      userId: json['user_id'] as String?,
      seasonId: json['season_id'] as String?,
      isRead: json['is_read'] == true,
      readCount: json['read_count'] as int? ?? 0,
      contentReadAt: json['content_read_at'] != null
          ? DateTime.parse(json['content_read_at'])
          : null,
      contentVersion: json['content_version'] as int?,
      contentVersionRead: json['content_version_read'] as int?,
      hasContentUpdate: json['has_content_update'] == true,
      isPassed: json['is_passed'] == true,
      quizStatus: json['quiz_status'] as String? ?? 'not_started',
      posttestScore: json['posttest_score'] as int?,
      lastReviewScore: json['last_review_score'] as int?,
      posttestAttempts: json['posttest_attempts'] as int? ?? 0,
      reviewCount: json['review_count'] as int? ?? 0,
      masteryLevel: json['mastery_level'] as String? ?? 'beginner',
      posttestCompletedAt: json['posttest_completed_at'] != null
          ? DateTime.parse(json['posttest_completed_at'])
          : null,
      posttestLastAttemptAt: json['posttest_last_attempt_at'] != null
          ? DateTime.parse(json['posttest_last_attempt_at'])
          : null,
      lastReviewAt: json['last_review_at'] != null
          ? DateTime.parse(json['last_review_at'])
          : null,
      nextReviewAt: json['next_review_at'] != null
          ? DateTime.parse(json['next_review_at'])
          : null,
      progressUpdatedAt: json['progress_updated_at'] != null
          ? DateTime.parse(json['progress_updated_at'])
          : null,
      progressPercent: json['progress_percent'] as int? ?? 0,
    );
  }

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