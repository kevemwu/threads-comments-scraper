import 'thread.dart';

class Post {
  final String datetime;
  final String? content;
  final List<String> images;
  final int directRepliesCount;
  final List<Thread> threads;

  Post({
    required this.datetime,
    this.content,
    this.images = const [],
    this.directRepliesCount = 0,
    this.threads = const [],
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    try {
      // 檢查 threads 資料結構
      final threadsData = json['thread_items'] ?? json['threads'] ?? [];
      
      final threads = (threadsData as List).map((thread) {
        try {
          if (thread is Map) {
            return Thread.fromJson(Map<String, dynamic>.from(thread));
          } else {
            print('無效的留言串格式: $thread');
            return Thread(replies: []);
          }
        } catch (e) {
          print('解析留言串時發生錯誤: $e');
          print('問題留言串資料: $thread');
          return Thread(replies: []);
        }
      }).toList();

      return Post(
        datetime: json['datetime'] as String? ?? '',
        content: json['content'] as String?,
        images: (json['images'] as List?)?.cast<String>() ?? [],
        directRepliesCount: json['direct_replies_count'] as int? ?? 0,
        threads: threads,
      );
    } catch (e, stackTrace) {
      print('解析貼文時發生錯誤: $e');
      print('錯誤堆疊: $stackTrace');
      print('原始資料: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'datetime': datetime,
      'content': content,
      'images': images,
      'direct_replies_count': directRepliesCount,
      'threads': threads.map((thread) => thread.toJson()).toList(),
    };
  }
}
