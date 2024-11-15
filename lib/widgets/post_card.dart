import 'package:flutter/material.dart';
import '../models/post.dart';

class PostCard extends StatelessWidget {
  final Post post;

  const PostCard({
    super.key,
    required this.post,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.datetime,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (post.content?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Text(post.content ?? ''),
                ],
              ],
            ),
          ),
          if (post.images.isNotEmpty)
            Container(
              height: 200,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: post.images.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Image.network(
                      post.images[index],
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  );
                },
              ),
            ),
          if (post.directRepliesCount > 0)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                '回覆數: ${post.directRepliesCount}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
