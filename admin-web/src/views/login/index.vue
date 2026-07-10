<script setup lang="ts">
import { ref, reactive } from 'vue'
import { useRouter } from 'vue-router'
import { useUserStore } from '@/stores/user'
import { ElMessage } from 'element-plus'
import { User, Lock, Promotion, InfoFilled } from '@element-plus/icons-vue'

const router = useRouter()
const userStore = useUserStore()

const loading = ref(false)
const loginForm = reactive({
  phone: '',
  password: ''
})

const rules = {
  phone: [
    { required: true, message: '请输入手机号', trigger: 'blur' },
    { pattern: /^1[3-9]\d{9}$/, message: '请输入有效的手机号', trigger: 'blur' }
  ],
  password: [
    { required: true, message: '请输入密码', trigger: 'blur' },
    { min: 6, message: '密码至少6位', trigger: 'blur' }
  ]
}

const handleLogin = async () => {
  loading.value = true
  try {
    const success = await userStore.login(loginForm.phone, loginForm.password)
    if (success) {
      ElMessage.success('登录成功')
      router.push('/')
    } else {
      ElMessage.error('手机号或密码错误')
    }
  } catch (e: any) {
    ElMessage.error(e?.message || '登录失败，请重试')
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="login-container">
    <div class="login-card">
      <!-- Logo -->
      <div class="login-header">
        <span class="logo-icon"><el-icon><Promotion /></el-icon></span>
        <h1 class="logo-title">Bird Kingdom Admin</h1>
        <p class="logo-subtitle">鸟鸟王国管理后台</p>
      </div>
      
      <!-- 登录表单 -->
      <el-form
        :model="loginForm"
        :rules="rules"
        class="login-form"
        @submit.prevent="handleLogin"
      >
        <el-form-item prop="phone">
          <el-input
            v-model="loginForm.phone"
            placeholder="请输入手机号"
            size="large"
            :prefix-icon="User"
          />
        </el-form-item>
        
        <el-form-item prop="password">
          <el-input
            v-model="loginForm.password"
            type="password"
            placeholder="请输入密码"
            size="large"
            :prefix-icon="Lock"
            show-password
            @keyup.enter="handleLogin"
          />
        </el-form-item>
        
        <el-form-item>
          <el-button
            type="primary"
            size="large"
            class="login-btn"
            :loading="loading"
            @click="handleLogin"
          >
            登 录
          </el-button>
        </el-form-item>
      </el-form>
      
      <div class="login-tips">
        <p><el-icon><InfoFilled /></el-icon> 提示: 请使用已注册的手机号和密码登录</p>
        <p>需要 ADMIN 角色才能使用管理功能</p>
      </div>
      
      <!-- 底部信息 -->
      <div class="login-footer">
        <span>© 2025 Bird Kingdom. All rights reserved.</span>
      </div>
    </div>
    
    <!-- 背景装饰 -->
    <div class="login-bg">
      <div class="bg-circle bg-circle-1"></div>
      <div class="bg-circle bg-circle-2"></div>
      <div class="bg-circle bg-circle-3"></div>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.login-container {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
  position: relative;
  overflow: hidden;
}

.login-card {
  width: 400px;
  padding: 40px;
  background: rgba(255, 255, 255, 0.05);
  backdrop-filter: blur(20px);
  border-radius: 16px;
  border: 1px solid rgba(255, 255, 255, 0.1);
  box-shadow: 0 25px 50px rgba(0, 0, 0, 0.3);
  z-index: 10;
}

.login-header {
  text-align: center;
  margin-bottom: 40px;
  
  .logo-icon {
    font-size: 56px;
    display: block;
    margin-bottom: 16px;
  }
  
  .logo-title {
    font-size: 24px;
    font-weight: 600;
    color: var(--text-primary);
    margin: 0 0 8px;
  }
  
  .logo-subtitle {
    font-size: 14px;
    color: rgba(255, 255, 255, 0.6);
    margin: 0;
  }
}

.login-form {
  :deep(.el-input) {
    --el-input-bg-color: rgba(255, 255, 255, 0.05);
    --el-input-border-color: rgba(255, 255, 255, 0.1);
    --el-input-text-color: var(--text-primary);
    --el-input-placeholder-color: rgba(255, 255, 255, 0.4);
    
    .el-input__wrapper {
      background-color: var(--el-input-bg-color);
      box-shadow: 0 0 0 1px var(--el-input-border-color) inset;
      border-radius: 8px;
      
      &:hover,
      &.is-focus {
        box-shadow: 0 0 0 1px var(--primary-color) inset;
      }
    }
    
    .el-input__prefix {
      color: rgba(255, 255, 255, 0.5);
    }
  }
}

.login-btn {
  width: 100%;
  height: 48px;
  font-size: 16px;
  border-radius: 8px;
  background: linear-gradient(135deg, #409EFF 0%, #66B1FF 100%);
  border: none;
  
  &:hover {
    background: linear-gradient(135deg, #66B1FF 0%, #409EFF 100%);
  }
}

.login-tips {
  margin-top: 20px;
  text-align: center;
  color: rgba(255, 255, 255, 0.5);
  font-size: 12px;
  line-height: 1.8;
  p { margin: 0; }
}

.login-footer {
  margin-top: 30px;
  text-align: center;
  color: rgba(255, 255, 255, 0.4);
  font-size: 12px;
}

// 背景装饰
.login-bg {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  pointer-events: none;
}

.bg-circle {
  position: absolute;
  border-radius: 50%;
  opacity: 0.1;
  
  &.bg-circle-1 {
    width: 400px;
    height: 400px;
    background: linear-gradient(135deg, #409EFF, #66B1FF);
    top: -100px;
    right: -100px;
    animation: float 8s ease-in-out infinite;
  }
  
  &.bg-circle-2 {
    width: 300px;
    height: 300px;
    background: linear-gradient(135deg, #67C23A, #95D475);
    bottom: -50px;
    left: -50px;
    animation: float 10s ease-in-out infinite reverse;
  }
  
  &.bg-circle-3 {
    width: 200px;
    height: 200px;
    background: linear-gradient(135deg, #E6A23C, #F3D19E);
    top: 50%;
    left: 10%;
    animation: float 6s ease-in-out infinite;
  }
}

@keyframes float {
  0%, 100% {
    transform: translateY(0) rotate(0deg);
  }
  50% {
    transform: translateY(-20px) rotate(5deg);
  }
}
</style>
