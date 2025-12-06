import 'package:flutter/material.dart';

class PostEditPage extends StatelessWidget {
  const PostEditPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: const Text('发布动态'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          children: [
            TextField(
              controller: controller,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: '分享今天和小鸟的故事、照片或问题...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // 预留：发送到后端
                  Navigator.of(context).pop();
                },
                child: const Text('发布'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
