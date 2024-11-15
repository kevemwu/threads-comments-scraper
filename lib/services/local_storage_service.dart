import 'package:hive_flutter/hive_flutter.dart';
import '../models/post.dart';
import '../models/comment.dart';

class LocalStorageService {
  late Box _box;
  
  static Future<LocalStorageService> init() async {
    await Hive.initFlutter();
    await Hive.openBox('accounts');
    final service = LocalStorageService();
    service._box = Hive.box('accounts');
    return service;
  }

  List<String> getSearchedAccounts() {
    final accounts = _box.get('searched_accounts');
    return accounts != null ? List<String>.from(accounts) : [];
  }

  String getSearchTime(String username) {
    final searchTime = _box.get('${username}_search_time');
    return searchTime ?? DateTime.now().toIso8601String();
  }

  Future<void> saveAccountPosts(String username, List<Post> posts) async {
    await _box.put('${username}_posts', posts.map((p) => p.toJson()).toList());
    await _box.put('${username}_search_time', DateTime.now().toIso8601String());
    
    final accounts = getSearchedAccounts();
    if (!accounts.contains(username)) {
      accounts.add(username);
      await _box.put('searched_accounts', accounts);
    }
  }

  List<Post> getAccountPosts(String username) {
    try {
      final postsData = _box.get('${username}_posts');
      if (postsData == null) {
        print('找不到 $username 的貼文資料');
        return [];
      }
      
      final posts = (postsData as List).map((p) {
        try {
          return Post.fromJson(Map<String, dynamic>.from(p));
        } catch (e) {
          print('解析貼文時發生錯誤: $e');
          print('問題貼文資料: $p');
          rethrow;
        }
      }).toList();
      
      print('成功解析貼文數量: ${posts.length}');
      return posts;
    } catch (e, stackTrace) {
      print('獲取貼文時發生錯誤: $e');
      print('錯誤堆疊: $stackTrace');
      return [];
    }
  }

  Future<void> deleteAccount(String username) async {
    await _box.delete('${username}_posts');
    await _box.delete('${username}_search_time');
    
    final accounts = getSearchedAccounts();
    accounts.remove(username);
    await _box.put('searched_accounts', accounts);
  }

  List<Comment> getAllComments(String username) {
    try {
      print('開始獲取 $username 的所有留言');
      final posts = getAccountPosts(username);
      print('成功獲取貼文，數量: ${posts.length}');
      
      final List<Comment> allComments = [];
      
      for (final post in posts) {
        if (post.threads.isEmpty) {
          continue;
        }
        
        for (final thread in post.threads) {
          // 只收集不是目標用戶發的留言
          final filteredReplies = thread.replies
              .where((reply) => reply.username != username)
              .toList();
          allComments.addAll(filteredReplies);
        }
      }
      
      print('總共收集到的留言數: ${allComments.length}');
      return allComments;
    } catch (e, stackTrace) {
      print('獲取留言時發生錯誤: $e');
      print('錯誤堆疊: $stackTrace');
      rethrow;
    }
  }
}