<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { Refresh } from '@element-plus/icons-vue'
import request from '@/utils/request'

const loading = ref(false)
const birds = ref<any[]>([])
const total = ref(0)

const fetchTrash = async () => {
  loading.value = true
  try {
    const res = await request.get('/birds/trash', { params: { page: 0, size: 50 } })
    if (res.code === 0) {
      birds.value = res.data.content
      total.value = res.data.totalElements
    }
  } catch (e) { console.error(e) }
  finally { loading.value = false }
}

onMounted(() => { fetchTrash() })
</script>

<template>
  <div class="page-container">
    <div class="page-header"><h2>回收站</h2><p>查看已删除的鸟儿档案</p></div>
    <el-card class="action-bar"><el-button :icon="Refresh" @click="fetchTrash">刷新</el-button></el-card>
    <el-card class="table-card">
      <el-table :data="birds" v-loading="loading" stripe>
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column prop="nickname" label="昵称" width="150" />
        <el-table-column prop="species" label="品种" width="150" />
        <el-table-column prop="ownerNickname" label="主人" width="150" />
        <el-table-column label="删除时间">
          <template #default="{ row }">{{ new Date(row.updatedAt).toLocaleString('zh-CN') }}</template>
        </el-table-column>
      </el-table>
      <div v-if="birds.length === 0 && !loading" style="padding: 40px; text-align: center;">
        <el-empty description="回收站为空" />
      </div>
    </el-card>
  </div>
</template>

<style lang="scss" scoped>
.page-container { padding: 20px; }
.page-header { margin-bottom: 20px; h2 { margin: 0 0 8px; color: var(--text-primary); } p { margin: 0; color: var(--text-secondary); } }
.action-bar { margin-bottom: 20px; }
.table-card { background: var(--bg-card); }
</style>
