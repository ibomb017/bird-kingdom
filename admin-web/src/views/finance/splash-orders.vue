<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { Refresh } from '@element-plus/icons-vue'
import request from '@/utils/request'

const loading = ref(false)
const orders = ref<any[]>([])
const total = ref(0)

const fetchOrders = async () => {
  loading.value = true
  try {
    const res = await request.get('/finance/splash-orders', { params: { page: 0, size: 50 } })
    if (res.code === 0) {
      orders.value = res.data.content
      total.value = res.data.totalElements
    }
  } catch (e) { console.error(e) }
  finally { loading.value = false }
}

const getStatusTag = (s: string) => {
  const map: Record<string, { label: string, type: '' | 'success' | 'warning' | 'info' | 'danger' }> = {
    'PAID': { label: '已支付', type: 'success' },
    'PENDING': { label: '待支付', type: 'warning' },
    'CANCELLED': { label: '已取消', type: 'info' }
  }
  return map[s] || { label: s, type: 'info' }
}

onMounted(() => { fetchOrders() })
</script>

<template>
  <div class="page-container">
    <div class="page-header"><h2>开屏订单</h2><p>查看开屏庆生订单</p></div>
    <el-card class="action-bar"><el-button :icon="Refresh" @click="fetchOrders">刷新</el-button></el-card>
    <el-card class="table-card">
      <el-table :data="orders" v-loading="loading" stripe>
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column prop="userNickname" label="用户" width="120" />
        <el-table-column prop="displayDate" label="展示日期" width="120" />
        <el-table-column label="金额" width="100">
          <template #default="{ row }"><span style="color: #E6A23C;">¥{{ row.amount }}</span></template>
        </el-table-column>
        <el-table-column label="状态" width="100">
          <template #default="{ row }"><el-tag :type="getStatusTag(row.status).type" size="small">{{ getStatusTag(row.status).label }}</el-tag></template>
        </el-table-column>
        <el-table-column label="支付时间" width="170">
          <template #default="{ row }">{{ row.paidAt ? new Date(row.paidAt).toLocaleString('zh-CN') : '-' }}</template>
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
