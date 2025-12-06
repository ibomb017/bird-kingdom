package com.birdkingdom.controller;

import com.birdkingdom.dto.UserDTO;
import com.birdkingdom.service.AuthService;
import com.birdkingdom.service.UserFollowService;
import org.springframework.data.domain.Page;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/users")
public class UserFollowController {

    private final UserFollowService followService;
    private final AuthService authService;

    public UserFollowController(UserFollowService followService, AuthService authService) {
        this.followService = followService;
        this.authService = authService;
    }
    
    /**
     * 关注/取消关注用户
     */
    @PostMapping("/{userId}/follow")
    public ResponseEntity<Map<String, Boolean>> toggleFollow(
            @PathVariable Long userId,
            @RequestHeader("Authorization") String authorization) {
        Long currentUserId = extractUserId(authorization);
        if (currentUserId == null) {
            return ResponseEntity.status(401).build();
        }
        boolean isFollowing = followService.toggleFollow(currentUserId, userId);
        return ResponseEntity.ok(Map.of("isFollowing", isFollowing));
    }
    
    /**
     * 检查是否关注
     */
    @GetMapping("/{userId}/is-following")
    public ResponseEntity<Map<String, Boolean>> isFollowing(
            @PathVariable Long userId,
            @RequestHeader("Authorization") String authorization) {
        Long currentUserId = extractUserId(authorization);
        if (currentUserId == null) {
            return ResponseEntity.status(401).build();
        }
        boolean isFollowing = followService.isFollowing(currentUserId, userId);
        return ResponseEntity.ok(Map.of("isFollowing", isFollowing));
    }
    
    /**
     * 获取用户的关注列表
     */
    @GetMapping("/{userId}/following")
    public ResponseEntity<Page<UserDTO>> getFollowing(
            @PathVariable Long userId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ResponseEntity.ok(followService.getFollowing(userId, page, size));
    }
    
    /**
     * 获取用户的粉丝列表
     */
    @GetMapping("/{userId}/followers")
    public ResponseEntity<Page<UserDTO>> getFollowers(
            @PathVariable Long userId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ResponseEntity.ok(followService.getFollowers(userId, page, size));
    }
    
    /**
     * 获取关注/粉丝数量
     */
    @GetMapping("/{userId}/follow-stats")
    public ResponseEntity<Map<String, Long>> getFollowStats(@PathVariable Long userId) {
        return ResponseEntity.ok(Map.of(
            "followingCount", followService.getFollowingCount(userId),
            "followerCount", followService.getFollowerCount(userId)
        ));
    }
    
    /**
     * 获取用户信息
     */
    @GetMapping("/{userId}")
    public ResponseEntity<UserDTO> getUserProfile(@PathVariable Long userId) {
        return ResponseEntity.ok(authService.getUserById(userId));
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
