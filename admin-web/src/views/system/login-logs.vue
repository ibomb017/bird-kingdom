<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { Refresh } from '@element-plus/icons-vue'
import request from '@/utils/request'

const loading = ref(false)
const logs = ref<any[]>([])

const fetchLogs = async () => {
  loading.value = true
  try {
    const res = await request.get('/system/login-logs', { params: { page: 0, size: 50 } })
    if (res.code === 0) { logs.value = res.data.content }
  } catch (e) { console.error(e) }
  finally { loading.value = false }
}

onMounted(() => { fetchLogs() })
</script>

<template>
  <div class="page-container">
    <div class="page-header"><h2>登录日志</h2><p>管理员登录记录</p></div>
    <el-card class="action-bar"><el-button :icon="Refresh" @click="fetchLogs">刷新</el-button></el-card>
    <el-card class="table-card">
      <el-table :data="logs" v-loading="loading" stripe>
        <el-table-column prop="adminId" label="ID" width="80" />
        <el-table-column prop="username" label="用户名" width="120" />
        <el-table-column prop="nickname" label="昵称" width="150" />
        <el-table-column label="登录时间" min-width="180">
          <template #default="{ row }">{{ new Date(row.loginTime).toLocaleString('zh-CN') }}</template>
        </el-table-column>
        <el-table-column prop="loginIp" label="IP" width="150">
          <template #default="{ row }">{{ row.loginIp || '-' }}</template>
        </el-table-column>
      </el-table>
    </el-card>
  </div>
</template>

<style lang="scss" scoped>
.page-container { padding: 20px; }
.page-header { margin-bottom: 20px; h2 { margin: 0 0 8px; color: var(--text-primary); } p { margin: 0; color: var(--text-secondary); } }
.action-bar { margin-bottom: 20px; }
.table-card { background: var(--bg-card); }
</style>
