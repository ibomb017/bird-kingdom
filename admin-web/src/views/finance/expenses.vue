<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { Search, Refresh } from '@element-plus/icons-vue'
import request from '@/utils/request'

const loading = ref(false)
const expenses = ref<any[]>([])
const total = ref(0)
const currentPage = ref(1)

const fetchExpenses = async () => {
  loading.value = true
  try {
    const res = await request.get('/finance/expenses', { params: { page: currentPage.value - 1, size: 20 } })
    if (res.code === 0) {
      expenses.value = res.data.content
      total.value = res.data.totalElements
    }
  } catch (e) { console.error(e) }
  finally { loading.value = false }
}

onMounted(() => { fetchExpenses() })
</script>

<template>
  <div class="page-container">
    <div class="page-header"><h2>支出记录</h2><p>查看用户支出记录统计</p></div>
    <el-card class="action-bar"><el-button :icon="Refresh" @click="fetchExpenses">刷新</el-button></el-card>
    <el-card class="table-card">
      <el-table :data="expenses" v-loading="loading" stripe>
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column prop="userNickname" label="用户" width="120" />
        <el-table-column prop="title" label="标题" min-width="150" />
        <el-table-column label="金额" width="100">
          <template #default="{ row }"><span style="color: #E6A23C; font-weight: 500;">¥{{ row.amount }}</span></template>
        </el-table-column>
        <el-table-column prop="category" label="分类" width="100" />
        <el-table-column prop="birdName" label="关联鸟儿" width="120" />
        <el-table-column label="日期" width="120">
          <template #default="{ row }">{{ row.expenseDate }}</template>
        </el-table-column>
      </el-table>
      <el-pagination v-if="total > 20" v-model:current-page="currentPage" :page-size="20" :total="total" layout="total, prev, pager, next" @current-change="fetchExpenses" style="margin-top: 20px; justify-content: flex-end;" />
    </el-card>
  </div>
</template>

<style lang="scss" scoped>
.page-container { padding: 20px; }
.page-header { margin-bottom: 20px; h2 { margin: 0 0 8px; color: var(--text-primary); } p { margin: 0; color: var(--text-secondary); } }
.action-bar { margin-bottom: 20px; }
.table-card { background: var(--bg-card); }
</style>
