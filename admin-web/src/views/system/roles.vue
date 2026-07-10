<script setup lang="ts">
import { ref, onMounted } from 'vue'
import request from '@/utils/request'

const loading = ref(false)
const roles = ref<any[]>([])

const fetchRoles = async () => {
  loading.value = true
  try {
    const res = await request.get('/system/roles')
    if (res.code === 0) { roles.value = res.data }
  } catch (e) { console.error(e) }
  finally { loading.value = false }
}

onMounted(() => { fetchRoles() })
</script>

<template>
  <div class="page-container">
    <div class="page-header"><h2>角色权限</h2><p>管理系统角色和权限</p></div>
    <div class="roles-grid" v-loading="loading">
      <el-card v-for="role in roles" :key="role.code" class="role-card">
        <div class="role-header">
          <h3>{{ role.name }}</h3>
          <el-tag size="small" type="info">{{ role.code }}</el-tag>
        </div>
        <p class="role-desc">{{ role.description }}</p>
        <div class="permissions">
          <el-tag v-for="perm in role.permissions" :key="perm" size="small" type="success" style="margin: 4px;">{{ perm }}</el-tag>
        </div>
      </el-card>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.page-container { padding: 20px; }
.page-header { margin-bottom: 20px; h2 { margin: 0 0 8px; color: var(--text-primary); } p { margin: 0; color: var(--text-secondary); } }
.roles-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 20px; }
.role-card {
  background: var(--bg-card);
  .role-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px; h3 { margin: 0; } }
  .role-desc { margin: 0 0 15px; color: var(--text-secondary); font-size: 13px; }
}
</style>
