import 'package:flutter/material.dart';
import '../services/local_storage_service.dart';
import '../services/threads_scraper_service.dart';
import 'account_posts_page.dart';
import 'account_comments_page.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class AccountSearchPage extends StatefulWidget {
  const AccountSearchPage({super.key});

  @override
  State<AccountSearchPage> createState() => _AccountSearchPageState();
}

class _AccountSearchPageState extends State<AccountSearchPage> {
  final _controller = TextEditingController();
  final _scraperService = ThreadsScraperService();
  late LocalStorageService _storageService;
  List<String> _searchedAccounts = [];
  bool _isLoading = false;
  String _loadingMessage = '';

  @override
  void initState() {
    super.initState();
    _initStorage();
  }

  Future<void> _initStorage() async {
    _storageService = await LocalStorageService.init();
    _loadSearchedAccounts();
  }

  Future<void> _loadSearchedAccounts() async {
    final accounts = _storageService.getSearchedAccounts();
    setState(() {
      _searchedAccounts = accounts;
    });
  }

  String _formatDateTime(String isoString) {
    final dt = DateTime.parse(isoString);
    return '${dt.year}年${dt.month}月${dt.day}日${dt.hour}時${dt.minute}分';
  }

  Future<void> _searchAccount(String username) async {
    if (username.isEmpty) return;

    if (_searchedAccounts.contains(username)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已有 @$username 的搜尋紀錄')),
        );
      }
      return;
    }

    await _forceSearchAccount(username);
  }

  Future<void> _forceSearchAccount(String username) async {
    setState(() {
      _isLoading = true;
      _loadingMessage = '正在取得 @$username 的貼文...';
    });

    try {
      print('開始搜尋帳號: $username');
      
      setState(() {
        _loadingMessage = '正在取得所有留言...';
      });
      
      final posts = await _scraperService.scrapeThreads(username);
      print('取得貼文數量: ${posts.length}');
      
      setState(() {
        _loadingMessage = '正在儲存資料...';
      });
      
      await _storageService.saveAccountPosts(username, posts);
      print('已儲存貼文');
      
      await _loadSearchedAccounts();
      print('已更新搜尋列表');

      // 清空搜尋欄
      _controller.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('搜尋完成'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('錯誤詳情: $e');
      if (mounted) {
        String errorMessage = '搜尋失敗';
        
        // 根據錯誤類型顯示不同訊息
        if (e.toString().contains('找不到該帳號的資料')) {
          errorMessage = '找不到該帳號的資料，可能是帳號不存在或是私密帳號';
        } else if (e.toString().contains('爬蟲腳本執行失敗')) {
          errorMessage = '無法取得資料，請稍後再試';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: '了解',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingMessage = '';
        });
      }
    }
  }

  Future<void> _deleteAccount(String username) async {
    try {
      final outputDir = path.join(Directory.current.path, 'python_scripts', 'output');
      final resultFile = File(path.join(outputDir, '${username}_result.json'));
      final rawDataFile = File(path.join(outputDir, '${username}_raw_data.json'));
      
      if (await resultFile.exists()) {
        await resultFile.delete();
      }
      if (await rawDataFile.exists()) {
        await rawDataFile.delete();
      }
      
      await _storageService.deleteAccount(username);
      await _loadSearchedAccounts();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已刪除 $username 的資料')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('刪除失敗: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('帳號搜尋')),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_loadingMessage),
                ],
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(
                            hintText: '輸入 Threads 帳號',
                            prefixText: '@',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () => _searchAccount(_controller.text.trim()),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _searchedAccounts.length,
                    itemBuilder: (context, index) {
                      final username = _searchedAccounts[index];
                      final searchTime = _storageService.getSearchTime(username);
                      return ListTile(
                        title: Text('@$username'),
                        subtitle: Text('更新時間：${_formatDateTime(searchTime)}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteAccount(username),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AccountCommentsPage(
                                username: username,
                                post: {},
                                selectedCommenter: null,
                              ),
                            ),
                          );
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