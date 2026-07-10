<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useUserStore } from '@/stores/user'
import { useSettingsStore } from '@/stores/settings'
import { ElMessage, ElMessageBox } from 'element-plus'
import request from '@/utils/request'

const route = useRoute()
const router = useRouter()
const userStore = useUserStore()
const settingsStore = useSettingsStore()

// 消息通知
const notifications = ref<any[]>([])
const notificationCount = ref(0)
const notificationVisible = ref(false)

// 个人信息弹窗
const profileVisible = ref(false)
const profileForm = ref({ nickname: '', phone: '', email: '' })
const profileLoading = ref(false)

// 修改密码弹窗
const passwordVisible = ref(false)
const passwordForm = ref({ oldPassword: '', newPassword: '', confirmPassword: '' })
const passwordLoading = ref(false)

// 面包屑
const breadcrumbs = computed(() => {
  const matched = route.matched.filter(item => item.meta?.title)
  return matched.map(item => ({
    title: item.meta?.title as string,
    path: item.path
  }))
})

// 加载通知
const loadNotifications = async () => {
  try {
    const res = await request.get('/stats/todos')
    if (res.code === 0) {
      notifications.value = res.data || []
      notificationCount.value = notifications.value.reduce((sum: number, n: any) => sum + (n.count || 0), 0)
    }
  } catch (e) { console.error(e) }
}

// 切换侧边栏折叠
const toggleCollapse = () => {
  settingsStore.toggleCollapse()
}

// 切换暗色模式
const toggleDark = () => {
  settingsStore.toggleDark()
}

// 处理通知点击
const handleNotificationClick = (notification: any) => {
  notificationVisible.value = false
  if (notification.path) {
    router.push(notification.path)
  }
}

// 显示个人信息
const showProfile = () => {
  const user = userStore.userInfo
  profileForm.value = {
    nickname: user?.nickname || '',
    phone: user?.phone || '',
    email: user?.email || ''
  }
  profileVisible.value = true
}

// 保存个人信息
const saveProfile = async () => {
  if (!profileForm.value.nickname) {
    ElMessage.warning('请输入昵称')
    return
  }
  
  profileLoading.value = true
  try {
    const res = await request.put('/system/admins/me', profileForm.value)
    if (res.code === 0) {
      ElMessage.success('保存成功')
      profileVisible.value = false
      // 更新本地用户信息
      userStore.userInfo = { ...userStore.userInfo, ...profileForm.value }
    } else {
      ElMessage.error(res.message)
    }
  } catch (e) { ElMessage.error('保存失败') }
  finally { profileLoading.value = false }
}

// 显示修改密码
const showChangePassword = () => {
  passwordForm.value = { oldPassword: '', newPassword: '', confirmPassword: '' }
  passwordVisible.value = true
}

// 修改密码
const changePassword = async () => {
  if (!passwordForm.value.oldPassword || !passwordForm.value.newPassword) {
    ElMessage.warning('请填写所有必填项')
    return
  }
  if (passwordForm.value.newPassword !== passwordForm.value.confirmPassword) {
    ElMessage.warning('两次输入的密码不一致')
    return
  }
  if (passwordForm.value.newPassword.length < 6) {
    ElMessage.warning('新密码长度不能少于6位')
    return
  }
  
  passwordLoading.value = true
  try {
    const res = await request.post('/auth/change-password', {
      oldPassword: passwordForm.value.oldPassword,
      newPassword: passwordForm.value.newPassword
    })
    if (res.code === 0) {
      ElMessage.success('密码修改成功，请重新登录')
      passwordVisible.value = false
      await userStore.logout()
      router.push('/login')
    } else {
      ElMessage.error(res.message)
    }
  } catch (e) { ElMessage.error('修改失败') }
  finally { passwordLoading.value = false }
}

// 处理下拉菜单命令
const handleCommand = (command: string) => {
  if (command === 'profile') {
    showProfile()
  } else if (command === 'password') {
    showChangePassword()
  } else if (command === 'logout') {
    handleLogout()
  }
}

// 登出
const handleLogout = async () => {
  try {
    await ElMessageBox.confirm('确定要退出登录吗？', '提示', {
      confirmButtonText: '确定',
      cancelButtonText: '取消',
      type: 'warning'
    })
    await userStore.logout()
    router.push('/login')
  } catch {
    // 取消
  }
}

onMounted(() => {
  loadNotifications()
})
</script>

<template>
  <header class="header">
    <!-- 左侧 -->
    <div class="header-left">
      <!-- 折叠按钮 -->
      <el-icon class="collapse-btn" @click="toggleCollapse">
        <component :is="settingsStore.isCollapse ? 'Expand' : 'Fold'" />
      </el-icon>
      
      <!-- 面包屑 -->
      <el-breadcrumb separator="/">
        <el-breadcrumb-item :to="{ path: '/' }">
          <el-icon><HomeFilled /></el-icon>
        </el-breadcrumb-item>
        <el-breadcrumb-item v-for="item in breadcrumbs" :key="item.path">
          {{ item.title }}
        </el-breadcrumb-item>
      </el-breadcrumb>
    </div>
    
    <!-- 右侧 -->
    <div class="header-right">
      <!-- 暗色模式切换 -->
      <el-tooltip :content="settingsStore.isDark ? '切换亮色模式' : '切换暗色模式'">
        <div class="header-icon-btn" @click="toggleDark">
          <el-icon :size="18">
            <Sunny v-if="settingsStore.isDark" />
            <Moon v-else />
          </el-icon>
        </div>
      </el-tooltip>
      
      <!-- 通知 -->
      <el-popover placement="bottom" :width="320" trigger="click" v-model:visible="notificationVisible">
        <template #reference>
          <el-badge :value="notificationCount" :max="99" :hidden="notificationCount === 0" class="header-badge">
            <div class="header-icon-btn">
              <el-icon :size="18"><Bell /></el-icon>
            </div>
          </el-badge>
        </template>
        <div class="notification-panel">
          <div class="notification-header">
            <span>待办通知</span>
            <el-button type="primary" link size="small" @click="loadNotifications">刷新</el-button>
          </div>
          <div class="notification-list">
            <div 
              v-for="n in notifications" 
              :key="n.title" 
              class="notification-item"
              @click="handleNotificationClick(n)"
            >
              <span class="notification-title">{{ n.title }}</span>
              <el-badge :value="n.count" :type="n.type" />
            </div>
            <div v-if="notifications.length === 0" class="notification-empty">
              暂无待办事项
            </div>
          </div>
        </div>
      </el-popover>
      
      <!-- 用户下拉菜单 -->
      <el-dropdown trigger="click" @command="handleCommand">
        <div class="user-info">
          <span class="user-name">{{ userStore.userInfo?.nickname || '管理员' }}</span>
          <el-icon><ArrowDown /></el-icon>
        </div>
        <template #dropdown>
          <el-dropdown-menu>
            <el-dropdown-item command="profile">
              <el-icon><User /></el-icon>
              个人信息
            </el-dropdown-item>
            <el-dropdown-item command="password">
              <el-icon><Lock /></el-icon>
              修改密码
            </el-dropdown-item>
            <el-dropdown-item divided command="logout">
              <el-icon><SwitchButton /></el-icon>
              退出登录
            </el-dropdown-item>
          </el-dropdown-menu>
        </template>
      </el-dropdown>
    </div>
    
    <!-- 个人信息弹窗 -->
    <el-dialog v-model="profileVisible" title="个人信息" width="450px">
      <el-form :model="profileForm" label-width="80px">
        <el-form-item label="用户名">
          <el-input :value="userStore.userInfo?.username" disabled />
        </el-form-item>
        <el-form-item label="昵称">
          <el-input v-model="profileForm.nickname" placeholder="请输入昵称" />
        </el-form-item>
        <el-form-item label="手机号">
          <el-input v-model="profileForm.phone" placeholder="请输入手机号" />
        </el-form-item>
        <el-form-item label="邮箱">
          <el-input v-model="profileForm.email" placeholder="请输入邮箱" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="profileVisible = false">取消</el-button>
        <el-button type="primary" @click="saveProfile" :loading="profileLoading">保存</el-button>
      </template>
    </el-dialog>
    
    <!-- 修改密码弹窗 -->
    <el-dialog v-model="passwordVisible" title="修改密码" width="400px">
      <el-form :model="passwordForm" label-width="100px">
        <el-form-item label="当前密码">
          <el-input v-model="passwordForm.oldPassword" type="password" placeholder="请输入当前密码" show-password />
        </el-form-item>
        <el-form-item label="新密码">
          <el-input v-model="passwordForm.newPassword" type="password" placeholder="请输入新密码（至少6位）" show-password />
        </el-form-item>
        <el-form-item label="确认新密码">
          <el-input v-model="passwordForm.confirmPassword" type="password" placeholder="请再次输入新密码" show-password />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="passwordVisible = false">取消</el-button>
        <el-button type="primary" @click="changePassword" :loading="passwordLoading">确认修改</el-button>
      </template>
    </el-dialog>
  </header>
</template>

<style lang="scss" scoped>
.header {
  height: var(--header-height);
  background-color: var(--bg-header);
  border-bottom: 1px solid var(--border-lighter);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 24px;
}

.header-left {
  display: flex;
  align-items: center;
  gap: 16px;
}

.collapse-btn {
  font-size: 20px;
  cursor: pointer;
  color: var(--text-secondary);
  transition: color 0.2s;
  
  &:hover {
    color: var(--primary-color);
  }
}

.header-right {
  display: flex;
  align-items: center;
  gap: 20px;
}

// 高级图标按钮样式
.header-icon-btn {
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  border-radius: 10px;
  background: var(--bg-card);
  border: 1px solid var(--border-base);
  color: var(--text-primary);
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  position: relative;
  overflow: hidden;
  
  // 发光效果层
  &::before {
    content: '';
    position: absolute;
    inset: 0;
    background: radial-gradient(circle at center, rgba(16, 185, 129, 0.2) 0%, transparent 70%);
    opacity: 0;
    transition: opacity 0.3s;
  }
  
  .el-icon {
    position: relative;
    z-index: 1;
    transition: all 0.3s;
  }
  
  &:hover {
    background: linear-gradient(135deg, rgba(16, 185, 129, 0.15) 0%, rgba(5, 150, 105, 0.1) 100%);
    border-color: var(--primary-color);
    color: var(--primary-color);
    transform: translateY(-2px);
    box-shadow: 0 4px 20px rgba(16, 185, 129, 0.25), 0 0 0 1px rgba(16, 185, 129, 0.1);
    
    &::before {
      opacity: 1;
    }
    
    .el-icon {
      transform: scale(1.15);
    }
  }
  
  &:active {
    transform: translateY(0);
    box-shadow: 0 2px 10px rgba(16, 185, 129, 0.2);
  }
}

// 保留旧的 header-icon 以防其他地方使用
.header-icon {
  font-size: 20px;
  color: var(--text-primary);
  cursor: pointer;
  transition: all 0.2s;
  padding: 8px;
  border-radius: 8px;
  background: var(--bg-card);
  border: 1px solid var(--border-light);
  
  &:hover {
    color: var(--primary-color);
    background: var(--primary-subtle);
    border-color: var(--primary-color);
  }
}

.header-badge {
  :deep(.el-badge__content) {
    border: none;
  }
}

.notification-panel {
  .notification-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding-bottom: 12px;
    border-bottom: 1px solid var(--border-lighter);
    margin-bottom: 12px;
    font-weight: 500;
  }
  
  .notification-list {
    max-height: 300px;
    overflow-y: auto;
  }
  
  .notification-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 12px;
    cursor: pointer;
    border-radius: 8px;
    transition: background 0.2s;
    
    &:hover {
      background: var(--bg-card-hover);
    }
    
    .notification-title {
      font-size: 14px;
    }
  }
  
  .notification-empty {
    text-align: center;
    padding: 24px;
    color: var(--text-placeholder);
  }
}

.user-info {
  display: flex;
  align-items: center;
  gap: 8px;
  cursor: pointer;
  padding: 6px 12px;
  border-radius: var(--radius-md);
  transition: all 0.2s;
  
  &:hover {
    background-color: rgba(16, 185, 129, 0.1);
  }
  
  .user-name {
    color: var(--text-primary);
    font-size: 14px;
  }
  
  .el-icon {
    color: var(--text-secondary);
    font-size: 12px;
  }
}
</style>
