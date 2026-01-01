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

  /// Create a new post (Admin only)
  Future<int?> createPost({
    required String userId,
    required int nursinghomeId,
    required String text,
    String? title,
    List<int>? residentIds,
    List<String>? taggedUserIds,
    List<String>? tagTopics,
    String? imgUrl,
    List<String>? multiImgUrl,
    String? youtubeUrl,
    bool visibleToRelative = false,
  }) async {
    try {
      // Insert post
      final response = await _supabase.from('Post').insert({
        'user_id': userId,
        'nursinghome_id': nursinghomeId,
        'Text': text,
        'title': title,
        'imgUrl': imgUrl,
        'multi_img_url': multiImgUrl,
        'youtubeUrl': youtubeUrl,
        'tagged_user': taggedUserIds,
        'Tag_Topics': tagTopics,
        'visible_to_relative': visibleToRelative,
      }).select('id').single();

      final postId = response['id'] as int;

      // Link to residents if provided
      if (residentIds != null && residentIds.isNotEmpty) {
        final residentLinks = residentIds
            .map((residentId) => {
                  'Post_id': postId,
                  'resident_id': residentId,
                })
            .toList();

        await _supabase.from('Post_Resident_id').insert(residentLinks);
      }

      debugPrint('PostActionService: created post $postId');
      return postId;
    } catch (e) {
      debugPrint('createPost error: $e');
      return null;
    }
  }

  /// Update post text/title
  Future<bool> updatePost({
    required int postId,
    String? text,
    String? title,
  }) async {
    try {
      final updates = <String, dynamic>{
        'last_modified_at': DateTime.now().toIso8601String(),
      };
      if (text != null) updates['Text'] = text;
      if (title != null) updates['title'] = title;

      await _supabase.from('Post').update(updates).eq('id', postId);
      debugPrint('PostActionService: updated post $postId');
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
