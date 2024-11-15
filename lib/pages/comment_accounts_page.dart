import 'package:flutter/material.dart';
import '../models/comment.dart';
import '../services/local_storage_service.dart';
import 'account_comments_page.dart';

class CommentAccountsPage extends StatefulWidget {
  final String username;

  const CommentAccountsPage({
    super.key,
    required this.username,
  });

  @override
  State<CommentAccountsPage> createState() => _CommentAccountsPageState();
}

class _CommentAccountsPageState extends State<CommentAccountsPage> {
  late LocalStorageService _storageService;
  bool _isLoading = true;
  String? _error;
  List<MapEntry<String, int>> _commenters = [];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      _storageService = await LocalStorageService.init();
      final allComments = _storageService.getAllComments(widget.username);
      
      // 計算每個帳號的留言數量並排序
      final commenterCounts = <String, int>{};
      for (var comment in allComments) {
        if (comment.username != widget.username) {
          commenterCounts[comment.username] = (commenterCounts[comment.username] ?? 0) + 1;
        }
      }

      _commenters = commenterCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '初始化失敗: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('@${widget.username} 的留言者'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('@${widget.username} 的留言者'),
        ),
        body: Center(
          child: Text(_error!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('@${widget.username} 的留言者'),
      ),
      body: ListView.builder(
        itemCount: _commenters.length + 1, // +1 for "全部留言" option
        itemBuilder: (context, index) {
          if (index == 0) {
            // 全部留言選項
            final totalComments = _commenters.fold(0, (sum, item) => sum + item.value);
            return ListTile(
              leading: const Icon(Icons.people),
              title: const Text('全部留言'),
              trailing: Text('$totalComments'),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AccountCommentsPage(
                      username: widget.username,
                      selectedCommenter: null,
                      post: {},
                    ),
                  ),
                );
              },
            );
          }

          final commenter = _commenters[index - 1];
          return ListTile(
            leading: const Icon(Icons.person),
            title: Text('@${commenter.key}'),
            trailing: Text('${commenter.value}'),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => AccountCommentsPage(
                    username: widget.username,
                    selectedCommenter: commenter.key,
                    post: {},
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
} 