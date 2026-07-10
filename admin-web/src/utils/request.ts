import axios, { type AxiosInstance, type AxiosRequestConfig, type AxiosResponse } from 'axios'
import { ElMessage } from 'element-plus'
import { useUserStore } from '@/stores/user'

// API 响应类型
export interface ApiResponse<T = any> {
    code: number
    message: string
    data: T
}

// 创建 axios 实例
const service: AxiosInstance = axios.create({
    baseURL: import.meta.env.VITE_API_BASE_URL || '/api/admin',
    timeout: 30000,
    headers: {
        'Content-Type': 'application/json'
    }
})

// 请求拦截器
service.interceptors.request.use(
    (config) => {
        const userStore = useUserStore()
        if (userStore.token) {
            config.headers.Authorization = `Bearer ${userStore.token}`
        }
        return config
    },
    (error) => {
        console.error('Request error:', error)
        return Promise.reject(error)
    }
)

// 响应拦截器
service.interceptors.response.use(
    (response: AxiosResponse<any>) => {
        let res = response.data

        // 兼容 Swift 后端：如果直接返回对象或数组，没有标准的 code 字段
        if (res && res.code === undefined) {
             // 检查是否为 PageResponse { content: [...], totalElements: X } 这种形式
             if (res.content !== undefined && res.totalElements !== undefined) {
                 res = { code: 0, message: 'success', data: res }
             } else if (Array.isArray(res)) {
                 // 如果直接返回数组，模拟分页结构
                 res = { code: 0, message: 'success', data: { content: res, totalElements: res.length } }
             } else {
                 // 其他对象类型直接包装
                 res = { code: 0, message: 'success', data: res }
             }
             // 将改变后的规范化响应放回
             response.data = res
        }

        // 业务错误
        if (res.code !== 0) {
            ElMessage.error(res.message || '请求失败')

            // 401 未授权，跳转登录
            if (res.code === 401) {
                const userStore = useUserStore()
                userStore.clearToken()
                window.location.href = '/admin/login'
            }

            return Promise.reject(new Error(res.message || 'Error'))
        }

        return response
    },
    (error) => {
        console.error('Response error:', error)
        const message = error.response?.data?.message || (error.response?.data?.reason) || error.message || '网络错误'
        // Swift Vapor usually returns { "error": true, "reason": "auth failed" }
        if (error.response?.status === 401) {
            const userStore = useUserStore()
            userStore.clearToken()
            window.location.href = '/admin/login'
            ElMessage.error('登录失效请重新登录')
        } else {
            ElMessage.error(message)
        }
        return Promise.reject(error)
    }
)

// 封装请求方法
export const request = {
    get<T = any>(url: string, config?: AxiosRequestConfig): Promise<ApiResponse<T>> {
        return service.get(url, config).then(res => res.data)
    },

    post<T = any>(url: string, data?: any, config?: AxiosRequestConfig): Promise<ApiResponse<T>> {
        return service.post(url, data, config).then(res => res.data)
    },

    put<T = any>(url: string, data?: any, config?: AxiosRequestConfig): Promise<ApiResponse<T>> {
        return service.put(url, data, config).then(res => res.data)
    },

    delete<T = any>(url: string, config?: AxiosRequestConfig): Promise<ApiResponse<T>> {
        return service.delete(url, config).then(res => res.data)
    }
}

export default request
