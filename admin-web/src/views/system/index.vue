<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { Refresh, User, Setting, Tickets, Lock } from '@element-plus/icons-vue'
import request from '@/utils/request'

const activeTab = ref('admins')
const loading = ref(false)

// 管理员数据
const admins = ref<any[]>([])
const adminTotal = ref(0)

// 角色数据
const roles = ref<any[]>([])

// 配置数据
const config = ref<any>({})

// 登录日志
const loginLogs = ref<any[]>([])

// 管理员编辑对话框
const adminDialogVisible = ref(false)
const adminDialogTitle = ref('新增管理员')
const adminForm = ref({
  id: null,
  username: '',
  password: '',
  nickname: '',
  email: '',
  phone: '',
  roleCode: 'ADMIN',
  status: 'ACTIVE'
})

const resetAdminForm = () => {
  adminForm.value = {
    id: null,
    username: '',
    password: '',
    nickname: '',
    email: '',
    phone: '',
    roleCode: 'ADMIN',
    status: 'ACTIVE'
  }
}

const showAddDialog = () => {
  resetAdminForm()
  adminDialogTitle.value = '新增管理员'
  adminDialogVisible.value = true
}

const showEditDialog = (admin: any) => {
  adminForm.value = {
    id: admin.id,
    username: admin.username,
    password: '',
    nickname: admin.nickname,
    email: admin.email,
    phone: admin.phone,
    roleCode: admin.roleCode,
    status: admin.status === 1 ? 'ACTIVE' : 'INACTIVE'
  }
  adminDialogTitle.value = '编辑管理员'
  adminDialogVisible.value = true
}

const saveAdmin = async () => {
  try {
    const data = { ...adminForm.value }
    if (adminForm.value.id) {
      // 编辑
      await request.put(`/system/admins/${adminForm.value.id}`, data)
    } else {
      // 新增
      await request.post('/system/admins', data)
    }
    adminDialogVisible.value = false
    fetchAdmins()
  } catch (e) {
    console.error(e)
  }
}

const deleteAdmin = async (id: number) => {
  try {
    await request.delete(`/system/admins/${id}`)
    fetchAdmins()
  } catch (e) {
    console.error(e)
  }
}

const fetchAdmins = async () => {
  loading.value = true
  try {
    const res = await request.get('/system/admins', { params: { page: 0, size: 50 } })
    if (res.code === 0) {
      admins.value = res.data.content
      adminTotal.value = res.data.totalElements
    }
  } catch (e) { console.error(e) }
  finally { loading.value = false }
}

const fetchRoles = async () => {
  try {
    const res = await request.get('/system/roles')
    if (res.code === 0) { roles.value = res.data }
  } catch (e) { console.error(e) }
}

const fetchConfig = async () => {
  try {
    const res = await request.get('/system/config')
    if (res.code === 0) { config.value = res.data }
  } catch (e) { console.error(e) }
}

const fetchLoginLogs = async () => {
  try {
    const res = await request.get('/system/login-logs', { params: { page: 0, size: 50 } })
    if (res.code === 0) { loginLogs.value = res.data.content }
  } catch (e) { console.error(e) }
}

const handleTabChange = (tab: string) => {
  if (tab === 'admins') fetchAdmins()
  else if (tab === 'roles') fetchRoles()
  else if (tab === 'config') fetchConfig()
  else if (tab === 'logs') fetchLoginLogs()
}

const formatDate = (dateStr: string) => dateStr ? new Date(dateStr).toLocaleString('zh-CN') : '-'

const getRoleLabel = (role: string) => {
  const map: Record<string, string> = { 'SUPER_ADMIN': '超级管理员', 'ADMIN': '管理员', 'REVIEWER': '审核员' }
  return map[role] || role
}

const getRoleType = (role: string): '' | 'success' | 'warning' | 'info' | 'danger' => {
  const map: Record<string, '' | 'success' | 'warning' | 'info' | 'danger'> = { 'SUPER_ADMIN': 'danger', 'ADMIN': 'warning', 'REVIEWER': 'info' }
  return map[role] || 'info'
}

onMounted(() => {
  fetchAdmins()
  fetchRoles()
  fetchConfig()
  fetchLoginLogs()
})
</script>

<template>
  <div class="page-container">
    <div class="page-header">
      <h2><el-icon><Setting /></el-icon> 系统配置</h2>
      <p>管理管理员账号、角色权限、系统参数</p>
    </div>
    
    <el-card class="main-card">
      <el-tabs v-model="activeTab" @tab-change="handleTabChange">
        <!-- 管理员列表 -->
        <el-tab-pane label="管理员" name="admins">
          <template #label><el-icon><User /></el-icon> 管理员</template>
          <div style="margin-bottom: 16px">
            <el-button class="add-btn" @click="showAddDialog">新增管理员</el-button>
          </div>
          <el-table :data="admins" v-loading="loading" stripe>
            <el-table-column prop="id" label="ID" width="80" />
            <el-table-column label="管理员" min-width="200">
              <template #default="{ row }">
                <div class="admin-info-text">
                  <span class="nickname">{{ row.nickname || row.username }}</span>
                  <span class="username">@{{ row.username }}</span>
                </div>
              </template>
            </el-table-column>
            <el-table-column label="角色" width="120">
              <template #default="{ row }">
                <el-tag class="role-tag-admin" size="small">{{ getRoleLabel(row.roleCode) }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column label="状态" width="100">
              <template #default="{ row }">
                <el-tag :type="row.status === 1 ? 'success' : 'danger'" size="small">{{ row.status === 1 ? '正常' : '禁用' }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column label="最后登录" width="170">
              <template #default="{ row }">{{ formatDate(row.lastLoginAt) }}</template>
            </el-table-column>
            <el-table-column label="操作" width="180" fixed="right">
              <template #default="{ row }">
                <el-button type="primary" link size="small" @click="showEditDialog(row)">编辑</el-button>
                <el-button type="danger" link size="small" @click="deleteAdmin(row.id)">删除</el-button>
              </template>
            </el-table-column>
          </el-table>
        </el-tab-pane>
        
        <!-- 角色权限 -->
        <el-tab-pane label="角色权限" name="roles">
          <template #label><el-icon><Lock /></el-icon> 角色权限</template>
          <div class="roles-grid">
            <el-card v-for="role in roles" :key="role.code" class="role-card">
              <div class="role-header">
                <h4>{{ role.name }}</h4>
                <el-tag size="small" class="role-code-tag">{{ role.code }}</el-tag>
              </div>
              <p class="role-desc">{{ role.description }}</p>
              <div class="permissions">
                <el-tag v-for="perm in role.permissions" :key="perm" size="small" class="permission-tag" style="margin: 3px;">{{ perm }}</el-tag>
              </div>
            </el-card>
          </div>
        </el-tab-pane>
        
        <!-- 系统配置 -->
        <el-tab-pane label="系统参数" name="config">
          <template #label><el-icon><Setting /></el-icon> 系统参数</template>
          <el-descriptions :column="2" border v-if="config.appName">
            <el-descriptions-item label="应用名称">{{ config.appName }}</el-descriptions-item>
            <el-descriptions-item label="版本号">{{ config.version }}</el-descriptions-item>
            <el-descriptions-item label="开屏单价">¥{{ config.splashPrice }}</el-descriptions-item>
            <el-descriptions-item label="每日展位数">{{ config.splashSlotsPerDay }} 个</el-descriptions-item>
            <el-descriptions-item label="月度VIP价格">¥{{ config.vipMonthlyPrice }}</el-descriptions-item>
            <el-descriptions-item label="年度VIP价格">¥{{ config.vipYearlyPrice }}</el-descriptions-item>
          </el-descriptions>
          <el-empty v-else description="暂无配置数据" />
        </el-tab-pane>
        
        <!-- 登录日志 -->
        <el-tab-pane label="登录日志" name="logs">
          <template #label><el-icon><Tickets /></el-icon> 登录日志</template>
          <el-table :data="loginLogs" stripe>
            <el-table-column prop="adminId" label="ID" width="80" />
            <el-table-column prop="username" label="用户名" width="120" />
            <el-table-column prop="nickname" label="昵称" width="150" />
            <el-table-column label="登录时间" min-width="180">
              <template #default="{ row }">{{ formatDate(row.loginTime) }}</template>
            </el-table-column>
            <el-table-column prop="loginIp" label="IP地址" width="150">
              <template #default="{ row }">{{ row.loginIp || '-' }}</template>
            </el-table-column>
          </el-table>
        </el-tab-pane>
      </el-tabs>
    </el-card>
    
    <!-- 管理员编辑对话框 -->
    <el-dialog v-model="adminDialogVisible" :title="adminDialogTitle" width="500px">
      <el-form :model="adminForm" label-width="100px">
        <el-form-item label="用户名" required>
          <el-input v-model="adminForm.username" :disabled="!!adminForm.id" />
        </el-form-item>
        <el-form-item label="密码" :required="!adminForm.id">
          <el-input v-model="adminForm.password" type="password" placeholder="编辑时不填则不修改" />
        </el-form-item>
        <el-form-item label="昵称">
          <el-input v-model="adminForm.nickname" />
        </el-form-item>
        <el-form-item label="邮箱">
          <el-input v-model="adminForm.email" />
        </el-form-item>
        <el-form-item label="手机">
          <el-input v-model="adminForm.phone" />
        </el-form-item>
        <el-form-item label="角色">
          <el-select v-model="adminForm.roleCode">
            <el-option label="超级管理员" value="SUPER_ADMIN" />
            <el-option label="管理员" value="ADMIN" />
            <el-option label="审核员" value="REVIEWER" />
          </el-select>
        </el-form-item>
        <el-form-item label="状态">
          <el-select v-model="adminForm.status">
            <el-option label="正常" value="ACTIVE" />
            <el-option label="禁用" value="INACTIVE" />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="adminDialogVisible = false">取消</el-button>
        <el-button type="primary" @click="saveAdmin">保存</el-button>
      </template>
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
.main-card { background: var(--bg-card); }

.admin-info-text {
  display: flex;
  flex-direction: column;
  .nickname { font-weight: 500; color: var(--text-primary); }
  .username { font-size: 12px; color: var(--text-secondary); margin-top: 4px; }
}

.roles-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 20px; }
.role-card {
  background: var(--bg-card-hover);
  .role-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;
    h4 { margin: 0; }
  }
  .role-desc { margin: 0 0 15px; color: var(--text-secondary); font-size: 13px; }
}

// 绿色森林主题标签样式
.role-code-tag {
  background: rgba(16, 185, 129, 0.1) !important;
  color: #10B981 !important;
  border-color: rgba(16, 185, 129, 0.3) !important;
}

.permission-tag {
  background: rgba(16, 185, 129, 0.15) !important;
  color: #10B981 !important;
  border-color: rgba(16, 185, 129, 0.4) !important;
}

// 新增按钮样式
.add-btn {
  background: var(--primary-color) !important;
  color: white !important;
  border-color: var(--primary-color) !important;
  
  &:hover {
    background: var(--primary-color-hover) !important;
    border-color: var(--primary-color-hover) !important;
  }
}

// 管理员角色标签样式
.role-tag-admin {
  background: rgba(16, 185, 129, 0.1) !important;
  color: #10B981 !important;
  border-color: rgba(16, 185, 129, 0.3) !important;
}
</style>
