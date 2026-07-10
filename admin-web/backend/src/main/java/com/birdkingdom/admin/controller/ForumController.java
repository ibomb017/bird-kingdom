package com.birdkingdom.admin.controller;

import com.birdkingdom.admin.entity.ForumPost;
import com.birdkingdom.admin.entity.PostComment;
import com.birdkingdom.admin.entity.PostReport;
import com.birdkingdom.admin.entity.PostImage;
import com.birdkingdom.admin.entity.User;
import com.birdkingdom.admin.entity.UserNotification;
import com.birdkingdom.admin.repository.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.*;

/**
 * 论坛管理控制器 - 完整CRUD实现
 */
@RestController
@RequestMapping({ "/api/forum", "/api/admin/forum" })
public class ForumController {

    @Autowired
    private ForumPostRepository forumPostRepository;

    @Autowired
    private PostCommentRepository postCommentRepository;

    @Autowired
    private PostReportRepository postReportRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private UserNotificationRepository userNotificationRepository;

    @Autowired
    private PostImageRepository postImageRepository;

    /**
     * 获取帖子列表
     */
    @GetMapping("/posts")
    public ResponseEntity<Map<String, Object>> getPosts(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) String postType,
            @RequestParam(required = false) String keyword) {
        PageRequest pageRequest = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "createdAt"));
        Page<ForumPost> postPage;

        if (keyword != null && !keyword.isEmpty()) {
            postPage = forumPostRepository.searchByKeyword(keyword, pageRequest);
        } else if (postType != null && !postType.isEmpty()) {
            postPage = forumPostRepository.findByPostType(postType, pageRequest);
        } else {
            postPage = forumPostRepository.findAll(pageRequest);
        }

        List<Map<String, Object>> posts = new ArrayList<>();
        for (ForumPost post : postPage.getContent()) {
            Map<String, Object> postMap = new HashMap<>();
            postMap.put("id", post.getId());
            postMap.put("content", truncateContent(post.getContent(), 100));
            postMap.put("postType", post.getPostType());
            postMap.put("mediaType", post.getMediaType());
            postMap.put("likeCount", post.getLikeCount());
            postMap.put("commentCount", post.getCommentCount());
            postMap.put("viewCount", post.getViewCount());
            postMap.put("authorId", post.getAuthorId());
            postMap.put("createdAt", post.getCreatedAt());

            // 获取作者信息
            if (post.getAuthorId() != null) {
                userRepository.findById(post.getAuthorId()).ifPresent(author -> {
                    postMap.put("authorNickname", author.getNickname());
                    postMap.put("authorAvatarUrl", author.getAvatarUrl());
                });
            }

            posts.add(postMap);
        }

        Map<String, Object> result = new HashMap<>();
        result.put("content", posts);
        result.put("totalElements", postPage.getTotalElements());
        result.put("totalPages", postPage.getTotalPages());

        return ResponseEntity.ok(Map.of(
                "code", 0,
                "message", "success",
                "data", result));
    }

    /**
     * 获取帖子详情
     */
    @GetMapping("/posts/{id}")
    public ResponseEntity<Map<String, Object>> getPostDetail(@PathVariable Long id) {
        Optional<ForumPost> postOpt = forumPostRepository.findById(id);
        if (postOpt.isEmpty()) {
            return ResponseEntity.ok(Map.of("code", 1, "message", "帖子不存在"));
        }

        ForumPost post = postOpt.get();
        Map<String, Object> detail = new HashMap<>();
        detail.put("id", post.getId());
        detail.put("content", post.getContent());
        detail.put("postType", post.getPostType());
        detail.put("mediaType", post.getMediaType());
        
        List<String> mediaUrls = postImageRepository.findByPostIdOrderBySortOrderAsc(post.getId())
                .stream()
                .map(PostImage::getImageUrl)
                .toList();
        detail.put("mediaUrls", mediaUrls);
        
        detail.put("videoUrl", post.getVideoUrl());
        detail.put("likeCount", post.getLikeCount());
        detail.put("commentCount", post.getCommentCount());
        detail.put("favoriteCount", post.getFavoriteCount());
        detail.put("viewCount", post.getViewCount());
        detail.put("locationName", post.getLocationName());
        detail.put("birdName", post.getBirdName());
        detail.put("birdSpecies", post.getBirdSpecies());
        detail.put("lostLocation", post.getLostLocation());
        detail.put("isFound", post.getIsFound());
        detail.put("authorId", post.getAuthorId());
        detail.put("createdAt", post.getCreatedAt());

        // 获取作者信息
        if (post.getAuthorId() != null) {
            userRepository.findById(post.getAuthorId()).ifPresent(author -> {
                detail.put("authorNickname", author.getNickname());
                detail.put("authorAvatarUrl", author.getAvatarUrl());
            });
        }

        return ResponseEntity.ok(Map.of(
                "code", 0,
                "message", "success",
                "data", detail));
    }

    /**
     * 获取评论列表
     */
    @GetMapping("/comments")
    public ResponseEntity<Map<String, Object>> getComments(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) Long postId) {
        PageRequest pageRequest = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "createdAt"));
        Page<PostComment> commentPage;

        if (postId != null) {
            commentPage = postCommentRepository.findByPostId(postId, pageRequest);
        } else {
            commentPage = postCommentRepository.findAll(pageRequest);
        }

        List<Map<String, Object>> comments = new ArrayList<>();
        for (PostComment comment : commentPage.getContent()) {
            Map<String, Object> commentMap = new HashMap<>();
            commentMap.put("id", comment.getId());
            commentMap.put("postId", comment.getPostId());
            commentMap.put("content", comment.getContent());
            commentMap.put("likeCount", comment.getLikeCount());
            commentMap.put("userId", comment.getUserId());
            commentMap.put("createdAt", comment.getCreatedAt());

            // 获取用户信息
            if (comment.getUserId() != null) {
                userRepository.findById(comment.getUserId()).ifPresent(user -> {
                    commentMap.put("userNickname", user.getNickname());
                    commentMap.put("userAvatarUrl", user.getAvatarUrl());
                });
            }

            comments.add(commentMap);
        }

        Map<String, Object> result = new HashMap<>();
        result.put("content", comments);
        result.put("totalElements", commentPage.getTotalElements());
        result.put("totalPages", commentPage.getTotalPages());

        return ResponseEntity.ok(Map.of(
                "code", 0,
                "message", "success",
                "data", result));
    }

    /**
     * 获取举报列表
     */
    @GetMapping("/reports")
    public ResponseEntity<Map<String, Object>> getReports(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) String status) {
        PageRequest pageRequest = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "createdAt"));
        Page<PostReport> reportPage;

        if (status != null && !status.isEmpty()) {
            reportPage = postReportRepository.findByStatus(status, pageRequest);
        } else {
            reportPage = postReportRepository.findAll(pageRequest);
        }

        List<Map<String, Object>> reports = new ArrayList<>();
        for (PostReport report : reportPage.getContent()) {
            Map<String, Object> reportMap = new HashMap<>();
            reportMap.put("id", report.getId());
            reportMap.put("postId", report.getPostId());
            reportMap.put("reason", report.getReason());
            reportMap.put("description", report.getDescription());
            reportMap.put("status", report.getStatus());
            reportMap.put("reporterId", report.getReporterId());
            reportMap.put("createdAt", report.getCreatedAt());

            // 获取帖子信息
            forumPostRepository.findById(report.getPostId()).ifPresent(post -> {
                reportMap.put("postContent", truncateContent(post.getContent(), 50));
            });

            // 获取举报人信息
            if (report.getReporterId() != null) {
                userRepository.findById(report.getReporterId()).ifPresent(user -> {
                    reportMap.put("reporterNickname", user.getNickname());
                });
            }

            reports.add(reportMap);
        }

        Map<String, Object> result = new HashMap<>();
        result.put("content", reports);
        result.put("totalElements", reportPage.getTotalElements());
        result.put("totalPages", reportPage.getTotalPages());

        return ResponseEntity.ok(Map.of(
                "code", 0,
                "message", "success",
                "data", result));
    }

    /**
     * 处理举报
     */
    @PostMapping("/reports/{id}/handle")
    public ResponseEntity<Map<String, Object>> handleReport(
            @PathVariable Long id,
            @RequestBody Map<String, String> request) {
        Optional<PostReport> reportOpt = postReportRepository.findById(id);
        if (reportOpt.isEmpty()) {
            return ResponseEntity.ok(Map.of("code", 1, "message", "举报不存在"));
        }

        PostReport report = reportOpt.get();
        String action = request.get("action"); // approve, reject, delete_post, ban_user
        String handlerNote = request.get("handlerNote"); // 处理说明

        // 更新举报状态
        report.setStatus("REVIEWED");
        report.setReviewNote(handlerNote);
        report.setReviewedAt(LocalDateTime.now());

        // 执行相应操作
        boolean postDeleted = false;
        if ("approve".equals(action) || "delete_post".equals(action) || "ban_user".equals(action)) {
            report.setStatus("APPROVED");

            // ban_user: 必须在删帖之前查找作者ID
            if ("ban_user".equals(action)) {
                forumPostRepository.findById(report.getPostId()).ifPresent(post -> {
                    userRepository.findById(post.getAuthorId()).ifPresent(user -> {
                        user.setIsDisabled(true);
                        userRepository.save(user);
                    });
                });
            }
            
            if ("delete_post".equals(action) || "ban_user".equals(action) || "true".equals(request.get("deletePost"))) {
                // 删除帖子前先删除评论，防止外键约束报错
                postCommentRepository.deleteByPostId(report.getPostId());
                forumPostRepository.deleteById(report.getPostId());
                postDeleted = true;
            }
        } else if ("reject".equals(action)) {
            report.setStatus("REJECTED");
        }

        report.setHandledAt(LocalDateTime.now());
        postReportRepository.save(report);

        // 发送处理结果通知给举报人
        sendReportHandledNotification(report.getReporterId(), action, handlerNote, postDeleted);

        return ResponseEntity.ok(Map.of(
                "code", 0,
                "message", "举报已处理"));
    }

    /**
     * 发送举报处理结果通知
     */
    private void sendReportHandledNotification(Long reporterId, String action, String note, boolean postDeleted) {
        try {
            UserNotification notification = new UserNotification();
            notification.setUserId(reporterId);
            notification.setNotificationType("REPORT_HANDLED");
            notification.setTitle("举报处理通知");

            // 构建通知内容
            String content = buildNotificationContent(action, note, postDeleted);
            notification.setContent(content);
            notification.setIsRead(false);
            notification.setRelatedType("REPORT");

            userNotificationRepository.save(notification);
        } catch (Exception e) {
            // 通知发送失败不影响主流程，仅记录日志
            System.err.println("发送举报处理通知失败: " + e.getMessage());
        }
    }

    /**
     * 构建通知内容
     */
    private String buildNotificationContent(String action, String note, boolean postDeleted) {
        String result;

        if (postDeleted) {
            result = "您举报的内容已被删除";
        } else {
            switch (action != null ? action : "") {
                case "approve":
                    result = "您的举报已被采纳";
                    break;
                case "ban_user":
                    result = "违规用户已被封禁";
                    break;
                case "reject":
                    result = "您的举报未被采纳";
                    break;
                default:
                    result = "您的举报已处理";
                    break;
            }
        }

        if (note != null && !note.trim().isEmpty()) {
            result += "。\n处理说明：" + note;
        }

        return result;
    }

    /**
     * 删除帖子 - 真正实现删除功能
     */
    @DeleteMapping("/posts/{id}")
    public ResponseEntity<Map<String, Object>> deletePost(@PathVariable Long id) {
        try {
            Optional<ForumPost> postOpt = forumPostRepository.findById(id);
            if (postOpt.isEmpty()) {
                return ResponseEntity.ok(Map.of("code", 1, "message", "帖子不存在"));
            }

            // 删除帖子关联的评论
            postCommentRepository.deleteByPostId(id);

            // 删除帖子
            forumPostRepository.deleteById(id);

            return ResponseEntity.ok(Map.of(
                    "code", 0,
                    "message", "帖子删除成功"));
        } catch (Exception e) {
            return ResponseEntity.ok(Map.of(
                    "code", 1,
                    "message", "删除失败: " + e.getMessage()));
        }
    }

    /**
     * 删除评论 - 真正实现删除功能
     */
    @DeleteMapping("/comments/{id}")
    public ResponseEntity<Map<String, Object>> deleteComment(@PathVariable Long id) {
        try {
            Optional<PostComment> commentOpt = postCommentRepository.findById(id);
            if (commentOpt.isEmpty()) {
                return ResponseEntity.ok(Map.of("code", 1, "message", "评论不存在"));
            }

            PostComment comment = commentOpt.get();
            Long postId = comment.getPostId();

            // 删除评论
            postCommentRepository.deleteById(id);

            // 更新帖子的评论数
            forumPostRepository.findById(postId).ifPresent(post -> {
                int newCount = Math.max(0, (post.getCommentCount() != null ? post.getCommentCount() : 0) - 1);
                post.setCommentCount(newCount);
                forumPostRepository.save(post);
            });

            return ResponseEntity.ok(Map.of(
                    "code", 0,
                    "message", "评论删除成功"));
        } catch (Exception e) {
            return ResponseEntity.ok(Map.of(
                    "code", 1,
                    "message", "删除失败: " + e.getMessage()));
        }
    }

    /**
     * 解析媒体URL (逗号分隔的字符串转列表)
     */
    private List<String> parseMediaUrls(String mediaUrls) {
        if (mediaUrls == null || mediaUrls.isEmpty()) {
            return new ArrayList<>();
        }
        return Arrays.asList(mediaUrls.split(","));
    }

    private String truncateContent(String content, int maxLength) {
        if (content == null)
            return "";
        if (content.length() <= maxLength)
            return content;
        return content.substring(0, maxLength) + "...";
    }
}
