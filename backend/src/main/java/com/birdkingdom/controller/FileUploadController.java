package com.birdkingdom.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/upload")
@CrossOrigin(origins = "*")
public class FileUploadController {

    // 上传目录（实际应用中应该配置到配置文件）
    private static final String UPLOAD_DIR = "uploads/avatars/";
    
    static {
        // 确保上传目录存在
        try {
            Files.createDirectories(Paths.get(UPLOAD_DIR));
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    /**
     * 上传鸟儿头像
     */
    @PostMapping("/bird-avatar")
    public ResponseEntity<Map<String, String>> uploadBirdAvatar(@RequestParam("file") MultipartFile file) {
        System.out.println("📥 收到文件上传请求");
        
        try {
            if (file.isEmpty()) {
                System.out.println("❌ 文件为空");
                return ResponseEntity.badRequest().body(Map.of("error", "文件为空"));
            }

            System.out.println("📦 文件名: " + file.getOriginalFilename());
            System.out.println("📦 文件大小: " + file.getSize() + " bytes (" + (file.getSize() / 1024.0 / 1024.0) + " MB)");
            System.out.println("📦 Content-Type: " + file.getContentType());

            // 验证文件类型
            String contentType = file.getContentType();
            if (contentType == null || !contentType.startsWith("image/")) {
                System.out.println("❌ 不是图片文件");
                return ResponseEntity.badRequest().body(Map.of("error", "只能上传图片文件"));
            }

            // 生成唯一文件名
            String originalFilename = file.getOriginalFilename();
            String extension = originalFilename != null && originalFilename.contains(".") 
                ? originalFilename.substring(originalFilename.lastIndexOf(".")) 
                : ".jpg";
            String filename = UUID.randomUUID().toString() + extension;

            // 保存文件
            Path filePath = Paths.get(UPLOAD_DIR + filename);
            System.out.println("💾 保存到: " + filePath.toAbsolutePath());
            
            Files.copy(file.getInputStream(), filePath);
            System.out.println("✅ 文件保存成功");

            // 返回文件URL
            String fileUrl = "/uploads/avatars/" + filename;
            
            Map<String, String> response = new HashMap<>();
            response.put("url", fileUrl);
            response.put("filename", filename);
            
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            System.out.println("❌ 上传失败: " + e.getClass().getName() + " - " + e.getMessage());
            e.printStackTrace();
            
            // 检查是否是文件大小限制
            if (e.getMessage() != null && e.getMessage().contains("Maximum upload size")) {
                return ResponseEntity.badRequest().body(Map.of("error", "Maximum upload size exceeded"));
            }
            
            return ResponseEntity.internalServerError().body(Map.of("error", "文件上传失败: " + e.getMessage()));
        }
    }
    
    /**
     * 上传用户头像
     */
    @PostMapping("/user-avatar")
    public ResponseEntity<Map<String, String>> uploadUserAvatar(@RequestParam("file") MultipartFile file) {
        // 与鸟儿头像上传逻辑相同
        return uploadBirdAvatar(file);
    }
}
