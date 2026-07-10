<script setup lang="ts">
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import type { RouteRecordRaw } from 'vue-router'

defineProps<{
  collapse: boolean
}>()

const route = useRoute()
const router = useRouter()

// 获取菜单路由
const menuRoutes = computed(() => {
  return router.options.routes.filter(r => !r.meta?.hidden)
})

const activeMenu = computed(() => route.path)

// 处理菜单点击
const handleMenuClick = (path: string) => {
  router.push(path)
}

// 获取图标组件
const getIcon = (icon?: string) => {
  return icon || 'Menu'
}
</script>

<template>
  <aside class="sidebar" :class="{ 'is-collapse': collapse }">
    <!-- Logo -->
    <div class="sidebar-logo">
      <img src="/app-logo.png" alt="Bird Kingdom" class="logo-img" />
      <transition name="logo-text">
        <span v-show="!collapse" class="logo-text">Bird Kingdom</span>
      </transition>
    </div>
    
    <!-- 菜单 -->
    <el-scrollbar class="sidebar-menu-wrapper">
      <el-menu
        :default-active="activeMenu"
        :collapse="collapse"
        :collapse-transition="false"
        :unique-opened="true"
        background-color="transparent"
        text-color="var(--text-regular)"
        active-text-color="var(--primary-color)"
      >
        <template v-for="menu in menuRoutes" :key="menu.path">
          <!-- 单级菜单 -->
          <el-menu-item
            v-if="!menu.children || menu.children.length === 1"
            :index="menu.redirect || (menu.path + '/' + (menu.children?.[0]?.path || ''))"
            @click="handleMenuClick(menu.redirect || (menu.path + '/' + (menu.children?.[0]?.path || '')))"
            class="menu-item-enhanced"
          >
            <el-icon><component :is="getIcon(menu.meta?.icon as string)" /></el-icon>
            <template #title>{{ menu.children?.[0]?.meta?.title || menu.meta?.title }}</template>
          </el-menu-item>
          
          <!-- 多级菜单 -->
          <el-sub-menu v-else :index="menu.path" class="sub-menu-enhanced">
            <template #title>
              <el-icon><component :is="getIcon(menu.meta?.icon as string)" /></el-icon>
              <span>{{ menu.meta?.title }}</span>
            </template>
            <el-menu-item
              v-for="child in menu.children"
              :key="child.path"
              :index="`${menu.path}/${child.path}`"
              @click="handleMenuClick(`${menu.path}/${child.path}`)"
              class="menu-item-enhanced"
            >
              <el-icon><component :is="getIcon(child.meta?.icon as string)" /></el-icon>
              <template #title>{{ child.meta?.title }}</template>
            </el-menu-item>
          </el-sub-menu>
        </template>
      </el-menu>
    </el-scrollbar>
    
    <!-- 底部版本信息 -->
    <div class="sidebar-footer" v-if="!collapse">
      <span>v1.0.0</span>
    </div>
  </aside>
</template>

<style lang="scss" scoped>
.sidebar {
  position: fixed;
  left: 0;
  top: 0;
  bottom: 0;
  width: var(--sidebar-width);
  background: var(--gradient-sidebar);
  border-right: 1px solid var(--border-lighter);
  display: flex;
  flex-direction: column;
  transition: width var(--transition-normal) cubic-bezier(0.4, 0, 0.2, 1);
  z-index: 1000;
  
  // 侧边栏发光效果
  &::after {
    content: '';
    position: absolute;
    top: 0;
    right: 0;
    bottom: 0;
    width: 1px;
    background: linear-gradient(180deg, 
      transparent 0%, 
      var(--primary-glow) 50%, 
      transparent 100%
    );
    opacity: 0.5;
  }
  
  &.is-collapse {
    width: var(--sidebar-collapsed-width);
    
    .logo-text {
      opacity: 0;
      width: 0;
    }
    
    .sidebar-footer {
      opacity: 0;
    }
  }
}

.sidebar-logo {
  height: var(--header-height);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0 16px;
  border-bottom: 1px solid var(--border-lighter);
  gap: 12px;
  position: relative;
  overflow: hidden;
  
  // Logo发光效果
  &::before {
    content: '';
    position: absolute;
    inset: 0;
    background: radial-gradient(ellipse at center, var(--primary-glow) 0%, transparent 70%);
    opacity: 0.3;
    pointer-events: none;
  }
  
  .logo-img {
    width: 36px;
    height: 36px;
    border-radius: var(--radius-md);
    object-fit: cover;
    transition: all var(--transition-normal);
    position: relative;
    z-index: 1;
    
    &:hover {
      transform: scale(1.1) rotate(5deg);
      filter: drop-shadow(0 0 8px var(--primary-glow));
    }
  }
  
  .logo-text {
    font-size: 18px;
    font-weight: 700;
    color: var(--text-primary);
    white-space: nowrap;
    transition: all var(--transition-normal);
    position: relative;
    z-index: 1;
    
    // 文字渐变效果
    background: linear-gradient(135deg, var(--text-primary) 0%, var(--primary-light) 100%);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
  }
}

// Logo文字过渡动画
.logo-text-enter-active,
.logo-text-leave-active {
  transition: all var(--transition-normal);
}

.logo-text-enter-from,
.logo-text-leave-to {
  opacity: 0;
  transform: translateX(-10px);
}

.sidebar-menu-wrapper {
  flex: 1;
  overflow: hidden;
  padding: 12px 0;
  
  :deep(.el-menu) {
    border-right: none;
    
    .el-menu-item,
    .el-sub-menu__title {
      height: 50px;
      line-height: 50px;
      margin: 4px 12px;
      border-radius: var(--radius-md);
      transition: all var(--transition-fast) cubic-bezier(0.4, 0, 0.2, 1);
      position: relative;
      overflow: hidden;
      
      // 悬停发光效果
      &::before {
        content: '';
        position: absolute;
        inset: 0;
        background: var(--gradient-glow);
        opacity: 0;
        transition: opacity var(--transition-fast);
      }
      
      &:hover {
        background-color: var(--bg-card-hover);
        transform: translateX(4px);
        
        &::before {
          opacity: 1;
        }
        
        .el-icon {
          color: var(--primary-color);
          transform: scale(1.15);
        }
      }
      
      &.is-active {
        background: linear-gradient(90deg, rgba(16, 185, 129, 0.15) 0%, transparent 100%);
        color: var(--primary-color);
        font-weight: 500;
        
        // 激活状态左侧指示条
        &::after {
          content: '';
          position: absolute;
          left: 0;
          top: 50%;
          transform: translateY(-50%);
          width: 3px;
          height: 60%;
          background: var(--gradient-forest);
          border-radius: 0 3px 3px 0;
          box-shadow: 0 0 10px var(--primary-glow);
        }
        
        .el-icon {
          color: var(--primary-color);
          filter: drop-shadow(0 0 4px var(--primary-glow));
        }
      }
      
      .el-icon {
        font-size: 18px;
        margin-right: 12px;
        transition: all var(--transition-fast);
      }
    }
    
    .el-sub-menu .el-menu-item {
      height: 46px;
      line-height: 46px;
      padding-left: 52px !important;
      margin: 2px 12px;
    }
    
    .el-sub-menu__title {
      .el-icon:last-child {
        transition: transform var(--transition-fast);
      }
    }
    
    .el-sub-menu.is-opened > .el-sub-menu__title {
      .el-icon:last-child {
        transform: rotate(180deg);
      }
    }
  }
}

.sidebar-footer {
  padding: 16px;
  text-align: center;
  font-size: 12px;
  color: var(--text-placeholder);
  border-top: 1px solid var(--border-lighter);
  transition: opacity var(--transition-normal);
}
</style>
