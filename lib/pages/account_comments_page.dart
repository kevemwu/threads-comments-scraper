import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/comment.dart';
import '../services/local_storage_service.dart';
import '../services/threads_scraper_service.dart';
import 'package:flutter/gestures.dart';
import 'comment_accounts_page.dart';
import '../widgets/better_video_player.dart';

class AccountCommentsPage extends StatefulWidget {
  final String username;
  final String? selectedCommenter;
  final String? videoUrl;
  final Map<String, dynamic> post;

  const AccountCommentsPage({
    Key? key,
    required this.username,
    this.selectedCommenter,
    this.videoUrl,
    required this.post,
  }) : super(key: key);

  @override
  State<AccountCommentsPage> createState() => _AccountCommentsPageState();
}

class _AccountCommentsPageState extends State<AccountCommentsPage> {
  late LocalStorageService _storageService;
  bool _isDescending = true;
  String? _selectedCommenter;
  List<Comment> _comments = [];
  Set<String> _commenters = {};
  bool _isLoading = true;
  String? _error;
  bool _isRefreshing = false;
  final Map<String, bool> _expandedPosts = {};
  bool _isCancelled = false;
  bool _showText = true;
  bool _showImages = true;
  bool _showVideos = true;

  @override
  void initState() {
    super.initState();
    _selectedCommenter = widget.selectedCommenter;
    _initData();
  }

  Future<void> _initData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      _storageService = await LocalStorageService.init();
      _loadComments();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '初始化失敗: $e';
        _isLoading = false;
      });
      print('初始化錯誤: $e');
    }
  }

  void _loadComments() {
    try {
      final allComments = _storageService.getAllComments(widget.username);
      
      _commenters = allComments.map((c) => c.username).toSet()
        ..remove(widget.username);

      setState(() {
        if (_selectedCommenter != null) {
          _comments = allComments
              .where((c) => c.username == _selectedCommenter)
              .toList();
        } else {
          _comments = allComments
              .where((c) => c.username != widget.username)
              .toList();
        }

        _comments = _comments.where((comment) {
          bool hasText = comment.content?.isNotEmpty ?? false;
          bool hasImages = comment.images.isNotEmpty;
          bool hasVideos = comment.videos?.isNotEmpty ?? false;

          return (_showText && hasText) ||
                 (_showImages && hasImages) ||
                 (_showVideos && hasVideos);
        }).toList();

        if (_isDescending) {
          _comments.sort((a, b) => b.datetime.compareTo(a.datetime));
        } else {
          _comments.sort((a, b) => a.datetime.compareTo(b.datetime));
        }
      });
    } catch (e) {
      setState(() {
        _error = '載入留言失敗: $e';
      });
      print('載入留言錯誤: $e');
    }
  }

  Future<void> _refreshComments() async {
    setState(() {
      _isRefreshing = true;
      _error = null;
      _isCancelled = false;
    });

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return WillPopScope(
            onWillPop: () async => false,
            child: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      const Text('正在取得留言中...'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isCancelled = true;
                            _isRefreshing = false;
                          });
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                '已取消取得留言',
                                style: TextStyle(color: Colors.orange),
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('取消'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    try {
      final scraperService = ThreadsScraperService();
      
      if (_isCancelled) return;

      final posts = await scraperService.scrapeThreads(widget.username);
      
      if (_isCancelled) return;

      await _storageService.saveAccountPosts(widget.username, posts);
      
      if (_isCancelled) return;

      _loadComments();

      if (mounted && !_isCancelled) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '留言更新成功！',
              style: TextStyle(color: Colors.green),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted && !_isCancelled) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '更新失敗: $e',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  List<Widget> _buildAppBarActions() {
    return [
      IconButton(
        icon: Icon(_isDescending ? Icons.arrow_downward : Icons.arrow_upward),
        onPressed: () {
          setState(() {
            _isDescending = !_isDescending;
            _loadComments();
          });
        },
        tooltip: _isDescending ? '由新到舊排序' : '由舊到新排序',
      ),
      IconButton(
        icon: const Icon(Icons.refresh),
        onPressed: _isRefreshing ? null : _refreshComments,
        tooltip: '重新取得留言',
      ),
    ];
  }

  Widget _buildPostInfo(Comment comment) {
    final postId = comment.uniqueId;
    final isExpanded = _expandedPosts[postId] ?? false;
    final firstLine = comment.postContent?.split('\n').first ?? '無內容';
    final hasMoreContent = (comment.postContent ?? '').split('\n').length > 1;
    
    return InkWell(
      onTap: () {
        setState(() {
          _expandedPosts[postId] = !isExpanded;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Theme.of(context).colorScheme.surfaceVariant,
        child: Row(
          children: [
            const Icon(Icons.comment, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isExpanded ? (comment.postContent ?? '無內容') : firstLine,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: isExpanded ? null : 1,
                    overflow: isExpanded ? null : TextOverflow.ellipsis,
                  ),
                  if (hasMoreContent)
                    Text(
                      isExpanded ? '收合貼文' : '...查看更多',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 12,
                      ),
                    ),
                  if (comment.postDateTime != null)
                    Text(
                      '發布時間：${DateTime.parse(comment.postDateTime!).year}年${DateTime.parse(comment.postDateTime!).month}月${DateTime.parse(comment.postDateTime!).day}日',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGallery(List<String> images) {
    return SizedBox(
      height: 200,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
          },
        ),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: images.length,
          itemBuilder: (context, imageIndex) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Image.network(
                images[imageIndex],
                height: 200,
                fit: BoxFit.cover,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterMenu() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '內容類型篩選',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.text_fields, size: 16),
                    const SizedBox(width: 4),
                    const Text('文字'),
                  ],
                ),
                selected: _showText,
                onSelected: (bool selected) {
                  setState(() {
                    _showText = selected;
                    _loadComments();
                  });
                },
              ),
              FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.image, size: 16),
                    const SizedBox(width: 4),
                    const Text('圖片'),
                  ],
                ),
                selected: _showImages,
                onSelected: (bool selected) {
                  setState(() {
                    _showImages = selected;
                    _loadComments();
                  });
                },
              ),
              FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.videocam, size: 16),
                    const SizedBox(width: 4),
                    const Text('影片'),
                  ],
                ),
                selected: _showVideos,
                onSelected: (bool selected) {
                  setState(() {
                    _showVideos = selected;
                    _loadComments();
                  });
                },
              ),
            ],
          ),
          const Divider(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('@${widget.username} 的留言')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          ..._buildAppBarActions(),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openEndDrawer();
              },
            ),
          ),
        ],
        title: Text(
          _selectedCommenter != null 
            ? '@${_selectedCommenter} 的留言 (${_comments.length})'
            : '全部留言 (${_comments.length})',
        ),
      ),
      endDrawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: Text(
                '@${widget.username} 的留言者',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            _buildFilterMenu(),
            ListTile(
              leading: const Icon(Icons.people),
              title: Text('全部留言 (${_storageService.getAllComments(widget.username).where((c) => c.username != widget.username).length})'),
              selected: _selectedCommenter == null,
              onTap: () {
                setState(() {
                  _selectedCommenter = null;
                  _loadComments();
                });
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ..._getCommentersListTiles(),
          ],
        ),
      ),
      body: Builder(
        builder: (BuildContext context) {
          if (_comments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '沒有找到符合條件的留言',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.filter_list),
                    label: const Text('調整篩選條件'),
                    onPressed: () {
                      Scaffold.of(context).openEndDrawer();
                    },
                  ),
                ],
              ),
            );
          }
          
          return ListView.builder(
            itemCount: _comments.length,
            itemBuilder: (context, index) {
              final comment = _comments[index];
              return Card(
                margin: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPostInfo(comment),
                    ListTile(
                      title: Text('@${comment.username}'),
                      subtitle: Text(comment.content ?? ''),
                      trailing: Text(
                        comment.formattedDateTime,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    if (comment.images.isNotEmpty)
                      _buildImageGallery(comment.images),
                    if (comment.videos != null && comment.videos!.isNotEmpty)
                      Container(
                        height: 200,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: comment.videos!.length,
                          itemBuilder: (context, videoIndex) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: SizedBox(
                                width: 300,
                                child: _buildVideoPlayer(comment.videos![videoIndex]),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  List<Widget> _getCommentersListTiles() {
    final allComments = _storageService.getAllComments(widget.username)
        .where((c) => c.username != widget.username)
        .toList();
    
    final commenterCounts = <String, int>{};
    for (var comment in allComments) {
      commenterCounts[comment.username] = (commenterCounts[comment.username] ?? 0) + 1;
    }
    
    final sortedCommenters = commenterCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedCommenters.map((entry) {
      return ListTile(
        leading: const Icon(Icons.person),
        title: Text('@${entry.key}'),
        trailing: Text('${entry.value}'),
        selected: _selectedCommenter == entry.key,
        onTap: () {
          setState(() {
            _selectedCommenter = entry.key;
            _loadComments();
          });
          Navigator.pop(context);
        },
      );
    }).toList();
  }

  Widget _buildVideoPlayer(String videoUrl) {
    return BetterVideoPlayer(videoUrl: videoUrl);
  }

  @override
  void dispose() {
    super.dispose();
  }
} 