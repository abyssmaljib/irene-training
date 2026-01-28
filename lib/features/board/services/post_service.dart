import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post.dart';
import '../models/post_tab.dart';
import '../models/post_filter.dart';

/// Service สำหรับจัดการ Posts
/// ใช้ in-memory cache เพื่อลด API calls
class PostService {
  static final instance = PostService._();
  PostService._();

  final _supabase = Supabase.instance.client;

  // Cache configuration
  List<Post>? _cachedPosts;
  int? _cachedNursinghomeId;
  PostFilter? _cachedFilter;
  DateTime? _cacheTime;
  static const _cacheMaxAge = Duration(minutes: 2);

  // Unread counts cache
  Map<PostMainTab, int>? _cachedUnreadCounts;
  int? _unreadCacheNursinghomeId;
  String? _unreadCacheUserId;
  DateTime? _unreadCacheTime;
  static const _unreadCacheMaxAge = Duration(minutes: 1);

  /// ตรวจสอบว่า cache ยังใช้ได้อยู่
  bool _isCacheValid(int nursinghomeId, PostFilter filter) {
    if (_cachedNursinghomeId != nursinghomeId) return false;
    if (_cachedFilter != filter) return false;
    if (_cachedPosts == null) return false;
    if (_cacheTime == null) return false;
    return DateTime.now().difference(_cacheTime!) < _cacheMaxAge;
  }

  /// ตรวจสอบว่า unread cache ยังใช้ได้อยู่
  bool _isUnreadCacheValid(int nursinghomeId, String userId) {
    if (_unreadCacheNursinghomeId != nursinghomeId) return false;
    if (_unreadCacheUserId != userId) return false;
    if (_cachedUnreadCounts == null) return false;
    if (_unreadCacheTime == null) return false;
    return DateTime.now().difference(_unreadCacheTime!) < _unreadCacheMaxAge;
  }

  /// ล้าง cache ทั้งหมด
  void invalidateCache() {
    _cachedPosts = null;
    _cacheTime = null;
    _cachedUnreadCounts = null;
    _unreadCacheTime = null;
    debugPrint('PostService: cache invalidated');
  }

  /// ดึง posts ตาม filter
  /// limit: จำนวน posts ต่อหน้า (default 10 สำหรับ infinite scroll)
  /// offset: ตำแหน่งเริ่มต้น
  /// Returns: (posts, hasMoreOnServer) - hasMore คำนวณจากจำนวนที่ server ส่งมา
  ///          ไม่ใช่หลัง client-side filter
  Future<(List<Post>, bool)> getPostsWithPagination({
    required int nursinghomeId,
    required PostFilter filter,
    String? currentUserId,
    int limit = 10,
    int offset = 0,
    bool forceRefresh = false,
  }) async {
    final posts = await getPosts(
      nursinghomeId: nursinghomeId,
      filter: filter,
      currentUserId: currentUserId,
      limit: limit,
      offset: offset,
      forceRefresh: forceRefresh,
    );
    // hasMore คำนวณจาก _lastServerPostCount ที่เก็บไว้ใน getPosts
    return (posts, _lastServerPostCount >= limit);
  }

  // เก็บจำนวน posts จาก server ก่อน client-side filter
  int _lastServerPostCount = 0;

  /// ดึง posts ตาม filter
  /// limit: จำนวน posts ต่อหน้า (default 10 สำหรับ infinite scroll)
  /// offset: ตำแหน่งเริ่มต้น
  Future<List<Post>> getPosts({
    required int nursinghomeId,
    required PostFilter filter,
    String? currentUserId,
    int limit = 10,
    int offset = 0,
    bool forceRefresh = false,
  }) async {
    // ใช้ cache ถ้ายังใช้ได้ (สำหรับ offset = 0 เท่านั้น)
    if (!forceRefresh &&
        offset == 0 &&
        _isCacheValid(nursinghomeId, filter)) {
      debugPrint('getPosts: using cached data (${_cachedPosts!.length} posts)');
      return _cachedPosts!;
    }

    try {
      final stopwatch = Stopwatch()..start();

      // Build query with all filters applied in chain
      var query = _supabase.from('postwithuserinfo').select();

      // Apply nursinghome filter
      query = query.eq('nursinghome_id', nursinghomeId);

      // Apply tab filter - V3: ศูนย์ vs ผู้พัก
      if (filter.isResidentTab) {
        // ผู้พัก tab: posts ที่มี resident_id และ is_handover = true
        query = query.not('resident_id', 'is', null).eq('is_handover', true);
      } else {
        // ศูนย์ tab: posts ที่ไม่มี resident_id
        query = query.isFilter('resident_id', null);
      }

      // Apply resident filter
      if (filter.selectedResidentId != null) {
        query = query.eq('resident_id', filter.selectedResidentId!);
      }

      // Apply search filter
      if (filter.searchQuery.isNotEmpty) {
        final searchTerm = '%${filter.searchQuery}%';
        query = query.or('title.ilike.$searchTerm,Text.ilike.$searchTerm');
      }

      // Execute query with ordering and pagination
      final response = await query
          .order('post_created_at', ascending: false)
          .range(offset, offset + limit - 1);

      stopwatch.stop();

      var posts = (response as List).map((json) => Post.fromJson(json)).toList();

      // เก็บจำนวน posts จาก server ก่อน filter
      // ใช้สำหรับเช็ค hasMore ใน pagination (ผ่าน getPostsWithPagination)
      _lastServerPostCount = posts.length;

      // Apply filter type (client-side filtering for complex conditions)
      if (currentUserId != null) {
        switch (filter.filterType) {
          case PostFilterType.unacknowledged:
            posts = posts.where((p) => !p.hasUserLiked(currentUserId)).toList();
            break;
          case PostFilterType.myPosts:
            posts = posts.where((p) => p.isUserAuthor(currentUserId)).toList();
            break;
          case PostFilterType.all:
            break;
        }
      }

      // Update cache (only for first page)
      if (offset == 0) {
        _cachedNursinghomeId = nursinghomeId;
        _cachedFilter = filter;
        _cachedPosts = posts;
        _cacheTime = DateTime.now();
      }

      debugPrint(
          'getPosts: fetched ${posts.length} posts (server: $_lastServerPostCount) in ${stopwatch.elapsedMilliseconds}ms');

      return posts;
    } catch (e) {
      debugPrint('getPosts error: $e');
      rethrow;
    }
  }

  /// ดึง post เดี่ยวตาม ID
  Future<Post?> getPostById(int postId) async {
    try {
      final response = await _supabase
          .from('postwithuserinfo')
          .select()
          .eq('id', postId)
          .maybeSingle();

      if (response == null) return null;
      return Post.fromJson(response);
    } catch (e) {
      debugPrint('getPostById error: $e');
      return null;
    }
  }

  /// ดึง pinned Critical post ล่าสุด
  Future<Post?> getPinnedCriticalPost(int nursinghomeId) async {
    try {
      final response = await _supabase
          .from('postwithuserinfo')
          .select()
          .eq('nursinghome_id', nursinghomeId)
          .eq('tab', 'Announcements-Critical')
          .order('post_created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return Post.fromJson(response);
    } catch (e) {
      debugPrint('getPinnedCriticalPost error: $e');
      return null;
    }
  }

  /// ดึงจำนวน unread posts ต่อ tab - V3: 2 tabs
  /// เงื่อนไขบังคับอ่าน: is_handover = true หรือ resident_id IS NULL
  Future<Map<PostMainTab, int>> getUnreadCounts(
    int nursinghomeId,
    String userId,
  ) async {
    // ใช้ cache ถ้ายังใช้ได้
    if (_isUnreadCacheValid(nursinghomeId, userId)) {
      return _cachedUnreadCounts!;
    }

    try {
      // ดึงโพส 14 วันล่าสุด
      final fourteenDaysAgo = DateTime.now().subtract(const Duration(days: 14));

      final response = await _supabase
          .from('postwithuserinfo')
          .select('like_user_ids, resident_id, is_handover')
          .eq('nursinghome_id', nursinghomeId)
          .gte('post_created_at', fourteenDaysAgo.toIso8601String());

      final counts = <PostMainTab, int>{
        PostMainTab.announcement: 0,
        PostMainTab.resident: 0,
      };

      for (final row in response as List) {
        final likeUserIds = row['like_user_ids'] as List?;
        final residentId = row['resident_id'];
        final isHandover = row['is_handover'] as bool? ?? false;

        // Check if user has NOT liked this post
        final hasLiked = likeUserIds?.contains(userId) ?? false;
        if (hasLiked) continue;

        // นับเฉพาะโพสที่บังคับอ่าน: is_handover = true หรือ resident_id IS NULL
        // Tab ผู้พัก = posts ที่มี resident_id และ is_handover = true
        if (residentId != null && isHandover) {
          counts[PostMainTab.resident] =
              (counts[PostMainTab.resident] ?? 0) + 1;
        }
        // Tab ศูนย์ = posts ที่ไม่มี resident_id
        else if (residentId == null) {
          counts[PostMainTab.announcement] =
              (counts[PostMainTab.announcement] ?? 0) + 1;
        }
        // โพสที่มี resident แต่ไม่ใช่ handover → ไม่นับ (ไม่บังคับอ่าน)
      }

      // Update cache
      _unreadCacheNursinghomeId = nursinghomeId;
      _unreadCacheUserId = userId;
      _cachedUnreadCounts = counts;
      _unreadCacheTime = DateTime.now();

      return counts;
    } catch (e) {
      debugPrint('getUnreadCounts error: $e');
      return {
        PostMainTab.announcement: 0,
        PostMainTab.resident: 0,
      };
    }
  }

  /// ดึง post IDs ที่ยังไม่ได้อ่าน (สำหรับหน้าเคลียร์โพส)
  /// เงื่อนไข: is_handover = true หรือ resident_id IS NULL (14 วันล่าสุด)
  /// เรียงจากใหม่ไปเก่า
  Future<List<int>> getUnreadPostIds(int nursinghomeId, String userId) async {
    try {
      final fourteenDaysAgo = DateTime.now().subtract(const Duration(days: 14));

      final response = await _supabase
          .from('postwithuserinfo')
          .select('id, like_user_ids, is_handover, resident_id')
          .eq('nursinghome_id', nursinghomeId)
          .gte('post_created_at', fourteenDaysAgo.toIso8601String())
          .order('post_created_at', ascending: false);

      // Filter: (is_handover = true OR resident_id IS NULL) AND user ยังไม่ได้ like
      final unreadPostIds = (response as List).where((post) {
        final isHandover = post['is_handover'] as bool? ?? false;
        final residentId = post['resident_id'];
        final likeUserIds = post['like_user_ids'] as List? ?? [];

        final isRequiredPost = isHandover || residentId == null;
        return isRequiredPost && !likeUserIds.contains(userId);
      }).map((post) => post['id'] as int).toList();

      return unreadPostIds;
    } catch (e) {
      debugPrint('getUnreadPostIds error: $e');
      return [];
    }
  }

  /// ค้นหา posts
  Future<List<Post>> searchPosts({
    required int nursinghomeId,
    required String query,
    PostMainTab? tab,
    int limit = 20,
  }) async {
    if (query.isEmpty) return [];

    try {
      final searchTerm = '%$query%';

      var dbQuery = _supabase
          .from('postwithuserinfo')
          .select()
          .eq('nursinghome_id', nursinghomeId)
          .or('title.ilike.$searchTerm,Text.ilike.$searchTerm');

      // Apply tab filter if specified
      if (tab != null) {
        final tabValues = tab.dbTabValues;
        if (tabValues.length == 1) {
          dbQuery = dbQuery.eq('tab', tabValues.first);
        } else {
          dbQuery = dbQuery.inFilter('tab', tabValues);
        }
      }

      final response = await dbQuery
          .order('post_created_at', ascending: false)
          .limit(limit);

      return (response as List).map((json) => Post.fromJson(json)).toList();
    } catch (e) {
      debugPrint('searchPosts error: $e');
      return [];
    }
  }

  /// ดึง posts ที่ link กับ resident คนนี้
  Future<List<Post>> getPostsByResident({
    required int nursinghomeId,
    required int residentId,
    int limit = 10,
  }) async {
    try {
      final response = await _supabase
          .from('postwithuserinfo')
          .select()
          .eq('nursinghome_id', nursinghomeId)
          .eq('resident_id', residentId)
          .order('post_created_at', ascending: false)
          .limit(limit);

      return (response as List).map((json) => Post.fromJson(json)).toList();
    } catch (e) {
      debugPrint('getPostsByResident error: $e');
      return [];
    }
  }

  /// ดึงรายชื่อ residents สำหรับ filter
  /// ใช้ table residents และ filter เฉพาะ s_status = 'Stay'
  Future<List<Map<String, dynamic>>> getResidents(int nursinghomeId) async {
    try {
      final response = await _supabase
          .from('residents')
          .select('''
            id,
            i_Name_Surname,
            i_picture_url,
            s_zone,
            nursinghome_zone(id, zone)
          ''')
          .eq('nursinghome_id', nursinghomeId)
          .eq('s_status', 'Stay')
          .order('i_Name_Surname');

      return (response as List).map((r) {
        final zoneData = r['nursinghome_zone'] as Map<String, dynamic>?;
        return {
          'id': r['id'],
          'Name': r['i_Name_Surname'],
          'i_Picture_url': r['i_picture_url'],
          'zone_name': zoneData?['zone'],
        };
      }).toList();
    } catch (e) {
      debugPrint('getResidents error: $e');
      return [];
    }
  }
}

