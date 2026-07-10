<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { Refresh, View } from '@element-plus/icons-vue'
import request from '@/utils/request'

const loading = ref(false)
const admins = ref<any[]>([])
const total = ref(0)
const currentPage = ref(1)
const pageSize = ref(20)
const detailVisible = ref(false)
const currentDetail = ref<any>(null)

const fetchAdmins = async () => {
  loading.value = true
  try {
    const res = await request.get('/system/admins', {
      params: { page: currentPage.value - 1, size: pageSize.value }
    })
    if (res.code === 0) {
      admins.value = res.data.content
      total.value = res.data.totalElements
    }
  } catch (e) {
    console.error(e)
  } finally {
    loading.value = false
  }
}

const showDetail = async (id: number) => {
  try {
    const res = await request.get(`/system/admins/${id}`)
    if (res.code === 0) {
      currentDetail.value = res.data
      detailVisible.value = true
    }
  } catch (e) {
    console.error(e)
  }
}

const handlePageChange = (page: number) => {
  currentPage.value = page
  fetchAdmins()
}

const formatDate = (dateStr: string) => {
  if (!dateStr) return '-'
  return new Date(dateStr).toLocaleString('zh-CN')
}

const getRoleLabel = (role: string) => {
  const map: Record<string, string> = {
    'SUPER_ADMIN': '超级管理员',
    'ADMIN': '管理员',
    'REVIEWER': '审核员'
  }
  return map[role] || role
}

const getRoleType = (role: string): '' | 'success' | 'warning' | 'info' | 'danger' => {
  const map: Record<string, '' | 'success' | 'warning' | 'info' | 'danger'> = {
    'SUPER_ADMIN': 'danger',
    'ADMIN': 'warning',
    'REVIEWER': 'info'
  }
  return map[role] || 'info'
}

onMounted(() => { fetchAdmins() })
</script>

<template>
  <div class="page-container">
    <div class="page-header">
      <h2>管理员列表</h2>
      <p>查看系统管理员账号</p>
    </div>
    
    <el-card class="action-bar">
      <el-button :icon="Refresh" @click="fetchAdmins">刷新</el-button>
    </el-card>
    
    <el-card class="table-card">
      <el-table :data="admins" v-loading="loading" stripe>
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column label="管理员" min-width="180">
          <template #default="{ row }">
            <div class="admin-info">
              <el-avatar :src="row.avatar" :size="40">{{ row.nickname?.charAt(0) || row.username?.charAt(0) }}</el-avatar>
              <div class="admin-detail">
                <span class="nickname">{{ row.nickname || row.username }}</span>
                <span class="username">@{{ row.username }}</span>
              </div>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="角色" width="120">
          <template #default="{ row }">
            <el-tag :type="getRoleType(row.roleCode)" size="small">{{ getRoleLabel(row.roleCode) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="100">
          <template #default="{ row }">
            <el-tag :type="row.status === 1 ? 'success' : 'danger'" size="small">
              {{ row.status === 1 ? '正常' : '禁用' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="最后登录" width="170">
          <template #default="{ row }">{{ formatDate(row.lastLoginAt) }}</template>
        </el-table-column>
        <el-table-column label="创建时间" width="170">
          <template #default="{ row }">{{ formatDate(row.createdAt) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="100" fixed="right">
          <template #default="{ row }">
            <el-button type="primary" link :icon="View" @click="showDetail(row.id)">详情</el-button>
          </template>
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
    
    <!-- 详情弹窗 -->
    <el-dialog v-model="detailVisible" title="管理员详情" width="500px" v-if="currentDetail">
      <div class="admin-detail-card">
        <el-avatar :src="currentDetail.avatar" :size="80">{{ currentDetail.nickname?.charAt(0) }}</el-avatar>
        <h3>{{ currentDetail.nickname }}</h3>
        <el-tag :type="getRoleType(currentDetail.roleCode)">{{ getRoleLabel(currentDetail.roleCode) }}</el-tag>
      </div>
      <el-descriptions :column="1" border style="margin-top: 20px;">
        <el-descriptions-item label="用户名">{{ currentDetail.username }}</el-descriptions-item>
        <el-descriptions-item label="手机号">{{ currentDetail.phone || '-' }}</el-descriptions-item>
        <el-descriptions-item label="邮箱">{{ currentDetail.email || '-' }}</el-descriptions-item>
        <el-descriptions-item label="状态">
          <el-tag :type="currentDetail.status === 1 ? 'success' : 'danger'" size="small">
            {{ currentDetail.status === 1 ? '正常' : '禁用' }}
          </el-tag>
        </el-descriptions-item>
        <el-descriptions-item label="最后登录">{{ formatDate(currentDetail.lastLoginAt) }}</el-descriptions-item>
        <el-descriptions-item label="创建时间">{{ formatDate(currentDetail.createdAt) }}</el-descriptions-item>
      </el-descriptions>
    </el-dialog>
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
.admin-info {
  display: flex;
  align-items: center;
  gap: 12px;
  .admin-detail {
    display: flex;
    flex-direction: column;
    .nickname { font-weight: 500; }
    .username { font-size: 12px; color: var(--text-secondary); }
  }
}
.pagination { margin-top: 20px; justify-content: flex-end; }
.admin-detail-card {
  text-align: center;
  padding: 20px 0;
  h3 { margin: 12px 0 8px; }
}
</style>
