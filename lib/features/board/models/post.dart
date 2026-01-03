import 'post_tab.dart';

/// Post model based on postwithuserinfo view
class Post {
  final int id;
  final DateTime createdAt;
  final String? userId;
  final String? text;
  final String? title;
  final String? youtubeUrl;
  final String? imgUrl;
  final int? nursinghomeId;
  final bool? visibleToRelative;
  final int? replyTo;

  // User info
  final String? postUserNickname;
  final String? photoUrl;
  final String? userGroup;

  // Resident info
  final int? residentId;
  final String? residentName;
  final String? residentPictureUrl;
  final int? zoneId;
  final String? residentZone;
  final String? residentSpecialStatus;

  // Tags & Tabs
  final List<String> postTags;
  final String? postTagsString;
  final List<String> postTabs;
  final String? tab; // prioritized_tab: 'Announcements-Critical', etc.
  final bool isImportant;

  // Tagged users
  final List<String> taggedUser;
  final List<String> taggedUserNicknames;
  final int numberOfTaggedUsers;

  // Likes
  final List<String> likeUserIds;
  final List<String> likeUserNicknames;
  final int likeCountMinusOne;
  final String? lastLikeNickname;
  final String? lastLikePhotoUrl;

  // Images
  final List<String> multiImgUrl;
  final List<String> multiImgUrlThumb;

  // Calendar
  final List<int> calendarIds;

  // Task done by
  final String? taskDoneByNickname;
  final String? taskDoneById;

  // QA (Quiz)
  final int? qaId;
  final String? qaQuestion;
  final String? qaChoiceA;
  final String? qaChoiceB;
  final String? qaChoiceC;
  final String? qaAnswer;

  // Latest update
  final DateTime? latestUpdateTime;

  // LINE notification status
  final String? prnStatus;
  final int? prnQueueId;
  final String? logLineStatus;
  final int? logLineQueueId;

  // Handover flag
  final bool isHandover;

  const Post({
    required this.id,
    required this.createdAt,
    this.userId,
    this.text,
    this.title,
    this.youtubeUrl,
    this.imgUrl,
    this.nursinghomeId,
    this.visibleToRelative,
    this.replyTo,
    this.postUserNickname,
    this.photoUrl,
    this.userGroup,
    this.residentId,
    this.residentName,
    this.residentPictureUrl,
    this.zoneId,
    this.residentZone,
    this.residentSpecialStatus,
    this.postTags = const [],
    this.postTagsString,
    this.postTabs = const [],
    this.tab,
    this.isImportant = false,
    this.taggedUser = const [],
    this.taggedUserNicknames = const [],
    this.numberOfTaggedUsers = 0,
    this.likeUserIds = const [],
    this.likeUserNicknames = const [],
    this.likeCountMinusOne = 0,
    this.lastLikeNickname,
    this.lastLikePhotoUrl,
    this.multiImgUrl = const [],
    this.multiImgUrlThumb = const [],
    this.calendarIds = const [],
    this.taskDoneByNickname,
    this.taskDoneById,
    this.qaId,
    this.qaQuestion,
    this.qaChoiceA,
    this.qaChoiceB,
    this.qaChoiceC,
    this.qaAnswer,
    this.latestUpdateTime,
    this.prnStatus,
    this.prnQueueId,
    this.logLineStatus,
    this.logLineQueueId,
    this.isHandover = false,
  });

  /// Factory constructor from JSON (postwithuserinfo view)
  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as int,
      createdAt: DateTime.parse(json['post_created_at'] as String),
      userId: json['user_id'] as String?,
      text: json['Text'] as String?,
      title: json['title'] as String?,
      youtubeUrl: json['youtubeUrl'] as String?,
      imgUrl: json['imgUrl'] as String?,
      nursinghomeId: json['nursinghome_id'] as int?,
      visibleToRelative: json['visible_to_relative'] as bool?,
      replyTo: json['reply_to'] as int?,
      postUserNickname: json['post_user_nickname'] as String?,
      photoUrl: json['photo_url'] as String?,
      userGroup: json['user_group'] as String?,
      residentId: json['resident_id'] as int?,
      residentName: json['resident_name'] as String?,
      residentPictureUrl: json['resident_i_picture_url'] as String?,
      zoneId: json['zone_id'] as int?,
      residentZone: json['resident_zone'] as String?,
      residentSpecialStatus: json['resident_s_special_status'] as String?,
      postTags: _parseStringList(json['post_tags']),
      postTagsString: json['post_tags_string'] as String?,
      postTabs: _parseStringList(json['post_tabs']),
      tab: json['tab'] as String?,
      isImportant: json['Importent'] as bool? ?? false,
      taggedUser: _parseStringList(json['tagged_user']),
      taggedUserNicknames: _parseStringList(json['tagged_user_nicknames']),
      numberOfTaggedUsers: json['number_of_tagged_users'] as int? ?? 0,
      likeUserIds: _parseStringList(json['like_user_ids']),
      likeUserNicknames: _parseStringList(json['like_user_nicknames']),
      likeCountMinusOne: json['like_count_minus_one'] as int? ?? 0,
      lastLikeNickname: json['last_like_nickname'] as String?,
      lastLikePhotoUrl: json['last_like_photo_url'] as String?,
      multiImgUrl: _parseStringList(json['multi_img_url']),
      multiImgUrlThumb: _parseStringList(json['multi_img_url_thumb']),
      calendarIds: _parseIntList(json['calendar_ids']),
      taskDoneByNickname: json['task_done_by_nickname'] as String?,
      taskDoneById: json['task_done_by_id'] as String?,
      qaId: json['qa_id'] as int?,
      qaQuestion: json['qa_question'] as String?,
      qaChoiceA: json['qa_choice_a'] as String?,
      qaChoiceB: json['qa_choice_b'] as String?,
      qaChoiceC: json['qa_choice_c'] as String?,
      qaAnswer: json['qa_answer'] as String?,
      latestUpdateTime: json['latest_update_time'] != null
          ? DateTime.parse(json['latest_update_time'] as String)
          : null,
      prnStatus: json['prn_status'] as String?,
      prnQueueId: json['prn_queue_id'] as int?,
      logLineStatus: json['log_line_status'] as String?,
      logLineQueueId: json['log_line_queue_id'] as int?,
      isHandover: json['is_handover'] as bool? ?? false,
    );
  }

  /// Helper to parse string list from JSON
  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }

  /// Helper to parse int list from JSON
  static List<int> _parseIntList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0).toList();
    }
    return [];
  }

  // Computed properties

  /// Check if post is an announcement
  bool get isAnnouncement => tab?.startsWith('Announcements') ?? false;

  /// Check if post is Critical announcement
  bool get isCritical => tab == 'Announcements-Critical';

  /// Check if post is Policy announcement
  bool get isPolicy => tab == 'Announcements-Policy';

  /// Check if post is Info announcement
  bool get isInfo => tab == 'Announcements-Info';

  /// Check if post is FYI
  bool get isFyi => tab == 'FYI' || tab == null;

  /// Check if post is Calendar
  bool get isCalendar => tab == 'Calendar';

  /// Check if post has quiz
  bool get hasQuiz => qaId != null;

  /// Check if post has images
  bool get hasImages => multiImgUrl.isNotEmpty || (imgUrl?.isNotEmpty ?? false);

  /// Check if post has video
  bool get hasVideo => youtubeUrl?.isNotEmpty ?? false;

  /// Get all image URLs (combining single and multi)
  List<String> get allImageUrls {
    final urls = <String>[];
    if (imgUrl?.isNotEmpty ?? false) urls.add(imgUrl!);
    urls.addAll(multiImgUrl);
    return urls;
  }

  /// Get total like count
  int get likeCount => likeCountMinusOne + 1;

  /// Check if current user has liked the post
  bool hasUserLiked(String? currentUserId) {
    if (currentUserId == null) return false;
    return likeUserIds.contains(currentUserId);
  }

  /// Check if current user is tagged in the post
  bool isUserTagged(String? currentUserId) {
    if (currentUserId == null) return false;
    return taggedUser.contains(currentUserId);
  }

  /// Check if current user is the post author
  bool isUserAuthor(String? currentUserId) {
    if (currentUserId == null || userId == null) return false;
    return userId == currentUserId;
  }

  /// Get the main tab type - V3: 2 tabs only
  /// นโยบาย = Policy only
  /// ส่งเวร = is_handover = true (รวม Critical)
  PostMainTab get mainTab {
    // นโยบาย = Policy เท่านั้น
    if (isPolicy) return PostMainTab.announcement;
    // ส่งเวร = is_handover = true (รวม Critical และทุกอย่างที่สำคัญ)
    if (isHandover || isCritical) return PostMainTab.handover;
    // ที่เหลือ (FYI, Info) จะไม่แสดงใน Board แต่แสดงใน Activity Log
    return PostMainTab.handover; // fallback
  }

  /// Get display text (truncated content for card)
  String get displayText {
    final content = text ?? '';
    if (content.length <= 150) return content;
    return '${content.substring(0, 150)}...';
  }

  /// Get display title
  String get displayTitle => title ?? '';

  /// Copy with method for updates
  Post copyWith({
    int? id,
    DateTime? createdAt,
    String? userId,
    String? text,
    String? title,
    String? youtubeUrl,
    String? imgUrl,
    int? nursinghomeId,
    bool? visibleToRelative,
    int? replyTo,
    String? postUserNickname,
    String? photoUrl,
    String? userGroup,
    int? residentId,
    String? residentName,
    String? residentPictureUrl,
    int? zoneId,
    String? residentZone,
    String? residentSpecialStatus,
    List<String>? postTags,
    String? postTagsString,
    List<String>? postTabs,
    String? tab,
    bool? isImportant,
    List<String>? taggedUser,
    List<String>? taggedUserNicknames,
    int? numberOfTaggedUsers,
    List<String>? likeUserIds,
    List<String>? likeUserNicknames,
    int? likeCountMinusOne,
    String? lastLikeNickname,
    String? lastLikePhotoUrl,
    List<String>? multiImgUrl,
    List<String>? multiImgUrlThumb,
    List<int>? calendarIds,
    String? taskDoneByNickname,
    String? taskDoneById,
    int? qaId,
    String? qaQuestion,
    String? qaChoiceA,
    String? qaChoiceB,
    String? qaChoiceC,
    String? qaAnswer,
    DateTime? latestUpdateTime,
    String? prnStatus,
    int? prnQueueId,
    String? logLineStatus,
    int? logLineQueueId,
    bool? isHandover,
  }) {
    return Post(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
      text: text ?? this.text,
      title: title ?? this.title,
      youtubeUrl: youtubeUrl ?? this.youtubeUrl,
      imgUrl: imgUrl ?? this.imgUrl,
      nursinghomeId: nursinghomeId ?? this.nursinghomeId,
      visibleToRelative: visibleToRelative ?? this.visibleToRelative,
      replyTo: replyTo ?? this.replyTo,
      postUserNickname: postUserNickname ?? this.postUserNickname,
      photoUrl: photoUrl ?? this.photoUrl,
      userGroup: userGroup ?? this.userGroup,
      residentId: residentId ?? this.residentId,
      residentName: residentName ?? this.residentName,
      residentPictureUrl: residentPictureUrl ?? this.residentPictureUrl,
      zoneId: zoneId ?? this.zoneId,
      residentZone: residentZone ?? this.residentZone,
      residentSpecialStatus: residentSpecialStatus ?? this.residentSpecialStatus,
      postTags: postTags ?? this.postTags,
      postTagsString: postTagsString ?? this.postTagsString,
      postTabs: postTabs ?? this.postTabs,
      tab: tab ?? this.tab,
      isImportant: isImportant ?? this.isImportant,
      taggedUser: taggedUser ?? this.taggedUser,
      taggedUserNicknames: taggedUserNicknames ?? this.taggedUserNicknames,
      numberOfTaggedUsers: numberOfTaggedUsers ?? this.numberOfTaggedUsers,
      likeUserIds: likeUserIds ?? this.likeUserIds,
      likeUserNicknames: likeUserNicknames ?? this.likeUserNicknames,
      likeCountMinusOne: likeCountMinusOne ?? this.likeCountMinusOne,
      lastLikeNickname: lastLikeNickname ?? this.lastLikeNickname,
      lastLikePhotoUrl: lastLikePhotoUrl ?? this.lastLikePhotoUrl,
      multiImgUrl: multiImgUrl ?? this.multiImgUrl,
      multiImgUrlThumb: multiImgUrlThumb ?? this.multiImgUrlThumb,
      calendarIds: calendarIds ?? this.calendarIds,
      taskDoneByNickname: taskDoneByNickname ?? this.taskDoneByNickname,
      taskDoneById: taskDoneById ?? this.taskDoneById,
      qaId: qaId ?? this.qaId,
      qaQuestion: qaQuestion ?? this.qaQuestion,
      qaChoiceA: qaChoiceA ?? this.qaChoiceA,
      qaChoiceB: qaChoiceB ?? this.qaChoiceB,
      qaChoiceC: qaChoiceC ?? this.qaChoiceC,
      qaAnswer: qaAnswer ?? this.qaAnswer,
      latestUpdateTime: latestUpdateTime ?? this.latestUpdateTime,
      prnStatus: prnStatus ?? this.prnStatus,
      prnQueueId: prnQueueId ?? this.prnQueueId,
      logLineStatus: logLineStatus ?? this.logLineStatus,
      logLineQueueId: logLineQueueId ?? this.logLineQueueId,
      isHandover: isHandover ?? this.isHandover,
    );
  }

  // LINE notification helpers

  /// Check if has pending PRN notification
  bool get hasPrnStatus => prnStatus != null && prnStatus!.isNotEmpty;

  /// Check if has pending Log LINE notification
  bool get hasLogLineStatus => logLineStatus != null && logLineStatus!.isNotEmpty;

  /// Check if PRN can be canceled
  bool canCancelPrn(String? currentUserId, String? userRole) {
    if (prnStatus != 'waiting') return false;
    if (currentUserId == null) return false;
    return userId == currentUserId ||
        userRole == 'admin' ||
        userRole == 'superAdmin';
  }

  /// Check if Log LINE can be canceled
  bool canCancelLogLine(String? currentUserId, String? userRole) {
    if (logLineStatus != 'waiting') return false;
    if (currentUserId == null) return false;
    return userId == currentUserId ||
        userRole == 'admin' ||
        userRole == 'superAdmin';
  }

  @override
  String toString() => 'Post(id: $id, title: $title, tab: $tab)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Post && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
