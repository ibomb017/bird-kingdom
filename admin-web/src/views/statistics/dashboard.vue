<script setup lang="ts">
import { ref, onMounted } from 'vue'
import request from '@/utils/request'

const loading = ref(false)
const stats = ref<any>({})

const fetchStats = async () => {
  loading.value = true
  try {
    const res = await request.get('/stats/dashboard')
    if (res.code === 0) { stats.value = res.data.overview }
  } catch (e) { console.error(e) }
  finally { loading.value = false }
}

onMounted(() => { fetchStats() })
</script>

<template>
  <div class="page-container">
    <div class="page-header"><h2>核心指标</h2><p>平台核心业务指标</p></div>
    <el-row :gutter="20" v-loading="loading">
      <el-col :span="6">
        <el-card class="stat-card"><div class="stat-value">{{ stats.totalUsers || 0 }}</div><div class="stat-label">总用户数</div></el-card>
      </el-col>
      <el-col :span="6">
        <el-card class="stat-card"><div class="stat-value">{{ stats.totalBirds || 0 }}</div><div class="stat-label">总鸟档案</div></el-card>
      </el-col>
      <el-col :span="6">
        <el-card class="stat-card"><div class="stat-value">{{ stats.totalPosts || 0 }}</div><div class="stat-label">总帖子数</div></el-card>
      </el-col>
      <el-col :span="6">
        <el-card class="stat-card"><div class="stat-value" style="color: #E6A23C;">{{ stats.vipUsers || 0 }}</div><div class="stat-label">VIP用户</div></el-card>
      </el-col>
    </el-row>
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
