<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { Refresh } from '@element-plus/icons-vue'
import request from '@/utils/request'

const config = ref<any>(null)
const roles = ref<any[]>([])
const loading = ref(true)

const fetchConfig = async () => {
  loading.value = true
  try {
    const [configRes, rolesRes] = await Promise.all([
      request.get('/system/config'),
      request.get('/system/roles')
    ])
    if (configRes.code === 0) config.value = configRes.data
    if (rolesRes.code === 0) roles.value = rolesRes.data
  } catch (e) {
    console.error(e)
  } finally {
    loading.value = false
  }
}

onMounted(() => { fetchConfig() })
</script>

<template>
  <div class="page-container">
    <div class="page-header">
      <h2>系统配置</h2>
      <p>查看系统配置信息</p>
    </div>
    
    <el-row :gutter="20">
      <el-col :span="12">
        <el-card class="config-card" v-loading="loading">
          <template #header>
            <div class="card-header">
              <span>基本配置</span>
              <el-button :icon="Refresh" text @click="fetchConfig">刷新</el-button>
            </div>
          </template>
          <el-descriptions :column="1" border v-if="config">
            <el-descriptions-item label="应用名称">{{ config.appName }}</el-descriptions-item>
            <el-descriptions-item label="版本号">{{ config.version }}</el-descriptions-item>
            <el-descriptions-item label="开屏单价">¥{{ config.splashPrice }}</el-descriptions-item>
            <el-descriptions-item label="每日展位数">{{ config.splashSlotsPerDay }} 个</el-descriptions-item>
            <el-descriptions-item label="月度VIP价格">¥{{ config.vipMonthlyPrice }}</el-descriptions-item>
            <el-descriptions-item label="年度VIP价格">¥{{ config.vipYearlyPrice }}</el-descriptions-item>
          </el-descriptions>
        </el-card>
      </el-col>
      
      <el-col :span="12">
        <el-card class="config-card" v-loading="loading">
          <template #header>
            <span>角色权限</span>
          </template>
          <div class="roles-list">
            <div v-for="role in roles" :key="role.code" class="role-item">
              <div class="role-header">
                <h4>{{ role.name }}</h4>
                <el-tag size="small" type="info">{{ role.code }}</el-tag>
              </div>
              <p class="role-desc">{{ role.description }}</p>
              <div class="permissions">
                <el-tag 
                  v-for="perm in role.permissions" 
                  :key="perm" 
                  size="small" 
                  type="success"
                  style="margin-right: 6px; margin-bottom: 6px;"
                >
                  {{ perm }}
                </el-tag>
              </div>
            </div>
          </div>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<style lang="scss" scoped>
.page-container { padding: 20px; }
.page-header {
  margin-bottom: 20px;
  h2 { margin: 0 0 8px; color: var(--text-primary); }
  p { margin: 0; color: var(--text-secondary); }
}
.config-card {
  background: var(--bg-card);
  .card-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
}
.roles-list {
  .role-item {
    padding: 16px;
    background: var(--bg-card-hover);
    border-radius: 8px;
    margin-bottom: 12px;
    &:last-child { margin-bottom: 0; }
    .role-header {
      display: flex;
      align-items: center;
      gap: 10px;
      margin-bottom: 8px;
      h4 { margin: 0; }
    }
    .role-desc {
      margin: 0 0 10px;
      font-size: 13px;
      color: var(--text-secondary);
    }
  }
}
</style>
