<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Refresh, Clock, Medal } from '@element-plus/icons-vue'
import request from '@/utils/request'

const loading = ref(false)
const users = ref<any[]>([])
const total = ref(0)
const currentPage = ref(1)
const vipType = ref('')

// 统计数据
const stats = ref({ monthly: 0, yearly: 0, lifetime: 0, total: 0 })

const fetchVipUsers = async () => {
  loading.value = true
  try {
    const params: any = { page: currentPage.value - 1, size: 20 }
    if (vipType.value) params.vipType = vipType.value
    
    const res = await request.get('/users/vip', { params })
    if (res.code === 0) {
      users.value = res.data.content
      total.value = res.data.totalElements
    }
  } catch (e) { console.error(e) }
  finally { loading.value = false }
}

const fetchStats = async () => {
  try {
    const res = await request.get('/stats/dashboard')
    if (res.code === 0 && res.data.overview) {
      stats.value.total = res.data.overview.vipUsers || 0
    }
  } catch (e) { console.error(e) }
}

const handleExtendVip = async (user: any) => {
  try {
    const { value } = await ElMessageBox.prompt('请输入延长天数', '延长VIP', {
      inputPattern: /^[1-9]\d*$/,
      inputErrorMessage: '请输入正整数',
      inputValue: '30'
    })
    if (value) {
      const res = await request.post(`/users/${user.id}/extend-vip`, { days: parseInt(value) })
      if (res.code === 0) {
        ElMessage.success(`VIP已延长至 ${res.data.newExpireDate}`)
        fetchVipUsers()
      } else {
        ElMessage.error(res.message || '操作失败')
      }
    }
  } catch (e) {}
}

const handleRevokeVip = async (user: any) => {
  try {
    await ElMessageBox.confirm(`确定撤销 ${user.nickname} 的VIP吗？此操作不可逆`, '撤销VIP', { type: 'warning' })
    const res = await request.post(`/users/${user.id}/revoke-vip`)
    if (res.code === 0) {
      ElMessage.success('VIP已撤销')
      fetchVipUsers()
    } else {
      ElMessage.error(res.message || '操作失败')
    }
  } catch (e) {}
}

const handlePageChange = (page: number) => { currentPage.value = page; fetchVipUsers() }

const formatDate = (dateStr: string) => dateStr ? new Date(dateStr).toLocaleDateString('zh-CN') : '-'

const getVipTypeLabel = (type: string) => {
  const map: Record<string, string> = { 'MONTHLY': '月度', 'YEARLY': '年度', 'LIFETIME': '永久' }
  return map[type] || type || 'VIP'
}

const isExpired = (expireDate: string) => {
  if (!expireDate) return false
  return new Date(expireDate) < new Date()
}

const getDaysRemaining = (expireDate: string) => {
  if (!expireDate) return 0
  const diff = new Date(expireDate).getTime() - new Date().getTime()
  return Math.max(0, Math.ceil(diff / (1000 * 60 * 60 * 24)))
}

onMounted(() => {
  fetchVipUsers()
  fetchStats()
})
</script>

<template>
  <div class="page-container">
    <div class="page-header">
      <div>
        <h2>
          <el-icon><Medal /></el-icon>
          VIP用户管理
        </h2>
        <p>管理VIP会员，可延长会期或撤销权益</p>
      </div>
      <el-button :icon="Refresh" @click="fetchVipUsers">刷新</el-button>
    </div>
    
    <!-- VIP统计卡片 -->
    <div class="stats-section">
      <div class="stat-card">
        <div class="stat-icon">
          <img src="/vip-icon.png" alt="VIP" class="vip-icon" />
        </div>
        <div class="stat-info">
          <div class="stat-value">{{ stats.total }}</div>
          <div class="stat-label">VIP总数</div>
        </div>
      </div>
    </div>
    
    <el-card class="filter-card">
      <el-radio-group v-model="vipType" @change="currentPage = 1; fetchVipUsers()" class="vip-filter">
        <el-radio-button label="">全部</el-radio-button>
        <el-radio-button label="MONTHLY">月度</el-radio-button>
        <el-radio-button label="YEARLY">年度</el-radio-button>
        <el-radio-button label="LIFETIME">永久</el-radio-button>
      </el-radio-group>
    </el-card>
    
    <el-card class="table-card">
      <el-table :data="users" v-loading="loading" stripe>
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column label="用户信息" min-width="200">
          <template #default="{ row }">
            <div class="user-cell">
              <el-avatar :src="row.avatarUrl" :size="40">{{ row.nickname?.charAt(0) }}</el-avatar>
              <div class="user-detail">
                <span class="nickname">{{ row.nickname }}</span>
                <span class="phone">{{ row.phone }}</span>
              </div>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="VIP类型" width="100">
          <template #default="{ row }">
            <span class="vip-type">{{ getVipTypeLabel(row.vipType) }}</span>
          </template>
        </el-table-column>
        <el-table-column label="到期时间" width="160">
          <template #default="{ row }">
            <div class="expire-info">
              <span :class="['expire-date', { 'is-expired': isExpired(row.vipExpireDate) }]">
                {{ formatDate(row.vipExpireDate) }}
              </span>
              <span v-if="isExpired(row.vipExpireDate)" class="expire-status expired">已过期</span>
              <span v-else-if="row.vipType !== 'LIFETIME'" class="expire-status remaining">
                剩余 {{ getDaysRemaining(row.vipExpireDate) }} 天
              </span>
              <span v-else class="expire-status lifetime">永久有效</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="开通时间" width="110">
          <template #default="{ row }">
            <span class="time-text">{{ formatDate(row.createdAt) }}</span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="140" fixed="right">
          <template #default="{ row }">
            <el-button type="primary" link size="small" @click="handleExtendVip(row)">延长</el-button>
            <el-button type="danger" link size="small" @click="handleRevokeVip(row)">撤销</el-button>
          </template>
        </el-table-column>
      </el-table>
      
      <el-pagination 
        v-model:current-page="currentPage" 
        :page-size="20" 
        :total="total" 
        layout="total, prev, pager, next" 
        @current-change="handlePageChange" 
        class="pagination" 
      />
    </el-card>
  </div>
</template>

<style lang="scss" scoped>
.stats-section {
  margin-bottom: 24px;
}

.stat-card {
  display: inline-flex;
  align-items: center;
  gap: 16px;
  padding: 20px 32px;
  background: var(--gradient-card);
  border: 1px solid var(--border-lighter);
  border-radius: var(--radius-lg);
  transition: all var(--transition-normal);
  
  &:hover {
    border-color: var(--primary-color);
    box-shadow: var(--shadow-glow);
  }
  
  .stat-icon {
    width: 48px;
    height: 48px;
    display: flex;
    align-items: center;
    justify-content: center;
    
    .vip-icon {
      width: 40px;
      height: 40px;
      object-fit: contain;
    }
  }
  
  .stat-info {
    .stat-value {
      font-size: 28px;
      font-weight: 700;
      color: var(--primary-color);
    }
    
    .stat-label {
      font-size: 14px;
      color: var(--text-secondary);
      margin-top: 4px;
    }
  }
}

.filter-card {
  margin-bottom: 24px;
  
  .vip-filter {
    :deep(.el-radio-button__inner) {
      transition: all var(--transition-fast);
    }
    
    :deep(.el-radio-button__original-radio:checked + .el-radio-button__inner) {
      background: var(--gradient-forest);
      border-color: var(--primary-color);
      box-shadow: var(--shadow-glow);
    }
  }
}

.user-cell {
  display: flex;
  align-items: center;
  gap: 12px;
  
  .el-avatar {
    border: 2px solid var(--border-lighter);
    flex-shrink: 0;
  }
  
  .user-detail {
    display: flex;
    flex-direction: column;
    min-width: 0;
    
    .nickname {
      font-weight: 600;
      color: var(--text-primary);
    }
    
    .phone {
      font-size: 12px;
      color: var(--text-secondary);
    }
  }
}

.vip-type {
  font-weight: 500;
  color: var(--primary-color);
}

.expire-info {
  display: flex;
  flex-direction: column;
  gap: 4px;
  
  .expire-date {
    color: var(--text-primary);
    
    &.is-expired {
      color: var(--danger-color);
    }
  }
  
  .expire-status {
    font-size: 11px;
    
    &.remaining {
      color: var(--text-secondary);
    }
    
    &.expired {
      color: var(--danger-color);
    }
    
    &.lifetime {
      color: var(--primary-color);
    }
  }
}

.time-text {
  font-size: 13px;
  color: var(--text-secondary);
}
</style>
