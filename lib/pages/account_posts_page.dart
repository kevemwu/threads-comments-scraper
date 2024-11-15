import 'package:flutter/material.dart';
import '../models/post.dart';
import '../services/local_storage_service.dart';
import '../services/threads_scraper_service.dart';
import '../widgets/post_card.dart';
import '../widgets/better_video_player.dart';

class AccountPostsPage extends StatefulWidget {
  final String username;

  const AccountPostsPage({
    super.key,
    required this.username,
  });

  @override
  State<AccountPostsPage> createState() => _AccountPostsPageState();
}

class _AccountPostsPageState extends State<AccountPostsPage> {
  late Future<List<Post>> _postsFuture;
  late LocalStorageService _storageService;
  final _scraperService = ThreadsScraperService();
  bool _isDescending = true;
  bool _isRefreshing = false;
  String? _statusMessage;
  Color? _statusColor;

  @override
  void initState() {
    super.initState();
    _postsFuture = _initStorage();
  }

  Future<List<Post>> _initStorage() async {
    _storageService = await LocalStorageService.init();
    return _loadPosts();
  }

  Future<List<Post>> _loadPosts() async {
    final posts = await _storageService.getAccountPosts(widget.username);
    posts.sort((a, b) => _isDescending 
      ? b.datetime.compareTo(a.datetime)
      : a.datetime.compareTo(b.datetime)
    );
    return posts;
  }

  Future<void> _refreshPosts() async {
    setState(() {
      _isRefreshing = true;
      _statusMessage = '正在重新取得貼文...';
      _statusColor = Colors.grey;
    });

    try {
      final posts = await _scraperService.scrapeThreads(widget.username);
      await _storageService.saveAccountPosts(widget.username, posts);
      
      setState(() {
        _postsFuture = _loadPosts();
        _statusMessage = '貼文更新成功！';
        _statusColor = Colors.green;
      });
    } catch (e) {
      setState(() {
        _statusMessage = '更新失敗：$e';
        _statusColor = Colors.red;
      });
    } finally {
      setState(() {
        _isRefreshing = false;
      });
      
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _statusMessage = null;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('@${widget.username}'),
        actions: [
          Tooltip(
            message: '重新取得此帳號的所有貼文',
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isRefreshing ? null : _refreshPosts,
            ),
          ),
          Tooltip(
            message: _isDescending ? '目前：由新到舊' : '目前：由舊到新',
            child: TextButton.icon(
              icon: Icon(_isDescending ? Icons.arrow_downward : Icons.arrow_upward),
              label: Text(_isDescending ? '新到舊' : '舊到新'),
              onPressed: () {
                setState(() {
                  _isDescending = !_isDescending;
                  _postsFuture = _loadPosts();
                });
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_statusMessage != null)
            Container(
              padding: const EdgeInsets.all(8),
              width: double.infinity,
              color: _statusColor?.withOpacity(0.1),
              child: Text(
                _statusMessage!,
                style: TextStyle(color: _statusColor),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: FutureBuilder<List<Post>>(
              future: _postsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      '載入失敗：${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                final posts = snapshot.data ?? [];
                if (posts.isEmpty) {
                  return const Center(
                    child: Text('目前沒有任何貼文'),
                  );
                }

                return ListView.builder(
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    return PostCard(post: posts[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
