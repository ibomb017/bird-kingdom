package com.birdkingdom.controller;

import com.birdkingdom.dto.CreatePostRequest;
import com.birdkingdom.dto.ForumPostDTO;
import com.birdkingdom.dto.PostCommentDTO;
import com.birdkingdom.service.AuthService;
import com.birdkingdom.service.ForumService;
import org.springframework.data.domain.Page;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/forum")
public class ForumController {

    private final ForumService forumService;
    private final AuthService authService;

    public ForumController(ForumService forumService, AuthService authService) {
        this.forumService = forumService;
        this.authService = authService;
    }
    
    /**
     * 获取帖子列表
     */
    @GetMapping("/posts")
    public ResponseEntity<Page<ForumPostDTO>> getPosts(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestHeader(value = "Authorization", required = false) String authorization) {
        Long userId = extractUserId(authorization);
        return ResponseEntity.ok(forumService.getPosts(page, size, userId));
    }
    
    /**
     * 获取用户的帖子
     */
    @GetMapping("/posts/user/{userId}")
    public ResponseEntity<Page<ForumPostDTO>> getUserPosts(
            @PathVariable Long userId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestHeader(value = "Authorization", required = false) String authorization) {
        Long currentUserId = extractUserId(authorization);
        return ResponseEntity.ok(forumService.getUserPosts(userId, page, size, currentUserId));
    }
    
    /**
     * 获取帖子详情
     */
    @GetMapping("/posts/{postId}")
    public ResponseEntity<ForumPostDTO> getPostDetail(
            @PathVariable Long postId,
            @RequestHeader(value = "Authorization", required = false) String authorization) {
        Long userId = extractUserId(authorization);
        return ResponseEntity.ok(forumService.getPostDetail(postId, userId));
    }
    
    /**
     * 创建帖子
     */
    @PostMapping("/posts")
    public ResponseEntity<ForumPostDTO> createPost(
            @RequestHeader("Authorization") String authorization,
            @RequestBody CreatePostRequest request) {
        Long userId = extractUserId(authorization);
        if (userId == null) {
            return ResponseEntity.status(401).build();
        }
        return ResponseEntity.ok(forumService.createPost(userId, request));
    }
    
    /**
     * 删除帖子
     */
    @DeleteMapping("/posts/{postId}")
    public ResponseEntity<Void> deletePost(
            @PathVariable Long postId,
            @RequestHeader("Authorization") String authorization) {
        Long userId = extractUserId(authorization);
        if (userId == null) {
            return ResponseEntity.status(401).build();
        }
        forumService.deletePost(postId, userId);
        return ResponseEntity.noContent().build();
    }
    
    /**
     * 点赞/取消点赞
     */
    @PostMapping("/posts/{postId}/like")
    public ResponseEntity<Map<String, Boolean>> toggleLike(
            @PathVariable Long postId,
            @RequestHeader("Authorization") String authorization) {
        Long userId = extractUserId(authorization);
        if (userId == null) {
            return ResponseEntity.status(401).build();
        }
        boolean isLiked = forumService.toggleLike(postId, userId);
        return ResponseEntity.ok(Map.of("isLiked", isLiked));
    }
    
    /**
     * 收藏/取消收藏
     */
    @PostMapping("/posts/{postId}/favorite")
    public ResponseEntity<Map<String, Boolean>> toggleFavorite(
            @PathVariable Long postId,
            @RequestHeader("Authorization") String authorization) {
        Long userId = extractUserId(authorization);
        if (userId == null) {
            return ResponseEntity.status(401).build();
        }
        boolean isFavorited = forumService.toggleFavorite(postId, userId);
        return ResponseEntity.ok(Map.of("isFavorited", isFavorited));
    }
    
    /**
     * 获取用户收藏的帖子
     */
    @GetMapping("/favorites")
    public ResponseEntity<Page<ForumPostDTO>> getFavorites(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestHeader("Authorization") String authorization) {
        Long userId = extractUserId(authorization);
        if (userId == null) {
            return ResponseEntity.status(401).build();
        }
        return ResponseEntity.ok(forumService.getFavorites(userId, page, size));
    }
    
    /**
     * 添加评论
     */
    @PostMapping("/posts/{postId}/comments")
    public ResponseEntity<PostCommentDTO> addComment(
            @PathVariable Long postId,
            @RequestHeader("Authorization") String authorization,
            @RequestBody Map<String, Object> request) {
        Long userId = extractUserId(authorization);
        if (userId == null) {
            return ResponseEntity.status(401).build();
        }
        String content = (String) request.get("content");
        Long parentId = request.get("parentId") != null ? Long.valueOf(request.get("parentId").toString()) : null;
        return ResponseEntity.ok(forumService.addComment(postId, userId, content, parentId));
    }
    
    /**
     * 获取帖子评论
     */
    @GetMapping("/posts/{postId}/comments")
    public ResponseEntity<Page<PostCommentDTO>> getComments(
            @PathVariable Long postId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestHeader(value = "Authorization", required = false) String authorization) {
        Long userId = extractUserId(authorization);
        return ResponseEntity.ok(forumService.getComments(postId, page, size, userId));
    }
    
    /**
     * 评论点赞/取消点赞
     */
    @PostMapping("/comments/{commentId}/like")
    public ResponseEntity<Map<String, Boolean>> toggleCommentLike(
            @PathVariable Long commentId,
            @RequestHeader("Authorization") String authorization) {
        Long userId = extractUserId(authorization);
        if (userId == null) {
            return ResponseEntity.status(401).build();
        }
        boolean isLiked = forumService.toggleCommentLike(commentId, userId);
        return ResponseEntity.ok(Map.of("isLiked", isLiked));
    }
    
    /**
     * 从Authorization头提取用户ID
     */
    private Long extractUserId(String authorization) {
        if (authorization == null || !authorization.startsWith("Bearer ")) {
            return null;
        }
        String token = authorization.substring(7);
        return authService.validateToken(token);
    }
}
