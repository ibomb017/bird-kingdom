import { defineStore } from 'pinia'
import { ref, watch } from 'vue'

export const useSettingsStore = defineStore('settings', () => {
    const isDark = ref<boolean>(localStorage.getItem('admin_dark') === 'true' || true)
    const isCollapse = ref<boolean>(false)

    // 监听暗色模式变化
    watch(isDark, (val) => {
        localStorage.setItem('admin_dark', String(val))
        if (val) {
            document.documentElement.classList.add('dark')
        } else {
            document.documentElement.classList.remove('dark')
        }
    }, { immediate: true })

    const toggleDark = () => {
        isDark.value = !isDark.value
    }

    const toggleCollapse = () => {
        isCollapse.value = !isCollapse.value
    }

    return {
        isDark,
        isCollapse,
        toggleDark,
        toggleCollapse
    }
})
