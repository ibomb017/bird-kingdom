<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import Sidebar from './components/Sidebar.vue'
import Header from './components/Header.vue'
import { useSettingsStore } from '@/stores/settings'

const route = useRoute()
const settingsStore = useSettingsStore()

const isCollapse = computed(() => settingsStore.isCollapse)
</script>

<template>
  <div class="layout">
    <!-- 侧边栏 -->
    <Sidebar :collapse="isCollapse" />
    
    <!-- 主内容区 -->
    <div class="layout-main" :class="{ 'is-collapse': isCollapse }">
      <!-- 顶部栏 -->
      <Header />
      
      <!-- 内容区 -->
      <main class="layout-content">
        <router-view v-slot="{ Component }">
          <transition name="page-fade" mode="out-in">
            <component :is="Component" :key="route.fullPath" />
          </transition>
        </router-view>
      </main>
      
      <!-- 底部 -->
      <footer class="layout-footer">
        <span>© 2025 Bird Kingdom Admin v1.0.0</span>
      </footer>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.layout {
  display: flex;
  height: 100vh;
  width: 100vw;
  overflow: hidden;
}

.layout-main {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-width: 0;
  transition: margin-left 0.3s ease;
  margin-left: var(--sidebar-width);
  
  &.is-collapse {
    margin-left: var(--sidebar-collapsed-width);
  }
}

.layout-content {
  flex: 1;
  padding: 20px;
  overflow-y: auto;
  background-color: var(--bg-content);
}

.layout-footer {
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  background-color: var(--bg-sidebar);
  color: var(--text-secondary);
  font-size: 12px;
  border-top: 1px solid var(--border-lighter);
}
</style>
