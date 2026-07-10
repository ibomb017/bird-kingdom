<script setup lang="ts">
import { computed } from 'vue'
import { useSettingsStore } from '@/stores/settings'

const settingsStore = useSettingsStore()

const isDark = computed(() => settingsStore.isDark)
</script>

<template>
  <el-config-provider>
    <div :class="{ dark: isDark }">
      <router-view />
    </div>
  </el-config-provider>
</template>

<style>
html.dark {
  --el-bg-color: #141414;
}
</style>
