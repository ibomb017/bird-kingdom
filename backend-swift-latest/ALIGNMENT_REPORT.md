# Swift 后端与数据库、前端 API 对齐报告
## 生成时间: 2025-12-28 02:57

---

## 一、数据库表与 Swift 模型对照

| # | 数据库表 | Swift 模型 | 位置 | 状态 |
|---|----------|-----------|------|------|
| 1 | `users` | `User` | `Models/User.swift` | ✅ |
| 2 | `birds` | `Bird` | `Models/Bird.swift` | ✅ |
| 3 | `forum_posts` | `ForumPost` | `Models/ForumPost.swift` | ✅ |
| 4 | `post_comments` | `PostComment` | `Models/PostComment.swift` | ✅ |
| 5 | `post_likes` | `PostLike` | `Models/PostInteractions.swift` | ✅ |
| 6 | `post_favorites` | `PostFavorite` | `Models/PostInteractions.swift` | ✅ |
| 7 | `post_images` | `PostImage` | `Models/PostImage.swift` | ✅ |
| 8 | `post_reports` | `PostReport` | `Models/PostInteractions.swift` | ✅ |
| 9 | `comment_likes` | `CommentLike` | `Models/PostInteractions.swift` | ✅ |
| 10 | `user_follows` | `UserFollow` | `Models/UserRelations.swift` | ✅ |
| 11 | `user_blocks` | `UserBlock` | `Models/UserRelations.swift` | ✅ |
| 12 | `user_notification` | `UserNotification` | `Controllers/NotificationController.swift` | ✅ |
| 13 | `verification_codes` | `VerificationCode` | `Models/UserRelations.swift` | ✅ |
| 14 | `bird_logs` | `BirdLog` | `Controllers/BirdLogController.swift` | ✅ |
| 15 | `bird_log_images` | `BirdLogImage` | `Controllers/BirdLogController.swift` | ✅ |
| 16 | `expenses` | `Expense` | `Controllers/ExpenseController.swift` | ✅ |
| 17 | `reminders` | `Reminder` | `Controllers/ReminderController.swift` | ✅ |
| 18 | `bird_cycle_record` | `BirdCycleRecord` | `Controllers/BirdCycleController.swift` | ✅ |
| 19 | `bird_encyclopedia` | `BirdEncyclopedia` | `Controllers/EncyclopediaController.swift` | ✅ |
| 20 | `bird_foods` | `BirdFood` | `Controllers/EncyclopediaController.swift` | ✅ |
| 21 | `symptoms` | `Symptom` | `Controllers/EncyclopediaController.swift` | ✅ |
| 22 | `parrot_species` | `ParrotSpecies` | `Controllers/ParrotSpeciesController.swift` | ✅ |
| 23 | `splash_order` | `SplashOrder` | `Controllers/SplashController.swift` | ✅ |
| 24 | `splash_display_slot` | `SplashDisplaySlot` | `Controllers/SplashController.swift` | ✅ |
| 25 | `splash_quota_daily` | `SplashQuotaDaily` | `Controllers/SplashController.swift` | ✅ |
| 26 | `apple_purchase_records` | `ApplePurchaseRecord` | `Controllers/AppleNotificationController.swift` | ✅ |
| 27 | `bird_shares` | `BirdShare` | `Models/AdditionalModels.swift` | ✅ |
| 28 | `color_genes` | `ColorGene` | `Models/AdditionalModels.swift` | ✅ |
| 29 | `idempotency_keys` | `IdempotencyKey` | `Models/AdditionalModels.swift` | ✅ |
| 30 | `admin_users` | - | Admin Web 专用，不需要在 App 后端 | ➖ 跳过 |
| 31 | `forum_comments` | - | 旧表，数据行数为 0，已被 post_comments 替代 | ➖ 跳过 |

---

## 二、前端 API 与后端路由对照

### Auth 相关 (/api/auth/*)
| 前端 API | 后端路由 | Controller | 状态 |
|----------|---------|------------|------|
| `auth/login` | POST `/api/auth/login` | AuthController | ✅ |
| `auth/login-password` | POST `/api/auth/login-password` | AuthController | ✅ |
| `auth/register` | POST `/api/auth/register` | AuthController | ✅ |
| `auth/send-code` | POST `/api/auth/send-code` | AuthController | ✅ |
| `auth/send-login-code` | POST `/api/auth/send-login-code` | AuthController | ✅ |
| `auth/send-register-code` | POST `/api/auth/send-register-code` | AuthController | ✅ |
| `auth/verify-code` | POST `/api/auth/verify-code` | AuthController | ✅ |
| `auth/set-password` | POST `/api/auth/set-password` | AuthController | ✅ |
| `auth/reset-password` | POST `/api/auth/reset-password` | AuthController | ✅ |
| `auth/change-password` | POST `/api/auth/change-password` | AuthController | ✅ |
| `auth/change-phone` | POST `/api/auth/change-phone` | AuthController | ✅ |
| `auth/change-phone/verify-old` | POST `/api/auth/change-phone/verify-old` | AuthController | ✅ |
| `auth/change-phone/send-code` | POST `/api/auth/change-phone/send-code` | AuthController | ✅ |
| `auth/me` | GET `/api/auth/me` | AuthController | ✅ |
| `auth/profile` | PUT `/api/auth/profile` | AuthController | ✅ |
| `auth/validate` | GET `/api/auth/validate` | AuthController | ✅ |
| `auth/check-user` | GET `/api/auth/check-user` | AuthController | ✅ |
| `auth/delete-account` | DELETE `/api/auth/delete-account` | AuthController | ✅ |
| `auth/couple/invitation` | POST `/api/auth/couple/invitation` | AuthController | ✅ |
| `auth/couple/invitation/accept` | POST `/api/auth/couple/invitation/accept` | AuthController | ✅ |
| `auth/couple/invitation/reject` | POST `/api/auth/couple/invitation/reject` | AuthController | ✅ |
| `auth/couple/bind` | POST `/api/auth/couple/bind` | AuthController | ✅ |
| `auth/couple/unbind` | POST `/api/auth/couple/unbind` | AuthController | ✅ |
| `auth/vip/purchase` | POST `/api/auth/vip/purchase` | AuthController | ✅ |
| `auth/vip/restore` | POST `/api/auth/vip/restore` | AuthController | ✅ |

### Birds 相关 (/api/birds/*)
| 前端 API | 后端路由 | Controller | 状态 |
|----------|---------|------------|------|
| `birds` | GET/POST `/api/birds` | BirdController | ✅ |
| `birds/{id}` | GET/PUT/DELETE `/api/birds/:id` | BirdController | ✅ |
| `birds/active` | GET `/api/birds/active` | BirdController | ✅ |
| `birds/deleted` | GET `/api/birds/deleted` | BirdController | ✅ |
| `birds/{id}/restore` | POST `/api/birds/:id/restore` | BirdController | ✅ |
| `birds/{id}/permanent` | DELETE `/api/birds/:id/permanent` | BirdController | ✅ |
| `birds/{id}/lost-status` | PUT `/api/birds/:id/lost-status` | BirdController | ✅ |
| `birds/{id}/share` | POST `/api/birds/:id/share` | BirdController | ✅ |
| `birds/{id}/shared-users` | GET `/api/birds/:id/shared-users` | BirdController | ✅ |
| `birds/{id}/leave` | POST `/api/birds/:id/leave` | BirdController | ✅ |
| `birds/{id}/logs` | GET `/api/birds/:id/logs` | BirdLogController | ✅ |
| `birds/{id}/cycles` | GET `/api/birds/:id/cycles` | BirdCycleController | ✅ |
| `birds/{id}/cycles/active` | GET `/api/birds/:id/cycles/active` | BirdCycleController | ✅ |
| `birds/{id}/weights` | GET `/api/birds/:id/weights` | BirdController | ✅ |

### Logs 相关 (/api/logs/*)
| 前端 API | 后端路由 | Controller | 状态 |
|----------|---------|------------|------|
| `logs` | GET/POST `/api/logs` | BirdLogController | ✅ |
| `logs/{id}` | GET/PUT/DELETE `/api/logs/:id` | BirdLogController | ✅ |
| `logs/bird/{id}` | GET `/api/logs/bird/:birdId` | BirdLogController | ✅ |
| `logs/weight-trend` | GET `/api/logs/weight-trend` | BirdLogController | ✅ |

### Cycles 相关 (/api/cycles/*)
| 前端 API | 后端路由 | Controller | 状态 |
|----------|---------|------------|------|
| `cycles/{id}` | PUT/DELETE `/api/cycles/:cycleId` | BirdCycleController | ✅ |

### Expenses 相关 (/api/expenses/*)
| 前端 API | 后端路由 | Controller | 状态 |
|----------|---------|------------|------|
| `expenses` | GET/POST `/api/expenses` | ExpenseController | ✅ |
| `expenses/{id}` | GET/PUT/DELETE `/api/expenses/:id` | ExpenseController | ✅ |
| `expenses/stats` | GET `/api/expenses/stats` | ExpenseController | ✅ |

### Reminders 相关 (/api/reminders/*)
| 前端 API | 后端路由 | Controller | 状态 |
|----------|---------|------------|------|
| `reminders` | GET/POST `/api/reminders` | ReminderController | ✅ |
| `reminders/{id}` | GET/PUT/DELETE `/api/reminders/:id` | ReminderController | ✅ |
| `reminders/{id}/toggle` | POST `/api/reminders/:id/toggle` | ReminderController | ✅ |

### Forum 相关 (/api/forum/*)
| 前端 API | 后端路由 | Controller | 状态 |
|----------|---------|------------|------|
| `forum/posts` | GET/POST `/api/forum/posts` | ForumController | ✅ |
| `forum/posts/{id}` | GET/DELETE `/api/forum/posts/:postId` | ForumController | ✅ |
| `forum/posts/search` | GET `/api/forum/posts/search` | ForumController | ✅ |
| `forum/posts/following` | GET `/api/forum/posts/following` | ForumController | ✅ |
| `forum/posts/mine` | GET `/api/forum/posts/mine` | ForumController | ✅ |
| `forum/posts/user/{userId}` | GET `/api/forum/posts/user/:userId` | ForumController | ✅ |
| `forum/posts/check-duplicate` | GET `/api/forum/posts/check-duplicate` | ForumController | ✅ |
| `forum/posts/{id}/like` | POST `/api/forum/posts/:postId/like` | ForumController | ✅ |
| `forum/posts/{id}/favorite` | POST `/api/forum/posts/:postId/favorite` | ForumController | ✅ |
| `forum/posts/{id}/comments` | GET/POST `/api/forum/posts/:postId/comments` | ForumController | ✅ |
| `forum/posts/{id}/report` | POST `/api/forum/posts/:postId/report` | ForumController | ✅ |
| `forum/posts/{id}/mark-found` | POST `/api/forum/posts/:postId/mark-found` | ForumController | ✅ |
| `forum/comments/{id}` | DELETE `/api/forum/comments/:commentId` | ForumController | ✅ |
| `forum/comments/{id}/like` | POST `/api/forum/comments/:commentId/like` | ForumController | ✅ |
| `forum/favorites` | GET `/api/forum/favorites` | ForumController | ✅ |

### Notifications 相关 (/api/notifications/*)
| 前端 API | 后端路由 | Controller | 状态 |
|----------|---------|------------|------|
| `notifications` | GET `/api/notifications` | NotificationController | ✅ |
| `notifications/unread-count` | GET `/api/notifications/unread-count` | NotificationController | ✅ |
| `notifications/mark-all-read` | POST `/api/notifications/mark-all-read` | NotificationController | ✅ |
| `notifications/{id}/read` | POST `/api/notifications/:id/read` | NotificationController | ✅ |

### Encyclopedia 相关 (/api/encyclopedia/*)
| 前端 API | 后端路由 | Controller | 状态 |
|----------|---------|------------|------|
| `encyclopedia/birds` | GET `/api/encyclopedia/birds` | EncyclopediaController | ✅ |
| `encyclopedia/birds/{id}` | GET `/api/encyclopedia/birds/:birdId` | EncyclopediaController | ✅ |
| `encyclopedia/birds/search` | GET `/api/encyclopedia/birds/search` | EncyclopediaController | ✅ |
| `encyclopedia/birds/categories` | GET `/api/encyclopedia/birds/categories` | EncyclopediaController | ✅ |
| `encyclopedia/birds/category/{cat}` | GET `/api/encyclopedia/birds/category/:category` | EncyclopediaController | ✅ |
| `encyclopedia/foods` | GET `/api/encyclopedia/foods` | EncyclopediaController | ✅ |
| `encyclopedia/foods/{id}` | GET `/api/encyclopedia/foods/:foodId` | EncyclopediaController | ✅ |
| `encyclopedia/foods/search` | GET `/api/encyclopedia/foods/search` | EncyclopediaController | ✅ |
| `encyclopedia/foods/categories` | GET `/api/encyclopedia/foods/categories` | EncyclopediaController | ✅ |
| `encyclopedia/foods/category/{cat}` | GET `/api/encyclopedia/foods/category/:category` | EncyclopediaController | ✅ |
| `encyclopedia/foods/safety/{level}` | GET `/api/encyclopedia/foods/safety/:safetyLevel` | EncyclopediaController | ✅ |
| `encyclopedia/symptoms` | GET `/api/encyclopedia/symptoms` | EncyclopediaController | ✅ |
| `encyclopedia/symptoms/{id}` | GET `/api/encyclopedia/symptoms/:symptomId` | EncyclopediaController | ✅ |
| `encyclopedia/symptoms/search` | GET `/api/encyclopedia/symptoms/search` | EncyclopediaController | ✅ |
| `encyclopedia/symptoms/severity/{sev}` | GET `/api/encyclopedia/symptoms/severity/:severity` | EncyclopediaController | ✅ |

### Species 相关 (/api/species/*)
| 前端 API | 后端路由 | Controller | 状态 |
|----------|---------|------------|------|
| `species` | GET `/api/species` | ParrotSpeciesController | ✅ |
| `species/by-name` | GET `/api/species/by-name` | ParrotSpeciesController | ✅ |

### Upload 相关 (/api/upload/*)
| 前端 API | 后端路由 | Controller | 状态 |
|----------|---------|------------|------|
| `upload/bird-avatar` | POST `/api/upload/bird-avatar` | UploadController | ✅ |
| `upload/post-image` | POST `/api/upload/post-image` | UploadController | ✅ |
| `upload/post-video` | POST `/api/upload/post-video` | UploadController | ✅ |

### Other 相关
| 前端 API | 后端路由 | Controller | 状态 |
|----------|---------|------------|------|
| `ai/chat` | POST `/api/ai/chat` | AIProxyController | ✅ |
| `feedback` | POST `/api/feedback` | FeedbackController | ✅ |
| `share/invitations/pending` | GET `/api/share/invitations/pending` | InvitationController | ✅ |
| `share/invitations/{id}/accept` | POST `/api/share/invitations/:id/accept` | InvitationController | ✅ |
| `share/invitations/{id}/reject` | POST `/api/share/invitations/:id/reject` | InvitationController | ✅ |

---

## 三、修复摘要

### 已修复的模型字段问题：
1. **User** - 添加 `is_disabled`，所有可选字段改为 `@OptionalField`
2. **Bird** - 所有可选字段改为 `@OptionalField`
3. **ForumPost** - 所有可选字段改为 `@OptionalField`
4. **PostComment** - 添加 `user_id`, `reply_to_user_id` 字段
5. **PostImage** - `sortOrder` 改为可选
6. **PostInteractions** - 添加 `CommentLike` 模型
7. **UserNotification** - 完全重构匹配数据库
8. **BirdLog** - `notes` 及其他字段改为可选
9. **Expense** - `description` → `note`，添加 `title`, `bird_name`
10. **Reminder** - 添加 `bird_id` 字段
11. **BirdCycleRecord** - 所有可选字段改为 `@OptionalField`
12. **ParrotSpecies** - 添加所有 molting/incubation/estrus 字段
13. **BirdFood** - `name` → `food_name`，添加完整字段
14. **BirdEncyclopedia** - 添加完整字段
15. **Symptom** - 添加完整字段
16. **SplashOrder** - 添加 `slot_id`, `expire_at`, `paid_at`
17. **SplashQuotaDaily** - 完全重构匹配数据库
18. **SplashDisplaySlot** - 添加所有审核字段

### 新增的模型：
1. **BirdLogImage** - 日志图片
2. **CommentLike** - 评论点赞
3. **ApplePurchaseRecord** - 苹果订阅记录
4. **BirdShare** - 鸟儿分享
5. **ColorGene** - 颜色基因
6. **IdempotencyKey** - 幂等键

### 新增的 API 路由：
1. `GET /api/forum/posts/following`
2. `GET /api/forum/posts/mine`
3. `GET /api/forum/posts/user/:userId`
4. `GET /api/forum/posts/check-duplicate`

---

## 四、编译状态

✅ **本地编译通过** (swift build 成功)

---

## 五、准备部署

所有模型已对齐，所有 API 已实现，可以进行部署。
