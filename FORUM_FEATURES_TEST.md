# 广场功能完整测试清单

## ✅ 已修复的问题

### 1. **评论功能** 
- ❌ 之前：只在本地添加，不调用后端API
- ✅ 现在：调用 `ApiService.shared.addComment()` 保存到数据库

## 🧪 完整功能测试

### 一、评论功能测试

#### 前端流程：
```swift
1. 用户输入评论内容
2. 点击发送按钮
3. 调用 submitComment()
4. ApiService.shared.addComment(postId, content)
5. 后端保存评论
6. 返回 CommentDTO
7. 转换为 PostComment
8. 添加到评论列表
9. 清空输入框
```

#### 后端API：
```
POST /api/forum/posts/{postId}/comments
Headers: Authorization: Bearer {token}
Body: {
  "content": "评论内容",
  "parentId": null  // 可选，回复评论时使用
}

Response: PostCommentDTO {
  id, postId, authorId, authorName, authorAvatar,
  content, likeCount, isLiked, createdAt, timeAgo
}
```

#### 测试步骤：
```
1. 登录账号
2. 进入任意帖子详情
3. 输入评论："测试评论123"
4. 点击发送
5. 检查：
   ✓ 评论立即显示在列表顶部
   ✓ 显示"刚刚"时间
   ✓ 显示当前用户昵称
   ✓ 输入框清空
6. 刷新页面
7. 检查：
   ✓ 评论仍然存在
   ✓ 数据从数据库加载
```

---

### 二、点赞功能测试

#### 前端流程：
```swift
1. 用户点击点赞按钮
2. 调用 socialService.toggleLike(postId)
3. ApiService.shared.togglePostLike(postId)
4. 后端切换点赞状态
5. 返回 {liked: true/false}
6. 更新UI（心形图标、点赞数）
```

#### 后端API：
```
POST /api/forum/posts/{postId}/like
Headers: Authorization: Bearer {token}

Response: {
  "liked": true  // true=已点赞, false=已取消
}
```

#### 测试步骤：
```
1. 点击未点赞的帖子的点赞按钮
2. 检查：
   ✓ 心形图标变红色填充
   ✓ 点赞数+1
   ✓ 动画效果
3. 再次点击
4. 检查：
   ✓ 心形图标变空心灰色
   ✓ 点赞数-1
5. 刷新页面
6. 检查：
   ✓ 点赞状态保持
```

---

### 三、收藏功能测试

#### 前端流程：
```swift
1. 用户点击收藏按钮
2. 调用 socialService.toggleFavorite(postId)
3. ApiService.shared.togglePostFavorite(postId)
4. 后端切换收藏状态
5. 更新UI（书签图标、文字）
```

#### 后端API：
```
POST /api/forum/posts/{postId}/favorite
Headers: Authorization: Bearer {token}

Response: {
  "favorited": true  // true=已收藏, false=已取消
}
```

#### 测试步骤：
```
1. 点击收藏按钮
2. 检查：
   ✓ 书签图标变绿色填充
   ✓ 文字变为"已收藏"
3. 再次点击
4. 检查：
   ✓ 书签图标变空心灰色
   ✓ 文字变为"收藏"
5. 进入"我的"->"我的收藏"
6. 检查：
   ✓ 收藏的帖子显示在列表中
```

---

### 四、分享功能测试

#### 前端流程：
```swift
1. 用户点击分享按钮
2. 显示系统分享面板
3. 用户选择分享方式
4. 分享内容包括：
   - 帖子标题/内容
   - 图片（如果有）
   - 链接（如果有）
```

#### 测试步骤：
```
1. 点击分享按钮
2. 检查：
   ✓ 显示系统分享面板
   ✓ 可以选择微信、复制链接等
3. 选择"复制链接"
4. 检查：
   ✓ 链接已复制到剪贴板
```

---

### 五、评论点赞测试

#### 后端API：
```
POST /api/forum/comments/{commentId}/like
Headers: Authorization: Bearer {token}

Response: {
  "liked": true
}
```

#### 测试步骤：
```
1. 点击评论的点赞按钮
2. 检查：
   ✓ 点赞数+1
   ✓ 图标变化
3. 刷新页面
4. 检查：
   ✓ 评论点赞状态保持
```

---

### 六、帖子加载测试

#### 后端API：
```
GET /api/forum/posts?page=0&size=20&sort=latest
Headers: Authorization: Bearer {token}

Response: {
  content: [ForumPostDTO],
  totalElements: 100,
  totalPages: 5,
  number: 0
}
```

#### 测试步骤：
```
1. 打开广场页面
2. 检查：
   ✓ 显示最新帖子列表
   ✓ 每个帖子显示：
     - 作者头像、昵称
     - 发布时间
     - 内容
     - 图片（如果有）
     - 点赞数、评论数
3. 下拉刷新
4. 检查：
   ✓ 加载最新数据
5. 上拉加载更多
6. 检查：
   ✓ 加载下一页数据
```

---

### 七、寻鸟启事特殊功能

#### 测试步骤：
```
1. 发布寻鸟启事
2. 检查：
   ✓ 顶部红色标签显示"🔍 寻鸟启事"
   ✓ 右侧显示"悬赏 ¥XXX"
   ✓ 图片区域纯图片显示
3. 点击进入详情
4. 检查：
   ✓ 寻鸟信息卡片显示：
     - 鸟儿名字
     - 鸟儿品种
     - 走失地点
     - 联系电话
     - 悬赏金额
   ✓ "联系失主"按钮
5. 点击"联系失主"
6. 检查：
   ✓ 自动弹出拨号界面
   ✓ 电话号码正确
```

---

## 🔧 需要检查的代码位置

### 前端：
1. **评论提交**：`BirdKingdomApp.swift` - `submitComment()`
2. **点赞功能**：`SocialService.swift` - `toggleLike()`
3. **收藏功能**：`SocialService.swift` - `toggleFavorite()`
4. **API调用**：`ApiService.swift` - `addComment()`, `togglePostLike()`, `togglePostFavorite()`

### 后端：
1. **评论API**：`ForumController.java` - `addComment()`
2. **点赞API**：`ForumController.java` - `toggleLike()`
3. **收藏API**：`ForumController.java` - `toggleFavorite()`
4. **服务层**：`ForumService.java` - 所有业务逻辑

---

## 📝 数据库表

### 1. forum_posts（帖子表）
```sql
- id
- author_id
- content
- post_type (NORMAL, FIND_BIRD)
- bird_name
- bird_species
- lost_location
- contact_phone
- reward
- is_found
- like_count
- comment_count
- created_at
```

### 2. comments（评论表）
```sql
- id
- post_id
- author_id
- content
- parent_id (回复评论)
- like_count
- created_at
```

### 3. post_likes（帖子点赞表）
```sql
- id
- post_id
- user_id
- created_at
```

### 4. comment_likes（评论点赞表）
```sql
- id
- comment_id
- user_id
- created_at
```

### 5. post_favorites（帖子收藏表）
```sql
- id
- post_id
- user_id
- created_at
```

---

## ✅ 功能对比：小红书 vs 鸟之王国

| 功能 | 小红书 | 鸟之王国 | 状态 |
|------|--------|----------|------|
| 发帖 | ✓ | ✓ | ✅ |
| 多图上传 | ✓ | ✓ | ✅ |
| 点赞 | ✓ | ✓ | ✅ |
| 评论 | ✓ | ✓ | ✅ |
| 回复评论 | ✓ | ✓ | ✅ |
| 收藏 | ✓ | ✓ | ✅ |
| 分享 | ✓ | ✓ | ✅ |
| 关注用户 | ✓ | ✓ | ✅ |
| 查看关注动态 | ✓ | ✓ | ✅ |
| 附近的帖子 | ✓ | ✓ | ✅ |
| 热门推荐 | ✓ | ✓ | ✅ |
| 寻鸟启事 | ✗ | ✓ | ✅ 特色功能 |

---

## 🚀 下一步优化建议

1. **实时通知**
   - 有人点赞/评论时推送通知
   - 使用WebSocket或推送服务

2. **图片优化**
   - 图片压缩
   - 缩略图生成
   - CDN加速

3. **性能优化**
   - 评论分页加载
   - 图片懒加载
   - 缓存策略

4. **用户体验**
   - 下拉刷新动画
   - 加载骨架屏
   - 错误提示优化

所有核心功能已完整实现！✅
