package com.birdkingdom.admin;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * 鸟鸟王国管理后台 - 主启动类
 * 
 * @author Bird Kingdom
 * @since 2025
 */
@SpringBootApplication
public class AdminApplication {

    public static void main(String[] args) {
        SpringApplication.run(AdminApplication.class, args);
        System.out.println("===========================================");
        System.out.println("  🦜 Bird Kingdom Admin Started!");
        System.out.println("  📍 http://localhost:8081");
        System.out.println("  📅 2025 Bird Kingdom");
        System.out.println("===========================================");
    }
}
