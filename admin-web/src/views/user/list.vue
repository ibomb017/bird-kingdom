<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Search, Refresh, View, User, Clock } from '@element-plus/icons-vue'
import request from '@/utils/request'

const loading = ref(false)
const users = ref<any[]>([])
const total = ref(0)
const currentPage = ref(1)
const pageSize = ref(20)
const keyword = ref('')
const vipStatus = ref('')

// 用户详情弹窗
const detailVisible = ref(false)
const currentUser = ref<any>(null)
const detailLoading = ref(false)

// VIP赠送弹窗
const vipDialogVisible = ref(false)
const vipForm = ref({ vipType: 'MONTHLY', days: 30, reason: '' })
const selectedUsers = ref<any[]>([])
const vipLoading = ref(false)

const fetchUsers = async () => {
  loading.value = true
  try {
    const params: any = { page: currentPage.value - 1, size: pageSize.value }
    if (keyword.value) params.keyword = keyword.value
    if (vipStatus.value) params.vipStatus = vipStatus.value
    
    const res = await request.get('/users', { params })
    if (res.code === 0) {
      users.value = res.data.content
      total.value = res.data.totalElements
    }
  } catch (e) { console.error(e) }
  finally { loading.value = false }
}

const handleSearch = () => { currentPage.value = 1; fetchUsers() }
const handlePageChange = (page: number) => { currentPage.value = page; fetchUsers() }

const showDetail = async (id: number) => {
  detailLoading.value = true
  detailVisible.value = true
  try {
    const res = await request.get(`/users/${id}`)
    if (res.code === 0) {
      currentUser.value = res.data
    }
  } catch (e) { console.error(e) }
  finally { detailLoading.value = false }
}

const showVipDialog = (user?: any) => {
  if (user) {
    selectedUsers.value = [user]
  }
  vipForm.value = { vipType: 'MONTHLY', days: 30, reason: '' }
  vipDialogVisible.value = true
}

const handleVipTypeChange = (type: string) => {
  if (type === 'MONTHLY') {
    vipForm.value.days = 30
  } else if (type === 'YEARLY') {
    vipForm.value.days = 365
  } else if (type === 'LIFETIME') {
    vipForm.value.days = 36500
  }
}

const handleGrantVip = async () => {
  if (selectedUsers.value.length === 0) {
    ElMessage.warning('请选择用户')
    return
  }
  
  vipLoading.value = true
  try {
    if (selectedUsers.value.length === 1) {
      const res = await request.post(`/users/${selectedUsers.value[0].id}/grant-vip`, vipForm.value)
      if (res.code === 0) {
        ElMessage.success('VIP赠送成功')
        vipDialogVisible.value = false
        fetchUsers()
      } else {
        ElMessage.error(res.message)
      }
    } else {
      const res = await request.post('/users/batch-grant-vip', {
        userIds: selectedUsers.value.map(u => u.id),
        ...vipForm.value
      })
      if (res.code === 0) {
        ElMessage.success(`成功赠送 ${res.data.successCount} 个用户`)
        vipDialogVisible.value = false
        fetchUsers()
      }
    }
  } catch (e) { ElMessage.error('操作失败') }
  finally { vipLoading.value = false }
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
        fetchUsers()
      } else {
        ElMessage.error(res.message)
      }
    }
  } catch (e) {}
}

const handleRevokeVip = async (user: any) => {
  try {
    await ElMessageBox.confirm(`确定撤销 ${user.nickname} 的VIP吗？`, '撤销VIP', { type: 'warning' })
    const res = await request.post(`/users/${user.id}/revoke-vip`)
    if (res.code === 0) {
      ElMessage.success('VIP已撤销')
      fetchUsers()
    }
  } catch (e) {}
}

const handleToggleStatus = async (user: any) => {
  const action = user.isDisabled ? '启用' : '禁用'
  try {
    await ElMessageBox.confirm(`确定${action}用户 ${user.nickname} 吗？`, `${action}用户`, { type: 'warning' })
    const res = await request.post(`/users/${user.id}/toggle-status`, { disabled: !user.isDisabled })
    if (res.code === 0) {
      ElMessage.success(`用户已${action}`)
      fetchUsers()
    }
  } catch (e) {}
}

// 情侣 VIP 恢复
const handleRestoreCoupleVip = async (user: any) => {
  try {
    const { value } = await ElMessageBox.prompt(
      `为用户 ${user.nickname} 恢复情侣VIP\n情侣对象ID: ${user.couplePartnerId || '无'}`,
      '恢复情侣VIP',
      {
        confirmButtonText: '恢复永久',
        cancelButtonText: '取消',
        inputPlaceholder: '选择类型: LIFETIME / YEARLY / MONTHLY',
        inputValue: 'LIFETIME'
      }
    )
    
    const vipType = value?.toUpperCase() || 'LIFETIME'
    const res = await request.post('/users/restore-couple-vip', {
      userId: user.id,
      vipType: vipType,
      applyToBoth: true
    })
    
    if (res.code === 0) {
      ElMessage.success(res.message)
      fetchUsers()
    } else {
      ElMessage.error(res.message)
    }
  } catch (e) {}
}

// 取消情侣 VIP
const handleCancelCoupleVip = async (user: any) => {
  try {
    await ElMessageBox.confirm(
      `确定取消 ${user.nickname} 的情侣VIP吗？\n这将同时取消其情侣对象的会员`,
      '取消情侣VIP',
      { type: 'warning' }
    )
    
    const res = await request.post('/users/cancel-couple-vip', {
      userId: user.id,
      applyToBoth: true
    })
    
    if (res.code === 0) {
      ElMessage.success(res.message)
      fetchUsers()
    }
  } catch (e) {}
}

const handleSelectionChange = (selection: any[]) => { selectedUsers.value = selection }

const formatDate = (dateStr: string) => dateStr ? new Date(dateStr).toLocaleDateString('zh-CN') : '-'
const formatDateTime = (dateStr: string) => dateStr ? new Date(dateStr).toLocaleString('zh-CN') : '-'

const getVipTypeLabel = (type: string) => {
  const map: Record<string, string> = { 'MONTHLY': '月度', 'YEARLY': '年度', 'LIFETIME': '永久' }
  return map[type] || type || '-'
}

const getVipDaysLeft = (expireDate: string) => {
  if (!expireDate) return 0
  const days = Math.ceil((new Date(expireDate).getTime() - Date.now()) / (1000 * 60 * 60 * 24))
  return Math.max(0, days)
}

const handleExport = () => {
  window.open(`${import.meta.env.VITE_API_BASE_URL || '/api'}/admin/users/export`)
}

onMounted(() => { fetchUsers() })
</script>

<template>
  <div class="page-container">
    <div class="page-header">
      <div>
        <h2>
          <el-icon><User /></el-icon>
          用户管理
        </h2>
        <p>管理平台用户，可赠送VIP、延长会期、禁用账号</p>
      </div>
      <div style="display: flex; gap: 10px;">
        <el-button 
          @click="handleExport" 
          class="export-btn"
        >
          导出CSV
        </el-button>
        <el-button 
          @click="showVipDialog()" 
          :disabled="selectedUsers.length === 0"
          class="batch-btn"
          :class="{ 'is-active': selectedUsers.length > 0 }"
        >
          批量赠送VIP ({{ selectedUsers.length }})
        </el-button>
      </div>
    </div>
    
    <el-card class="search-card">
      <el-form :inline="true">
        <el-form-item label="关键词">
          <el-input v-model="keyword" placeholder="手机号/昵称" clearable @keyup.enter="handleSearch" style="width: 200px;" />
        </el-form-item>
        <el-form-item label="用户类型">
          <el-select v-model="vipStatus" placeholder="全部" clearable style="width: 140px;">
            <el-option label="全部用户" value="" />
            <el-option label="VIP用户" value="vip" />
            <el-option label="情侣VIP" value="couple" />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button type="primary" :icon="Search" @click="handleSearch">搜索</el-button>
          <el-button :icon="Refresh" @click="keyword = ''; vipStatus = ''; handleSearch()">重置</el-button>
        </el-form-item>
      </el-form>
    </el-card>
    
    <el-card class="table-card">
      <el-table :data="users" v-loading="loading" stripe @selection-change="handleSelectionChange">
        <el-table-column type="selection" width="50" />
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column label="用户信息" min-width="220">
          <template #default="{ row }">
            <div class="user-cell">
              <el-avatar :src="row.avatarUrl" :size="44" class="user-avatar">{{ row.nickname?.charAt(0) }}</el-avatar>
              <div class="user-detail">
                <span class="nickname">{{ row.nickname }}</span>
                <span class="phone">{{ row.phone }}</span>
              </div>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="VIP状态" width="160">
          <template #default="{ row }">
            <div class="vip-badges">
              <!-- 情侣 VIP 标识 - 优先显示 -->
              <span v-if="row.isCoupleVip" class="vip-badge couple">情侣VIP</span>
              <!-- 普通 VIP 标识 - 只有在没有情侣 VIP 时才显示 -->
              <span v-else-if="row.isVip" class="vip-badge">{{ getVipTypeLabel(row.vipType) }}VIP</span>
              <!-- 普通用户 -->
              <span v-else class="status-normal">普通用户</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="情侣绑定" width="120">
          <template #default="{ row }">
            <span v-if="row.couplePartnerId" class="status-couple">ID: {{ row.couplePartnerId }}</span>
            <span v-else class="status-none">-</span>
          </template>
        </el-table-column>
        <el-table-column label="账号状态" width="100">
          <template #default="{ row }">
            <span :class="['status-tag', row.isDisabled ? 'disabled' : 'active']">
              {{ row.isDisabled ? '已禁用' : '正常' }}
            </span>
          </template>
        </el-table-column>
        <el-table-column label="注册时间" width="120">
          <template #default="{ row }">
            <span class="time-text">{{ formatDate(row.createdAt) }}</span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="350" fixed="right">
          <template #default="{ row }">
            <div class="action-buttons">
              <button class="action-btn" @click="showDetail(row.id)">详情</button>
              <button class="action-btn" @click="showVipDialog(row)">赠送VIP</button>
              <button v-if="row.isVip" class="action-btn" @click="handleExtendVip(row)">延长</button>
              <button v-if="row.isVip" class="action-btn" @click="handleRevokeVip(row)">撤销</button>
              <button v-if="row.couplePartnerId" class="action-btn couple" @click="handleRestoreCoupleVip(row)">情侣VIP</button>
              <button v-if="row.isCoupleVip" class="action-btn" @click="handleCancelCoupleVip(row)">取消情侣</button>
              <button class="action-btn danger" @click="handleToggleStatus(row)">
                {{ row.isDisabled ? '启用' : '禁用' }}
              </button>
            </div>
          </template>
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
    
    <!-- 用户详情弹窗 -->
    <el-dialog v-model="detailVisible" title="用户详情" width="550px" class="detail-dialog">
      <div v-loading="detailLoading">
        <template v-if="currentUser">
          <div class="detail-header">
            <el-avatar :src="currentUser.avatarUrl" :size="72" class="detail-avatar">{{ currentUser.nickname?.charAt(0) }}</el-avatar>
            <div class="detail-info">
              <h3>{{ currentUser.nickname }}</h3>
              <span v-if="currentUser.isVip" class="detail-vip">{{ getVipTypeLabel(currentUser.vipType) }} VIP</span>
            </div>
          </div>
          
          <el-descriptions :column="2" border class="detail-descriptions">
            <el-descriptions-item label="用户ID">{{ currentUser.id }}</el-descriptions-item>
            <el-descriptions-item label="手机号">{{ currentUser.phone }}</el-descriptions-item>
            <el-descriptions-item label="个性签名" :span="2">{{ currentUser.bio || '暂无签名' }}</el-descriptions-item>
            <el-descriptions-item label="鸟儿数量">{{ currentUser.birdCount || 0 }} 只</el-descriptions-item>
            <el-descriptions-item label="发帖数量">{{ currentUser.postCount || 0 }} 篇</el-descriptions-item>
            <el-descriptions-item label="VIP到期">
              <span v-if="currentUser.vipExpireDate">
                {{ formatDate(currentUser.vipExpireDate) }}
                <span class="days-left">({{ getVipDaysLeft(currentUser.vipExpireDate) }}天后)</span>
              </span>
              <span v-else>-</span>
            </el-descriptions-item>
            <el-descriptions-item label="注册时间">{{ formatDateTime(currentUser.createdAt) }}</el-descriptions-item>
          </el-descriptions>
        </template>
      </div>
      <template #footer>
        <el-button @click="detailVisible = false">关闭</el-button>
        <el-button type="primary" @click="showVipDialog(currentUser); detailVisible = false" v-if="currentUser">赠送VIP</el-button>
      </template>
    </el-dialog>
    
    <!-- VIP赠送弹窗 -->
    <el-dialog v-model="vipDialogVisible" title="赠送VIP" width="480px" class="vip-dialog">
      <div class="vip-target" v-if="selectedUsers.length > 0">
        <span class="target-label">赠送对象：</span>
        <div class="target-users">
          <span v-for="u in selectedUsers.slice(0, 5)" :key="u.id" class="target-name">{{ u.nickname }}</span>
          <span v-if="selectedUsers.length > 5" class="more-count">等 {{ selectedUsers.length }} 人</span>
        </div>
      </div>
      
      <el-form :model="vipForm" label-width="110px" class="vip-form">
        <el-form-item label="VIP类型">
          <el-radio-group v-model="vipForm.vipType" @change="handleVipTypeChange" class="vip-type-group">
            <el-radio-button label="MONTHLY">月度 (30天)</el-radio-button>
            <el-radio-button label="YEARLY">年度 (365天)</el-radio-button>
            <el-radio-button label="LIFETIME">永久</el-radio-button>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="自定义天数" v-if="vipForm.vipType !== 'LIFETIME'">
          <el-input-number v-model="vipForm.days" :min="1" :max="3650" />
          <span class="days-hint">天</span>
        </el-form-item>
        <el-form-item label="操作原因">
          <el-input v-model="vipForm.reason" type="textarea" :rows="2" placeholder="如：活动赠送、售后补偿等" />
        </el-form-item>
      </el-form>
      
      <template #footer>
        <el-button @click="vipDialogVisible = false">取消</el-button>
        <el-button type="primary" @click="handleGrantVip" :loading="vipLoading">确认赠送</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style lang="scss" scoped>
.page-container { padding: 28px; }

// 批量操作按钮 - 禁用时灰色，激活时主色
.batch-btn {
  padding: 10px 20px;
  border-radius: var(--radius-md);
  font-weight: 500;
  transition: all var(--transition-normal) cubic-bezier(0.4, 0, 0.2, 1);
  background: var(--bg-card);
  border: 1px solid var(--border-base);
  color: var(--text-disabled);
  cursor: not-allowed;
  
  &.is-active {
    background: var(--gradient-forest);
    border-color: var(--primary-color);
    color: white;
    cursor: pointer;
    box-shadow: var(--shadow-glow);
    
    &:hover {
      transform: translateY(-3px);
      box-shadow: var(--shadow-glow-lg);
    }
    
    &:active {
      transform: translateY(-1px);
    }
  }
}

.export-btn {
  padding: 10px 20px;
  border-radius: var(--radius-md);
  font-weight: 500;
  transition: all var(--transition-normal) cubic-bezier(0.4, 0, 0.2, 1);
  background: white;
  border: 1px solid var(--primary-color);
  color: var(--primary-color);
  cursor: pointer;
  
  &:hover {
    background: var(--primary-subtle);
    transform: translateY(-1px);
    box-shadow: var(--shadow-sm);
  }
}

.user-cell {
  display: flex;
  align-items: center;
  gap: 14px;
  
  .user-avatar {
    border: 2px solid var(--border-lighter);
    transition: all var(--transition-fast);
    
    &:hover {
      border-color: var(--primary-color);
      box-shadow: var(--shadow-glow);
      transform: scale(1.05);
    }
  }
  
  .user-detail {
    display: flex;
    flex-direction: column;
    
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

// VIP状态 - 统一使用主色调
.vip-status {
  display: flex;
  flex-direction: column;
  gap: 4px;
  
  .vip-label {
    font-weight: 600;
    color: var(--primary-color);
    font-size: 13px;
  }
  
  .vip-expire {
    font-size: 11px;
    color: var(--text-secondary);
  }
}

// VIP 徽章样式 - 统一绿色主题
.vip-badges {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  
  .vip-badge {
    display: inline-block;
    padding: 3px 10px;
    border-radius: 12px;
    font-size: 11px;
    font-weight: 500;
    background: var(--primary-subtle);
    color: var(--primary-color);
    
    // 情侣 VIP - 粉色
    &.couple {
      background: rgba(236, 72, 153, 0.15);
      color: #EC4899;
    }
  }
}

.status-normal, .status-none {
  color: var(--text-secondary);
  font-size: 13px;
}

.status-couple {
  color: var(--primary-color);
  font-size: 13px;
}

// 状态标签 - 仅用灰色和主色
.status-tag {
  display: inline-block;
  padding: 4px 10px;
  border-radius: 20px;
  font-size: 12px;
  
  &.active {
    background: var(--primary-subtle);
    color: var(--primary-color);
  }
  
  &.disabled {
    background: var(--bg-card);
    color: var(--text-disabled);
  }
}

.time-text {
  font-size: 13px;
  color: var(--text-secondary);
}

// 操作按钮 - 极简风格，悬停发光
.action-buttons {
  display: flex;
  gap: 6px;
  
  .action-btn {
    background: transparent;
    border: none;
    color: var(--text-secondary);
    font-size: 13px;
    padding: 6px 10px;
    border-radius: var(--radius-sm);
    cursor: pointer;
    transition: all var(--transition-fast) cubic-bezier(0.4, 0, 0.2, 1);
    position: relative;
    overflow: hidden;
    
    &::before {
      content: '';
      position: absolute;
      inset: 0;
      background: var(--gradient-glow);
      opacity: 0;
      transition: opacity var(--transition-fast);
    }
    
    &:hover {
      color: var(--primary-color);
      transform: translateY(-2px);
      
      &::before {
        opacity: 1;
      }
    }
    
    &:active {
      transform: translateY(0);
    }
    
    &.danger:hover {
      color: var(--danger-color);
    }
    
    &.couple {
      color: #EC4899;
      
      &:hover {
        color: #F472B6;
        background: rgba(236, 72, 153, 0.1);
      }
    }
  }
}

// 详情弹窗
.detail-header {
  display: flex;
  align-items: center;
  gap: 20px;
  padding-bottom: 24px;
  border-bottom: 1px solid var(--border-lighter);
  margin-bottom: 24px;
  
  .detail-avatar {
    border: 2px solid var(--border-lighter);
  }
  
  .detail-info {
    h3 {
      margin: 0 0 8px;
      font-size: 20px;
      color: var(--text-primary);
    }
    
    .detail-vip {
      display: inline-block;
      padding: 4px 12px;
      background: var(--primary-subtle);
      color: var(--primary-color);
      border-radius: 20px;
      font-size: 12px;
      font-weight: 500;
    }
  }
}

.days-left {
  color: var(--text-secondary);
  font-size: 12px;
}

// VIP弹窗
.vip-target {
  padding: 16px;
  background: var(--bg-card-hover);
  border-radius: var(--radius-md);
  margin-bottom: 24px;
  
  .target-label {
    font-size: 13px;
    color: var(--text-secondary);
  }
  
  .target-users {
    display: inline;
  }
  
  .target-name {
    display: inline-block;
    padding: 2px 10px;
    background: var(--primary-subtle);
    color: var(--primary-color);
    border-radius: 20px;
    font-size: 12px;
    margin: 4px 4px 0 0;
  }
  
  .more-count {
    font-size: 12px;
    color: var(--text-secondary);
  }
}

.vip-form {
  .days-hint {
    margin-left: 10px;
    color: var(--text-secondary);
  }
}

.vip-type-group {
  :deep(.el-radio-button__inner) {
    transition: all var(--transition-fast);
  }
  
  :deep(.el-radio-button__original-radio:checked + .el-radio-button__inner) {
    background: var(--gradient-forest);
    border-color: var(--primary-color);
    box-shadow: var(--shadow-glow);
  }
}
</style>
