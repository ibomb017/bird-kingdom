import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { login as loginApi, logout as logoutApi } from '@/api/auth'

export interface AdminUser {
    id: number
    phone: string
    nickname: string
    avatar?: string
    role: string
}

export const useUserStore = defineStore('user', () => {
    const token = ref<string>(localStorage.getItem('admin_token') || '')
    const userInfo = ref<AdminUser | null>(null)

    const isLoggedIn = computed(() => !!token.value)

    const setToken = (newToken: string) => {
        token.value = newToken
        localStorage.setItem('admin_token', newToken)
    }

    const clearToken = () => {
        token.value = ''
        localStorage.removeItem('admin_token')
    }

    const login = async (phone: string, password: string) => {
        try {
            const res = await loginApi(phone, password)
            if (res.code === 0 && res.data) {
                setToken(res.data.token)
                userInfo.value = res.data.user as AdminUser
                return true
            }
            return false
        } catch {
            return false
        }
    }

    const logout = async () => {
        try {
            await logoutApi()
        } finally {
            clearToken()
            userInfo.value = null
        }
    }

    return {
        token,
        userInfo,
        isLoggedIn,
        login,
        logout,
        setToken,
        clearToken
    }
})
