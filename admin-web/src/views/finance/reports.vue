<script setup lang="ts">
import { ref, onMounted } from 'vue'
import request from '@/utils/request'

const loading = ref(false)
const report = ref<any>({})

const fetchReport = async () => {
  loading.value = true
  try {
    const res = await request.get('/finance/reports')
    if (res.code === 0) { report.value = res.data }
  } catch (e) { console.error(e) }
  finally { loading.value = false }
}

onMounted(() => { fetchReport() })
</script>

<template>
  <div class="page-container">
    <div class="page-header"><h2>财务报表</h2><p>财务数据汇总</p></div>
    <el-row :gutter="20" v-loading="loading">
      <el-col :span="6">
        <el-card class="stat-card">
          <div class="stat-value" style="color: #67C23A;">¥{{ report.splashRevenue || 0 }}</div>
          <div class="stat-label">开屏收入</div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card class="stat-card">
          <div class="stat-value" style="color: #E6A23C;">¥{{ report.estimatedVipRevenue || 0 }}</div>
          <div class="stat-label">预估VIP收入</div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card class="stat-card">
          <div class="stat-value">{{ report.vipUsers || 0 }}</div>
          <div class="stat-label">VIP用户</div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card class="stat-card">
          <div class="stat-value" style="color: #F56C6C;">¥{{ report.userExpenses || 0 }}</div>
          <div class="stat-label">用户总支出</div>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<style lang="scss" scoped>
.page-container { padding: 20px; }
.page-header { margin-bottom: 20px; h2 { margin: 0 0 8px; color: var(--text-primary); } p { margin: 0; color: var(--text-secondary); } }
.stat-card { text-align: center; padding: 30px;
  .stat-value { font-size: 32px; font-weight: 600; }
  .stat-label { margin-top: 10px; color: var(--text-secondary); }
}
</style>
