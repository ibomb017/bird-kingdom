<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { Search, Refresh } from '@element-plus/icons-vue'
import request from '@/utils/request'

const loading = ref(false)
const orders = ref<any[]>([])
const total = ref(0)
const currentPage = ref(1)
const pageSize = ref(20)
const status = ref('')

const fetchOrders = async () => {
  loading.value = true
  try {
    const params: any = { page: currentPage.value - 1, size: pageSize.value }
    if (status.value) params.status = status.value
    
    const res = await request.get('/finance/splash-orders', { params })
    if (res.code === 0) {
      orders.value = res.data.content
      total.value = res.data.totalElements
    }
  } catch (e) {
    console.error(e)
  } finally {
    loading.value = false
  }
}

const handleSearch = () => {
  currentPage.value = 1
  fetchOrders()
}

const handlePageChange = (page: number) => {
  currentPage.value = page
  fetchOrders()
}

const formatDate = (dateStr: string) => {
  if (!dateStr) return '-'
  return new Date(dateStr).toLocaleString('zh-CN')
}

const getStatusTag = (s: string) => {
  const map: Record<string, { label: string, type: '' | 'success' | 'warning' | 'info' | 'danger' }> = {
    'PAID': { label: '已支付', type: 'success' },
    'PENDING': { label: '待支付', type: 'warning' },
    'CANCELLED': { label: '已取消', type: 'info' },
    'REFUNDED': { label: '已退款', type: 'danger' },
    'EXPIRED': { label: '已过期', type: 'info' }
  }
  return map[s] || { label: s, type: 'info' }
}

onMounted(() => { fetchOrders() })
</script>

<template>
  <div class="page-container">
    <div class="page-header">
      <h2>开屏订单</h2>
      <p>查看开屏庆生订单记录</p>
    </div>
    
    <el-card class="search-card">
      <el-form :inline="true">
        <el-form-item label="状态">
          <el-select v-model="status" placeholder="全部" clearable>
            <el-option label="已支付" value="PAID" />
            <el-option label="待支付" value="PENDING" />
            <el-option label="已取消" value="CANCELLED" />
            <el-option label="已退款" value="REFUNDED" />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button type="primary" :icon="Search" @click="handleSearch">搜索</el-button>
          <el-button :icon="Refresh" @click="status = ''; handleSearch()">重置</el-button>
        </el-form-item>
      </el-form>
    </el-card>
    
    <el-card class="table-card">
      <el-table :data="orders" v-loading="loading" stripe>
        <el-table-column prop="id" label="订单ID" width="100" />
        <el-table-column label="用户" width="150">
          <template #default="{ row }">{{ row.userNickname || '未知' }}</template>
        </el-table-column>
        <el-table-column label="展示日期" width="120">
          <template #default="{ row }">{{ row.displayDate }}</template>
        </el-table-column>
        <el-table-column label="金额" width="100">
          <template #default="{ row }">
            <span class="amount">¥{{ row.amount }}</span>
          </template>
        </el-table-column>
        <el-table-column label="支付方式" width="100">
          <template #default="{ row }">{{ row.paymentMethod || '-' }}</template>
        </el-table-column>
        <el-table-column label="状态" width="100">
          <template #default="{ row }">
            <el-tag :type="getStatusTag(row.status).type" size="small">
              {{ getStatusTag(row.status).label }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="支付时间" width="170">
          <template #default="{ row }">{{ formatDate(row.paidAt) }}</template>
        </el-table-column>
        <el-table-column label="创建时间" width="170">
          <template #default="{ row }">{{ formatDate(row.createdAt) }}</template>
        </el-table-column>
      </el-table>
      
      <el-pagination
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
.search-card { margin-bottom: 20px; }
.table-card { background: var(--bg-card); }
.amount { color: #E6A23C; font-weight: 500; }
.pagination { margin-top: 20px; justify-content: flex-end; }
</style>
