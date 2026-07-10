<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { Refresh } from '@element-plus/icons-vue'
import request from '@/utils/request'

const loading = ref(false)
const posts = ref<any[]>([])
const total = ref(0)

const fetchFindBird = async () => {
  loading.value = true
  try {
    const res = await request.get('/forum/posts', { params: { page: 0, size: 50, postType: 'FIND_BIRD' } })
    if (res.code === 0) {
      posts.value = res.data.content
      total.value = res.data.totalElements
    }
  } catch (e) { console.error(e) }
  finally { loading.value = false }
}

onMounted(() => { fetchFindBird() })
</script>

<template>
  <div class="page-container">
    <div class="page-header"><h2>寻鸟帖专项</h2><p>管理寻鸟帖子</p></div>
    <el-card class="action-bar"><el-button :icon="Refresh" @click="fetchFindBird">刷新</el-button></el-card>
    <el-card class="table-card">
      <el-table :data="posts" v-loading="loading" stripe>
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column prop="authorNickname" label="作者" width="120" />
        <el-table-column label="内容" min-width="300">
          <template #default="{ row }"><p class="content">{{ row.content }}</p></template>
        </el-table-column>
        <el-table-column label="状态" width="100">
          <template #default="{ row }">
            <el-tag :type="!row.isFound ? 'danger' : 'success'" size="small">{{ !row.isFound ? '寻找中' : '已找到' }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="发布时间" width="170">
          <template #default="{ row }">{{ new Date(row.createdAt).toLocaleString('zh-CN') }}</template>
        </el-table-column>
      </el-table>
      <div v-if="posts.length === 0 && !loading" style="padding: 40px; text-align: center;">
        <el-empty description="暂无寻鸟帖" />
      </div>
    </el-card>
  </div>
</template>

<style lang="scss" scoped>
.page-container { padding: 20px; }
.page-header { margin-bottom: 20px; h2 { margin: 0 0 8px; color: var(--text-primary); } p { margin: 0; color: var(--text-secondary); } }
.action-bar { margin-bottom: 20px; }
.table-card { background: var(--bg-card); }
.content { margin: 0; overflow: hidden; text-overflow: ellipsis; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; }
</style>
