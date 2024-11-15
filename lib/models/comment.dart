class Comment {
  final String username;
  final String datetime;
  final String? content;
  final List<String> images;
  final List<String>? videos;
  final String? postContent;
  final String? postDateTime;

  Comment({
    required this.username,
    required this.datetime,
    this.content,
    this.images = const [],
    this.videos,
    this.postContent,
    this.postDateTime,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      username: json['username'] as String,
      datetime: json['datetime'] as String,
      content: json['content'] as String?,
      images: (json['images'] as List?)?.map((e) => e.toString()).toList() ?? [],
      videos: (json['videos'] as List?)?.map((e) => e.toString()).toList(),
      postContent: json['post_content'] as String?,
      postDateTime: json['post_datetime'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'datetime': datetime,
      'content': content,
      'images': images,
      'videos': videos,
      'post_content': postContent,
      'post_datetime': postDateTime,
    };
  }

  String get formattedDateTime {
    final dt = DateTime.parse(datetime);
    return '${dt.year}年${dt.month}月${dt.day}日${dt.hour}時${dt.minute}分';
  }

  String get uniqueId => '${username}_${datetime}_${postContent?.hashCode ?? 0}';
} 