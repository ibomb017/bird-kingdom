import { request as baseRequest } from '@/utils/request'
import axios from 'axios'

export interface LoginResult {
    token: string
    user: {
        id: number
        phone: string
        nickname: string
        avatarUrl?: string
        role: string
    }
}

// 后端返回的登录响应格式
interface BackendLoginResponse {
    success: boolean
    message: string
    token: string | null
    user: LoginResult['user'] | null
}

// 手机号+密码登录 (使用后端现有接口)
// 注意：后端返回格式与标准 API 不同，需要特殊处理
export const login = async (phone: string, password: string) => {
    const baseURL = import.meta.env.VITE_API_BASE_URL || '/api'

    try {
        const response = await axios.post<BackendLoginResponse>(
            `${baseURL}/admin/auth/login`,
            { username: phone, password },
            { headers: { 'Content-Type': 'application/json' } }
        )

        const data = response.data

        if (data.success && data.token && data.user) {
            // 转换为标准格式
            return {
                code: 0,
                message: data.message,
                data: {
                    token: data.token,
                    user: data.user
                }
            }
        } else {
            return {
                code: -1,
                message: data.message || '登录失败',
                data: null
            }
        }
    } catch (error: any) {
        const message = error.response?.data?.reason || error.response?.data?.message || error.message || '网络错误'
        return {
            code: -1,
            message,
            data: null
        }
    }
}

// 登出 (后端没有此接口，本地清理即可)
export const logout = () => {
    return Promise.resolve({ code: 0, data: null, message: 'ok' })
}

// 获取当前用户信息
export const getCurrentUser = () => {
    return baseRequest.get('/auth/me')
}
