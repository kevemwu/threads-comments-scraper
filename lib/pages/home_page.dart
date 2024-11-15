import 'package:flutter/material.dart';
import 'account_search_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Threads Viewer')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AccountSearchPage(),
                  ),
                );
              },
              child: const Text('帳號搜尋'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // 留言管理功能待實作
              },
              child: const Text('留言管理'),
            ),
          ],
        ),
      ),
    );
  }
}