import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/post.dart';

class ThreadsScraperService {
  Future<String> get _pythonPath async {
    if (Platform.isWindows) {
      return 'python';
    } else {
      return 'python3';
    }
  }

  Future<String> get _scriptPath async {
    // 直接使用專案目錄下的 python_scripts 資料夾
    return path.join(
      Directory.current.path,
      'python_scripts',
      'threads_scraper.py'
    );
  }

  Future<List<Post>> scrapeThreads(String username) async {
    try {
      final pythonPath = await _pythonPath;
      final scriptPath = await _scriptPath;
      
      // 確保輸出目錄存在
      final outputDir = Directory(path.join(Directory.current.path, 'output'));
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }
      
      // 執行 Python 腳本
      final process = await Process.run(
        pythonPath,
        [scriptPath, username],
        workingDirectory: path.dirname(scriptPath),
      );
      
      if (process.exitCode != 0) {
        print('Python 錯誤輸出: ${process.stderr}');
        throw Exception('爬蟲執行失敗: ${process.stderr}');
      }
      
      final file = File(path.join(outputDir.path, '${username}_result.json'));
      if (!await file.exists()) {
        throw Exception('找不到該帳號的資料，可能是帳號不存在或是私密帳號');
      }

      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString);
      
      if (data == null || !data.containsKey('posts')) {
        throw Exception('資料格式錯誤：缺少 posts 欄位');
      }

      return (data['posts'] as List).map((post) => Post.fromJson(post)).toList();
    } catch (e, stackTrace) {
      print('錯誤堆疊: $stackTrace');
      throw Exception('爬蟲過程發生錯誤: $e');
    }
  }
}