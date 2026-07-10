<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { Refresh } from '@element-plus/icons-vue'
import request from '@/utils/request'

const loading = ref(false)
const slots = ref<any[]>([])
const total = ref(0)

const fetchSlots = async () => {
  loading.value = true
  try {
    const res = await request.get('/splash/slots', { params: { page: 0, size: 50 } })
    if (res.code === 0) {
      slots.value = res.data.content
      total.value = res.data.totalElements
    }
  } catch (e) { console.error(e) }
  finally { loading.value = false }
}

onMounted(() => { fetchSlots() })
</script>

<template>
  <div class="page-container">
    <div class="page-header"><h2>展示位管理</h2><p>管理开屏展示位</p></div>
    <el-card class="action-bar"><el-button :icon="Refresh" @click="fetchSlots">刷新</el-button></el-card>
    <el-card class="table-card">
      <el-table :data="slots" v-loading="loading" stripe>
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column prop="userNickname" label="用户" width="120" />
        <el-table-column prop="displayDate" label="展示日期" width="120" />
        <el-table-column prop="slotNumber" label="展位号" width="100" />
        <el-table-column label="审核状态" width="100">
          <template #default="{ row }">
            <el-tag :type="row.reviewStatus === 'APPROVED' ? 'success' : (row.reviewStatus === 'REJECTED' ? 'danger' : 'warning')" size="small">
              {{ row.reviewStatus === 'APPROVED' ? '已通过' : (row.reviewStatus === 'REJECTED' ? '已驳回' : '待审核') }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="图片" width="100">
          <template #default="{ row }">
            <el-image v-if="row.imageUrl" :src="row.imageUrl" :preview-src-list="[row.imageUrl]" fit="cover" style="width: 50px; height: 50px; border-radius: 4px;" />
          </template>
        </el-table-column>
      </el-table>
    </el-card>
  </div>
</template>

<style lang="scss" scoped>
.page-container { padding: 20px; }
.page-header { margin-bottom: 20px; h2 { margin: 0 0 8px; color: var(--text-primary); } p { margin: 0; color: var(--text-secondary); } }
.action-bar { margin-bottom: 20px; }
.table-card { background: var(--bg-card); }
</style>
