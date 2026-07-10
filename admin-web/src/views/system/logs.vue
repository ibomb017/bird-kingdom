<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { Refresh } from '@element-plus/icons-vue'
import request from '@/utils/request'

const loading = ref(false)
const logs = ref<any[]>([])
const total = ref(0)
const currentPage = ref(1)
const pageSize = ref(20)

const fetchLogs = async () => {
  loading.value = true
  try {
    const res = await request.get('/system/login-logs', {
      params: { page: currentPage.value - 1, size: pageSize.value }
    })
    if (res.code === 0) {
      logs.value = res.data.content
      total.value = res.data.totalElements
    }
  } catch (e) {
    console.error(e)
  } finally {
    loading.value = false
  }
}

const handlePageChange = (page: number) => {
  currentPage.value = page
  fetchLogs()
}

const formatDate = (dateStr: string) => {
  if (!dateStr) return '-'
  return new Date(dateStr).toLocaleString('zh-CN')
}

onMounted(() => { fetchLogs() })
</script>

<template>
  <div class="page-container">
    <div class="page-header">
      <h2>登录日志</h2>
      <p>查看管理员登录记录</p>
    </div>
    
    <el-card class="action-bar">
      <el-button :icon="Refresh" @click="fetchLogs">刷新</el-button>
    </el-card>
    
    <el-card class="table-card">
      <el-table :data="logs" v-loading="loading" stripe>
        <el-table-column prop="adminId" label="管理员ID" width="100" />
        <el-table-column prop="username" label="用户名" width="120" />
        <el-table-column prop="nickname" label="昵称" width="150" />
        <el-table-column label="登录时间" min-width="180">
          <template #default="{ row }">{{ formatDate(row.loginTime) }}</template>
        </el-table-column>
        <el-table-column prop="loginIp" label="登录IP" width="150">
          <template #default="{ row }">{{ row.loginIp || '-' }}</template>
        </el-table-column>
      </el-table>
      
      <el-pagination
        v-if="total > pageSize"
        v-model:current-page="currentPage"
        :page-size="pageSize"
        :total="total"
        layout="total, prev, pager, next"
        @current-change="handlePageChange"
        class="pagination"
      />
    </el-card>
  </div>
</template>

<style lang="scss" scoped>
.page-container { padding: 20px; }
.page-header {
  margin-bottom: 20px;
  h2 { margin: 0 0 8px; color: var(--text-primary); }
  p { margin: 0; color: var(--text-secondary); }
}
.action-bar { margin-bottom: 20px; }
.table-card { background: var(--bg-card); }
.pagination { margin-top: 20px; justify-content: flex-end; }
</style>
