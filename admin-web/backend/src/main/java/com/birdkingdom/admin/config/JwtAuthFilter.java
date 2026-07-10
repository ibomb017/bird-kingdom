package com.birdkingdom.admin.config;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.Collections;
import java.util.Map;
import com.birdkingdom.admin.service.AdminAuthService;

/**
 * JWT 认证过滤器
 */
@Component
public class JwtAuthFilter extends OncePerRequestFilter {

    @Autowired
    private JwtUtil jwtUtil;
    
    @Autowired
    private AdminAuthService adminAuthService;

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {

        String authHeader = request.getHeader("Authorization");

        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            String token = authHeader.substring(7);
            
            try {
                if (!jwtUtil.isTokenExpired(token)) {
                    Long adminId = jwtUtil.getAdminIdFromToken(token);
                    
                    if (adminId != null && SecurityContextHolder.getContext().getAuthentication() == null) {
                        Map<String, Object> adminInfo = adminAuthService.getAdminByToken(authHeader);
                        if (adminInfo != null) {
                            String username = (String) adminInfo.get("username");
                            String role = (String) adminInfo.get("role");
                            UsernamePasswordAuthenticationToken authentication = 
                                    new UsernamePasswordAuthenticationToken(username, null, 
                                            Collections.singletonList(new SimpleGrantedAuthority("ROLE_" + role)));
                            
                            SecurityContextHolder.getContext().setAuthentication(authentication);
                        }
                    }
                }
            } catch (Exception e) {
                // Invalid token, ignore
            }
        }

        filterChain.doFilter(request, response);
    }
}
