package com.birdkingdom.service;

import com.birdkingdom.dto.UserDTO;
import com.birdkingdom.entity.User;
import com.birdkingdom.entity.UserFollow;
import com.birdkingdom.repository.UserFollowRepository;
import com.birdkingdom.repository.UserRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class UserFollowService {

    private final UserFollowRepository followRepository;
    private final UserRepository userRepository;

    public UserFollowService(UserFollowRepository followRepository, UserRepository userRepository) {
        this.followRepository = followRepository;
        this.userRepository = userRepository;
    }
    
    /**
     * 关注/取消关注
     */
    @Transactional
    public boolean toggleFollow(Long followerId, Long followingId) {
        if (followerId.equals(followingId)) {
            throw new RuntimeException("不能关注自己");
        }
        
        User follower = userRepository.findById(followerId)
            .orElseThrow(() -> new RuntimeException("用户不存在"));
        User following = userRepository.findById(followingId)
            .orElseThrow(() -> new RuntimeException("被关注用户不存在"));
        
        if (followRepository.existsByFollowerIdAndFollowingId(followerId, followingId)) {
            followRepository.deleteByFollowerIdAndFollowingId(followerId, followingId);
            return false;
        } else {
            UserFollow follow = new UserFollow();
            follow.setFollower(follower);
            follow.setFollowing(following);
            followRepository.save(follow);
            return true;
        }
    }
    
    /**
     * 检查是否关注
     */
    public boolean isFollowing(Long followerId, Long followingId) {
        return followRepository.existsByFollowerIdAndFollowingId(followerId, followingId);
    }
    
    /**
     * 获取关注列表
     */
    public Page<UserDTO> getFollowing(Long userId, int page, int size) {
        Pageable pageable = PageRequest.of(page, size);
        Page<UserFollow> follows = followRepository.findByFollowerIdOrderByCreatedAtDesc(userId, pageable);
        return follows.map(follow -> convertToDTO(follow.getFollowing(), userId));
    }
    
    /**
     * 获取粉丝列表
     */
    public Page<UserDTO> getFollowers(Long userId, int page, int size) {
        Pageable pageable = PageRequest.of(page, size);
        Page<UserFollow> follows = followRepository.findByFollowingIdOrderByCreatedAtDesc(userId, pageable);
        return follows.map(follow -> convertToDTO(follow.getFollower(), userId));
    }
    
    /**
     * 获取关注数
     */
    public long getFollowingCount(Long userId) {
        return followRepository.countByFollowerId(userId);
    }
    
    /**
     * 获取粉丝数
     */
    public long getFollowerCount(Long userId) {
        return followRepository.countByFollowingId(userId);
    }
    
    /**
     * 转换为DTO
     */
    private UserDTO convertToDTO(User user, Long currentUserId) {
        UserDTO dto = new UserDTO();
        dto.setId(user.getId());
        dto.setPhone(user.getPhone());
        dto.setNickname(user.getNickname());
        dto.setAvatarUrl(user.getAvatarUrl());
        dto.setBio(user.getBio());
        dto.setIsVip(user.getIsVip());
        dto.setCreatedAt(user.getCreatedAt());
        
        // 统计
        dto.setFollowerCount((int) followRepository.countByFollowingId(user.getId()));
        dto.setFollowingCount((int) followRepository.countByFollowerId(user.getId()));
        
        return dto;
    }
}
