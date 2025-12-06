package com.birdkingdom.controller;

import com.birdkingdom.service.BirdShareService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/invitations")
@CrossOrigin(origins = "*")
public class InvitationController {

    private final BirdShareService birdShareService;

    public InvitationController(BirdShareService birdShareService) {
        this.birdShareService = birdShareService;
    }

    /** 获取用户收到的邀请 */
    @GetMapping
    public ResponseEntity<List<Map<String, Object>>> getUserInvitations(@RequestParam Long userId) {
        return ResponseEntity.ok(birdShareService.getUserInvitations(userId));
    }

    /** 接受邀请 */
    @PostMapping("/{id}/accept")
    public ResponseEntity<Void> acceptInvitation(@PathVariable Long id, @RequestParam Long userId) {
        birdShareService.acceptInvitation(id, userId);
        return ResponseEntity.ok().build();
    }

    /** 拒绝邀请 */
    @PostMapping("/{id}/reject")
    public ResponseEntity<Void> rejectInvitation(@PathVariable Long id, @RequestParam Long userId) {
        birdShareService.rejectInvitation(id, userId);
        return ResponseEntity.ok().build();
    }
}
