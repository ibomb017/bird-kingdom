package com.birdkingdom.controller;

import com.birdkingdom.dto.BirdDTO;
import com.birdkingdom.entity.BirdShare;
import com.birdkingdom.service.BirdService;
import com.birdkingdom.service.BirdShareService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/birds")
@CrossOrigin(origins = "*")
public class BirdController {

    private final BirdService birdService;
    private final BirdShareService birdShareService;

    public BirdController(BirdService birdService, BirdShareService birdShareService) {
        this.birdService = birdService;
        this.birdShareService = birdShareService;
    }

    /** 获取所有鸟档案 */
    @GetMapping
    public ResponseEntity<List<BirdDTO>> getAllBirds() {
        return ResponseEntity.ok(birdService.getAllBirds());
    }

    /** 获取单个鸟档案 */
    @GetMapping("/{id}")
    public ResponseEntity<BirdDTO> getBirdById(@PathVariable Long id) {
        return ResponseEntity.ok(birdService.getBirdById(id));
    }

    /** 创建鸟档案 */
    @PostMapping
    public ResponseEntity<BirdDTO> createBird(@Valid @RequestBody BirdDTO dto) {
        return ResponseEntity.ok(birdService.createBird(dto));
    }

    /** 更新鸟档案 */
    @PutMapping("/{id}")
    public ResponseEntity<BirdDTO> updateBird(@PathVariable Long id, @Valid @RequestBody BirdDTO dto) {
        return ResponseEntity.ok(birdService.updateBird(id, dto));
    }

    /** 删除鸟档案（软删除） */
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteBird(@PathVariable Long id) {
        birdService.deleteBird(id);
        return ResponseEntity.noContent().build();
    }
    
    /** 恢复已删除的鸟档案 */
    @PostMapping("/{id}/restore")
    public ResponseEntity<BirdDTO> restoreBird(@PathVariable Long id) {
        return ResponseEntity.ok(birdService.restoreBird(id));
    }
    
    /** 获取回收站中的鸟档案 */
    @GetMapping("/deleted")
    public ResponseEntity<List<BirdDTO>> getDeletedBirds(@RequestParam Long userId) {
        return ResponseEntity.ok(birdService.getDeletedBirds(userId));
    }
    
    /** 获取活跃的鸟档案 */
    @GetMapping("/active")
    public ResponseEntity<List<BirdDTO>> getActiveBirds(@RequestParam Long userId) {
        return ResponseEntity.ok(birdService.getActiveBirds(userId));
    }
    
    /** 获取鸟的共享用户列表 */
    @GetMapping("/{id}/shared-users")
    public ResponseEntity<List<Map<String, Object>>> getBirdSharedUsers(@PathVariable Long id) {
        return ResponseEntity.ok(birdShareService.getBirdSharedUsers(id));
    }
    
    /** 发送共享邀请 */
    @PostMapping("/{id}/share")
    public ResponseEntity<Map<String, Object>> shareBird(
            @PathVariable Long id,
            @RequestBody Map<String, String> request) {
        Long ownerId = Long.parseLong(request.get("ownerId"));
        String targetPhone = request.get("targetPhone");
        String role = request.get("role");
        
        BirdShare share = birdShareService.sendShareInvitation(id, ownerId, targetPhone, role);
        
        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("message", "邀请已发送");
        response.put("shareId", share.getId());
        
        return ResponseEntity.ok(response);
    }
    
    /** 移除共享用户 */
    @DeleteMapping("/{birdId}/shared-users/{userId}")
    public ResponseEntity<Void> removeSharedUser(
            @PathVariable Long birdId,
            @PathVariable Long userId) {
        birdShareService.removeSharedUser(birdId, userId);
        return ResponseEntity.noContent().build();
    }
    
    /** 更新共享用户角色 */
    @PatchMapping("/{birdId}/shared-users/{userId}")
    public ResponseEntity<Map<String, Object>> updateSharedUserRole(
            @PathVariable Long birdId,
            @PathVariable Long userId,
            @RequestBody Map<String, String> request) {
        String newRole = request.get("role");
        Map<String, Object> result = birdShareService.updateSharedUserRole(birdId, userId, newRole);
        return ResponseEntity.ok(result);
    }
    
    /** 退出共享 */
    @PostMapping("/{birdId}/leave")
    public ResponseEntity<Void> leaveSharedBird(@PathVariable Long birdId, @RequestParam Long userId) {
        birdShareService.removeSharedUser(birdId, userId);
        return ResponseEntity.ok().build();
    }
}
