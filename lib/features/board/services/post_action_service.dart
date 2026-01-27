import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service สำหรับ actions บน Posts (like, create)
class PostActionService {
  static final instance = PostActionService._();
  PostActionService._();

  final _supabase = Supabase.instance.client;

  /// Toggle like/acknowledge บน post
  /// Returns true if liked, false if unliked
  Future<bool> toggleLike(int postId, String userId) async {
    try {
      // Check if already liked
      final existing = await _supabase
          .from('Post_likes')
          .select('id')
          .eq('Post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        // Unlike - delete the like
        await _supabase
            .from('Post_likes')
            .delete()
            .eq('id', existing['id']);
        debugPrint('PostActionService: unliked post $postId');
        return false;
      } else {
        // Like - insert new like
        await _supabase.from('Post_likes').insert({
          'Post_id': postId,
          'user_id': userId,
        });
        debugPrint('PostActionService: liked post $postId');
        return true;
      }
    } catch (e) {
      debugPrint('toggleLike error: $e');
      rethrow;
    }
  }

  /// Like a post (without toggle, just add if not exists)
  Future<bool> likePost(int postId, String userId) async {
    try {
      // Check if already liked
      final existing = await _supabase
          .from('Post_likes')
          .select('id')
          .eq('Post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        // Already liked
        return true;
      }

      // Insert new like
      await _supabase.from('Post_likes').insert({
        'Post_id': postId,
        'user_id': userId,
      });
      debugPrint('PostActionService: liked post $postId');
      return true;
    } catch (e) {
      debugPrint('likePost error: $e');
      return false;
    }
  }

  /// Unlike a post
  Future<bool> unlikePost(int postId, String userId) async {
    try {
      await _supabase
          .from('Post_likes')
          .delete()
          .eq('Post_id', postId)
          .eq('user_id', userId);
      debugPrint('PostActionService: unliked post $postId');
      return true;
    } catch (e) {
      debugPrint('unlikePost error: $e');
      return false;
    }
  }

  /// Create a new post
  ///
  /// Supports both legacy params (tagTopics, residentIds) and new params (tagId, tagName, residentId)
  Future<int?> createPost({
    required String userId,
    required int nursinghomeId,
    required String text,
    String? title,
    // New tag system (single tag)
    int? tagId,
    String? tagName,
    bool isHandover = false,
    // Single resident (new)
    int? residentId,
    // Multiple residents (legacy)
    List<int>? residentIds,
    List<String>? taggedUserIds,
    // Legacy tag topics
    List<String>? tagTopics,
    String? imgUrl,
    // New: imageUrls parameter
    List<String>? imageUrls,
    // Legacy: multiImgUrl parameter
    List<String>? multiImgUrl,
    String? youtubeUrl,
    bool visibleToRelative = false,
    // Quiz fields (for advanced post)
    String? qaQuestion,
    String? qaChoiceA,
    String? qaChoiceB,
    String? qaChoiceC,
    String? qaAnswer,
    // DD Record link (for DD handover posts)
    int? ddId,
  }) async {
    try {
      // Build Tag_Topics from tagName if provided
      List<String>? finalTagTopics = tagTopics;
      if (tagName != null && tagName.isNotEmpty) {
        finalTagTopics = [tagName];
      }

      // Use imageUrls if provided, otherwise use multiImgUrl
      final finalImageUrls = imageUrls ?? multiImgUrl;

      // Create QA entry if quiz data is provided
      int? qaId;
      if (qaQuestion != null &&
          qaQuestion.trim().isNotEmpty &&
          qaChoiceA != null &&
          qaChoiceB != null &&
          qaChoiceC != null &&
          qaAnswer != null) {
        final qaResponse = await _supabase.from('QATable').insert({
          'question': qaQuestion,
          'choiceA': qaChoiceA,
          'choiceB': qaChoiceB,
          'choiceC': qaChoiceC,
          'answer': qaAnswer,
        }).select('id').single();
        qaId = qaResponse['id'] as int;
        debugPrint('PostActionService: created QA entry $qaId');
      }

      // Insert post
      final response = await _supabase.from('Post').insert({
        'user_id': userId,
        'nursinghome_id': nursinghomeId,
        'Text': text,
        'title': title,
        'imgUrl': imgUrl,
        'multi_img_url': finalImageUrls,
        'youtubeUrl': youtubeUrl,
        'tagged_user': taggedUserIds,
        'Tag_Topics': finalTagTopics,
        'visible_to_relative': visibleToRelative,
        'is_handover': isHandover,
        'qa_id': qaId,
        if (ddId != null) 'DD_id': ddId,
      }).select('id').single();

      final postId = response['id'] as int;

      // Link to single resident if provided (new)
      if (residentId != null) {
        await _supabase.from('Post_Resident_id').insert({
          'Post_id': postId,
          'resident_id': residentId,
        });
      }
      // Link to multiple residents if provided (legacy)
      else if (residentIds != null && residentIds.isNotEmpty) {
        final residentLinks = residentIds
            .map((rid) => {
                  'Post_id': postId,
                  'resident_id': rid,
                })
            .toList();

        await _supabase.from('Post_Resident_id').insert(residentLinks);
      }

      debugPrint('PostActionService: created post $postId (handover: $isHandover)');

      // Auto-acknowledge: ผู้สร้างโพสให้ถือว่ารับทราบโพสตัวเองโดยอัตโนมัติ
      // เพื่อไม่ต้องกลับมากด like โพสตัวเองอีกรอบ
      await likePost(postId, userId);
      debugPrint('PostActionService: auto-acknowledged post $postId for creator');

      return postId;
    } catch (e) {
      debugPrint('createPost error: $e');
      return null;
    }
  }

  /// Update post text/title and images
  /// For shift leader+: also supports updating tag and resident
  Future<bool> updatePost({
    required int postId,
    String? text,
    String? title,
    String? imgUrl,
    List<String>? multiImgUrl,
    // Quiz fields - pass existing qaId if updating, null if creating new
    int? existingQaId,
    String? qaQuestion,
    String? qaChoiceA,
    String? qaChoiceB,
    String? qaChoiceC,
    String? qaAnswer,
    // Tag and Resident fields (for shift leader+ editing)
    String? tagName, // ถ้าส่งมา = เปลี่ยน tag, null = ไม่เปลี่ยน
    int? residentId, // ถ้าส่ง -1 = ลบ resident, null = ไม่เปลี่ยน, >0 = เปลี่ยน
    bool? isHandover,
  }) async {
    try {
      final updates = <String, dynamic>{
        'last_modified_at': DateTime.now().toIso8601String(),
      };
      if (text != null) updates['Text'] = text;
      if (title != null) updates['title'] = title;
      if (imgUrl != null) updates['imgUrl'] = imgUrl;
      if (multiImgUrl != null) updates['multi_img_url'] = multiImgUrl;

      // Handle tag update (Tag_Topics is array of tag names)
      if (tagName != null) {
        updates['Tag_Topics'] = [tagName];
        debugPrint('PostActionService: updating tag to $tagName');
      }

      // Handle handover flag update
      if (isHandover != null) {
        updates['is_handover'] = isHandover;
        debugPrint('PostActionService: updating is_handover to $isHandover');
      }

      // Handle quiz update/create
      final hasQuizData = qaQuestion != null &&
          qaQuestion.trim().isNotEmpty &&
          qaChoiceA != null &&
          qaChoiceB != null &&
          qaChoiceC != null &&
          qaAnswer != null;

      if (hasQuizData) {
        if (existingQaId != null) {
          // Update existing QA
          await _supabase.from('QATable').update({
            'question': qaQuestion,
            'choiceA': qaChoiceA,
            'choiceB': qaChoiceB,
            'choiceC': qaChoiceC,
            'answer': qaAnswer,
          }).eq('id', existingQaId);
          debugPrint('PostActionService: updated QA entry $existingQaId');
        } else {
          // Create new QA and link to post
          final qaResponse = await _supabase.from('QATable').insert({
            'question': qaQuestion,
            'choiceA': qaChoiceA,
            'choiceB': qaChoiceB,
            'choiceC': qaChoiceC,
            'answer': qaAnswer,
          }).select('id').single();
          final newQaId = qaResponse['id'] as int;
          updates['qa_id'] = newQaId;
          debugPrint('PostActionService: created new QA entry $newQaId for post $postId');
        }
      }

      // Update the Post table
      await _supabase.from('Post').update(updates).eq('id', postId);
      debugPrint('PostActionService: updated post $postId');

      // Handle resident update (uses Post_Resident_id junction table)
      if (residentId != null) {
        // ลบ resident เดิมก่อน
        await _supabase.from('Post_Resident_id').delete().eq('Post_id', postId);
        debugPrint('PostActionService: deleted existing resident links for post $postId');

        // เพิ่ม resident ใหม่ (ถ้า residentId > 0)
        if (residentId > 0) {
          await _supabase.from('Post_Resident_id').insert({
            'Post_id': postId,
            'resident_id': residentId,
          });
          debugPrint('PostActionService: linked post $postId to resident $residentId');
        }
      }

      return true;
    } catch (e) {
      debugPrint('updatePost error: $e');
      return false;
    }
  }

  /// Delete a post
  Future<bool> deletePost(int postId) async {
    try {
      // Delete related records first
      await _supabase.from('Post_likes').delete().eq('Post_id', postId);
      await _supabase.from('Post_Resident_id').delete().eq('Post_id', postId);
      await _supabase.from('Post_Tags').delete().eq('Post_id', postId);

      // Delete the post
      await _supabase.from('Post').delete().eq('id', postId);
      debugPrint('PostActionService: deleted post $postId');
      return true;
    } catch (e) {
      debugPrint('deletePost error: $e');
      return false;
    }
  }

  /// Create notification for new announcement
  Future<void> createAnnouncementNotification({
    required int postId,
    required int nursinghomeId,
    required String title,
    required String postType, // 'Critical' or 'Policy'
  }) async {
    try {
      // Get all users in this nursinghome
      final users = await _supabase
          .from('user_info')
          .select('id')
          .eq('nursinghome_id', nursinghomeId);

      if (users.isEmpty) return;

      // Create inbox entries for all users
      final notifications = (users as List).map((user) => {
            'user_id': user['id'],
            'post_id': postId,
            'title': postType == 'Critical' ? '🔴 ประกาศสำคัญ' : '🟠 ประกาศนโยบาย',
            'desc': title,
          }).toList();

      await _supabase.from('Inbox').insert(notifications);
      debugPrint('PostActionService: created ${notifications.length} notifications');
    } catch (e) {
      debugPrint('createAnnouncementNotification error: $e');
    }
  }

  /// Cancel PRN LINE notification
  Future<bool> cancelPrnNotification(int queueId) async {
    try {
      await _supabase.from('PrnPostQueue').update({
        'status': 'canceling...',
      }).eq('id', queueId);
      debugPrint('PostActionService: canceled PRN queue $queueId');
      return true;
    } catch (e) {
      debugPrint('cancelPrnNotification error: $e');
      return false;
    }
  }

  /// Cancel Log LINE notification
  Future<bool> cancelLogLineNotification(int queueId) async {
    try {
      await _supabase.from('TaskLogLineQueue').update({
        'status': 'canceling...',
      }).eq('id', queueId);
      debugPrint('PostActionService: canceled Log LINE queue $queueId');
      return true;
    } catch (e) {
      debugPrint('cancelLogLineNotification error: $e');
      return false;
    }
  }
}
