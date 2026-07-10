<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { Refresh } from '@element-plus/icons-vue'
import request from '@/utils/request'

const loading = ref(false)
const comments = ref<any[]>([])
const total = ref(0)
const currentPage = ref(1)
const pageSize = ref(20)

const fetchComments = async () => {
  loading.value = true
  try {
    const res = await request.get('/forum/comments', {
      params: { page: currentPage.value - 1, size: pageSize.value }
    })
    if (res.code === 0) {
      comments.value = res.data.content
      total.value = res.data.totalElements
    }
  } catch (e) {
    console.error(e)
  } finally {
    loading.value = false
  }
}

const handlePageChange = (page: number) => {
  currentPage.value = page
  fetchComments()
}

const formatDate = (dateStr: string) => {
  if (!dateStr) return '-'
  return new Date(dateStr).toLocaleString('zh-CN')
}

onMounted(() => { fetchComments() })
</script>

<template>
  <div class="page-container">
    <div class="page-header">
      <h2>评论管理</h2>
      <p>查看帖子评论</p>
    </div>
    
    <el-card class="action-bar">
      <el-button :icon="Refresh" @click="fetchComments">刷新</el-button>
    </el-card>
    
    <el-card class="table-card">
      <el-table :data="comments" v-loading="loading" stripe>
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column label="评论者" width="150">
          <template #default="{ row }">
            <div class="user-info">
              <el-avatar :src="row.userAvatarUrl" :size="32">{{ row.userNickname?.charAt(0) }}</el-avatar>
              <span>{{ row.userNickname || '未知' }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="评论内容" min-width="300">
          <template #default="{ row }">
            <p class="comment-content">{{ row.content }}</p>
          </template>
        </el-table-column>
        <el-table-column prop="postId" label="帖子ID" width="100" />
        <el-table-column label="点赞" width="80">
          <template #default="{ row }">{{ row.likeCount }}</template>
        </el-table-column>
        <el-table-column label="时间" width="170">
          <template #default="{ row }">{{ formatDate(row.createdAt) }}</template>
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
  </div>
</template>

<style lang="scss" scoped>
.page-container { padding: 20px; }
.page-header {
  margin-bottom: 20px;
  h2 { margin: 0 0 8px; color: var(--text-primary); }
  p { margin: 0; color: var(--text-secondary); }
}
.action-bar { margin-bottom: 20px; }
.table-card { background: var(--bg-card); }
.user-info {
  display: flex;
  align-items: center;
  gap: 8px;
}
.comment-content {
  margin: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
}
.pagination { margin-top: 20px; justify-content: flex-end; }
</style>
