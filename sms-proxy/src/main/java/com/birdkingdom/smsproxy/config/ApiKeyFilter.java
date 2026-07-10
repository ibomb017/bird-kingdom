package com.birdkingdom.smsproxy.config;

import jakarta.servlet.*;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.io.IOException;

/**
 * API Key 认证过滤器
 * 保护短信接口不被未授权访问
 */
@Component
public class ApiKeyFilter implements Filter {

    @Value("${sms-proxy.api-key}")
    private String apiKey;

    private static final String API_KEY_HEADER = "X-API-Key";

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {

        HttpServletRequest httpRequest = (HttpServletRequest) request;
        HttpServletResponse httpResponse = (HttpServletResponse) response;

        String path = httpRequest.getRequestURI();

        // 只对内部短信接口进行认证
        if (path.startsWith("/internal/sms")) {
            String providedApiKey = httpRequest.getHeader(API_KEY_HEADER);

            if (providedApiKey == null || !providedApiKey.equals(apiKey)) {
                System.err.println("⚠️ 未授权访问尝试: " + httpRequest.getRemoteAddr() + " -> " + path);
                httpResponse.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
                httpResponse.setContentType("application/json;charset=UTF-8");
                httpResponse.getWriter().write("{\"success\":false,\"message\":\"Unauthorized\"}");
                return;
            }
        }

        chain.doFilter(request, response);
    }
}
