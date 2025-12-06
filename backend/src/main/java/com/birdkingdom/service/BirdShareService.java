package com.birdkingdom.service;

import com.birdkingdom.entity.Bird;
import com.birdkingdom.entity.BirdShare;
import com.birdkingdom.entity.User;
import com.birdkingdom.repository.BirdRepository;
import com.birdkingdom.repository.BirdShareRepository;
import com.birdkingdom.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
public class BirdShareService {

    private final BirdShareRepository birdShareRepository;
    private final BirdRepository birdRepository;
    private final UserRepository userRepository;

    public BirdShareService(BirdShareRepository birdShareRepository,
                           BirdRepository birdRepository,
                           UserRepository userRepository) {
        this.birdShareRepository = birdShareRepository;
        this.birdRepository = birdRepository;
        this.userRepository = userRepository;
    }

    /**
     * 发送共享邀请
     */
    @Transactional
    public BirdShare sendShareInvitation(Long birdId, Long ownerId, String targetPhone, String role) {
        Bird bird = birdRepository.findById(birdId)
                .orElseThrow(() -> new RuntimeException("鸟档案不存在"));
        
        User owner = userRepository.findById(ownerId)
                .orElseThrow(() -> new RuntimeException("用户不存在"));
        
        User targetUser = userRepository.findByPhone(targetPhone)
                .orElseThrow(() -> new RuntimeException("目标用户不存在"));
        
        // 检查是否已经共享
        if (birdShareRepository.existsByBirdIdAndSharedUserIdAndStatus(birdId, targetUser.getId(), "ACCEPTED")) {
            throw new RuntimeException("该用户已经是共享用户");
        }
        
        // 检查是否有待处理的邀请
        if (birdShareRepository.existsByBirdIdAndSharedUserIdAndStatus(birdId, targetUser.getId(), "PENDING")) {
            throw new RuntimeException("已有待处理的邀请");
        }
        
        BirdShare share = new BirdShare();
        share.setBird(bird);
        share.setOwner(owner);
        share.setSharedUser(targetUser);
        share.setRole(role);
        share.setStatus("PENDING");
        
        return birdShareRepository.save(share);
    }

    /**
     * 获取鸟的共享用户列表
     */
    public List<Map<String, Object>> getBirdSharedUsers(Long birdId) {
        List<BirdShare> shares = birdShareRepository.findByBirdIdAndStatus(birdId, "ACCEPTED");
        
        return shares.stream().map(share -> {
            Map<String, Object> userInfo = new HashMap<>();
            User user = share.getSharedUser();
            userInfo.put("id", share.getId());
            userInfo.put("userId", user.getId());
            userInfo.put("nickname", user.getNickname());
            userInfo.put("phone", user.getPhone());
            userInfo.put("role", share.getRole());
            userInfo.put("sharedAt", share.getCreatedAt());
            return userInfo;
        }).collect(Collectors.toList());
    }

    /**
     * 获取用户收到的邀请
     */
    public List<Map<String, Object>> getUserInvitations(Long userId) {
        List<BirdShare> shares = birdShareRepository.findBySharedUserIdAndStatus(userId, "PENDING");
        
        return shares.stream().map(share -> {
            Map<String, Object> invitation = new HashMap<>();
            Bird bird = share.getBird();
            User owner = share.getOwner();
            
            invitation.put("id", share.getId());
            invitation.put("birdId", bird.getId());
            invitation.put("birdName", bird.getNickname());
            invitation.put("birdSpecies", bird.getSpecies());
            invitation.put("ownerName", owner.getNickname());
            invitation.put("role", share.getRole());
            invitation.put("createdAt", share.getCreatedAt());
            
            return invitation;
        }).collect(Collectors.toList());
    }

    /**
     * 接受邀请
     */
    @Transactional
    public void acceptInvitation(Long shareId, Long userId) {
        BirdShare share = birdShareRepository.findById(shareId)
                .orElseThrow(() -> new RuntimeException("邀请不存在"));
        
        if (!share.getSharedUser().getId().equals(userId)) {
            throw new RuntimeException("无权操作此邀请");
        }
        
        if (!"PENDING".equals(share.getStatus())) {
            throw new RuntimeException("邀请已处理");
        }
        
        share.setStatus("ACCEPTED");
        birdShareRepository.save(share);
    }

    /**
     * 拒绝邀请
     */
    @Transactional
    public void rejectInvitation(Long shareId, Long userId) {
        BirdShare share = birdShareRepository.findById(shareId)
                .orElseThrow(() -> new RuntimeException("邀请不存在"));
        
        if (!share.getSharedUser().getId().equals(userId)) {
            throw new RuntimeException("无权操作此邀请");
        }
        
        if (!"PENDING".equals(share.getStatus())) {
            throw new RuntimeException("邀请已处理");
        }
        
        share.setStatus("REJECTED");
        birdShareRepository.save(share);
    }

    /**
     * 移除共享用户
     */
    @Transactional
    public void removeSharedUser(Long birdId, Long userId) {
        BirdShare share = birdShareRepository.findByBirdIdAndSharedUserId(birdId, userId)
                .orElseThrow(() -> new RuntimeException("共享关系不存在"));
        
        birdShareRepository.delete(share);
    }

    /**
     * 更新共享用户角色
     */
    @Transactional
    public Map<String, Object> updateSharedUserRole(Long birdId, Long userId, String newRole) {
        BirdShare share = birdShareRepository.findByBirdIdAndSharedUserId(birdId, userId)
                .orElseThrow(() -> new RuntimeException("共享关系不存在"));
        
        share.setRole(newRole);
        share = birdShareRepository.save(share);
        
        Map<String, Object> result = new HashMap<>();
        User user = share.getSharedUser();
        result.put("id", share.getId());
        result.put("userId", user.getId());
        result.put("nickname", user.getNickname());
        result.put("role", share.getRole());
        
        return result;
    }
}
