<script setup lang="ts">
import { ref, onMounted } from 'vue'
import request from '@/utils/request'

const loading = ref(false)
const stats = ref<any>({})

const fetchStats = async () => {
  loading.value = true
  try {
    const res = await request.get('/finance/vip-income')
    if (res.code === 0) { stats.value = res.data }
  } catch (e) { console.error(e) }
  finally { loading.value = false }
}

onMounted(() => { fetchStats() })
</script>

<template>
  <div class="page-container">
    <div class="page-header"><h2>VIP收入</h2><p>VIP会员收入统计</p></div>
    <el-row :gutter="20" v-loading="loading">
      <el-col :span="8">
        <el-card class="stat-card">
          <div class="stat-value">{{ stats.totalVipUsers || 0 }}</div>
          <div class="stat-label">VIP用户总数</div>
        </el-card>
      </el-col>
      <el-col :span="8">
        <el-card class="stat-card">
          <div class="stat-value" style="color: #E6A23C;">¥{{ stats.estimatedRevenue || 0 }}</div>
          <div class="stat-label">预估总收入</div>
        </el-card>
      </el-col>
    </el-row>
    <el-card style="margin-top: 20px;"><el-empty description="详细VIP订单需要对接Apple IAP记录" /></el-card>
  </div>
</template>

<style lang="scss" scoped>
.page-container { padding: 20px; }
.page-header { margin-bottom: 20px; h2 { margin: 0 0 8px; color: var(--text-primary); } p { margin: 0; color: var(--text-secondary); } }
.stat-card { text-align: center; padding: 30px;
  .stat-value { font-size: 36px; font-weight: 600; }
  .stat-label { margin-top: 10px; color: var(--text-secondary); }
}
</style>
