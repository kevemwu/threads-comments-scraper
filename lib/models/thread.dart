import 'comment.dart';

class Thread {
  final List<Comment> replies;

  Thread({
    required this.replies,
  });

  factory Thread.fromJson(Map<dynamic, dynamic> json) {
    try {
      final repliesData = json['replies'] as List;
      final replies = repliesData
          .map((reply) => Comment.fromJson(Map<String, dynamic>.from(reply)))
          .toList();
      return Thread(replies: replies);
    } catch (e) {
      print('解析 Thread 時發生錯誤: $e');
      return Thread(replies: []);
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'replies': replies.map((reply) => reply.toJson()).toList(),
    };
  }
}