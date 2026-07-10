<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Search, Refresh, View, Delete, ChatLineSquare, Picture, VideoPlay, Document } from '@element-plus/icons-vue'
import request from '@/utils/request'

const loading = ref(false)
const posts = ref<any[]>([])
const total = ref(0)
const currentPage = ref(1)
const keyword = ref('')
const postType = ref('')

// 帖子详情
const detailVisible = ref(false)
const currentPost = ref<any>(null)
const detailLoading = ref(false)

// 评论列表
const commentsVisible = ref(false)
const comments = ref<any[]>([])
const commentsLoading = ref(false)
const commentsTotal = ref(0)
const commentsPage = ref(1)

// 图片预览
const previewVisible = ref(false)
const previewImages = ref<string[]>([])
const previewIndex = ref(0)

const fetchPosts = async () => {
  loading.value = true
  try {
    const params: any = { page: currentPage.value - 1, size: 20 }
    if (keyword.value) params.keyword = keyword.value
    if (postType.value) params.postType = postType.value
    
    const res = await request.get('/forum/posts', { params })
    if (res.code === 0) {
      posts.value = res.data.content
      total.value = res.data.totalElements
    }
  } catch (e) { console.error(e) }
  finally { loading.value = false }
}

const handleSearch = () => { currentPage.value = 1; fetchPosts() }
const handlePageChange = (page: number) => { currentPage.value = page; fetchPosts() }

const showDetail = async (id: number) => {
  detailLoading.value = true
  detailVisible.value = true
  try {
    const res = await request.get(`/forum/posts/${id}`)
    if (res.code === 0) {
      currentPost.value = res.data
    }
  } catch (e) { console.error(e) }
  finally { detailLoading.value = false }
}

// 加载帖子评论
const loadComments = async (postId: number) => {
  commentsLoading.value = true
  commentsVisible.value = true
  try {
    const res = await request.get('/forum/comments', { 
      params: { postId, page: commentsPage.value - 1, size: 20 } 
    })
    if (res.code === 0) {
      comments.value = res.data.content
      commentsTotal.value = res.data.totalElements
    }
  } catch (e) { console.error(e) }
  finally { commentsLoading.value = false }
}

// 显示图片预览
const showImagePreview = (images: string[], index: number = 0) => {
  previewImages.value = images
  previewIndex.value = index
  previewVisible.value = true
}

// 删除帖子
const handleDelete = async (id: number) => {
  try {
    await ElMessageBox.confirm('确定删除这条帖子吗？删除后将无法恢复。', '删除确认', {
      confirmButtonText: '确定删除',
      cancelButtonText: '取消',
      type: 'warning',
      confirmButtonClass: 'el-button--danger'
    })
    
    const res = await request.delete(`/forum/posts/${id}`)
    if (res.code === 0) {
      ElMessage.success('删除成功')
      fetchPosts()
      if (detailVisible.value) detailVisible.value = false
    } else {
      ElMessage.error(res.message || '删除失败')
    }
  } catch (e: any) {
    if (e !== 'cancel') {
      ElMessage.error('删除失败')
    }
  }
}

// 删除评论
const handleDeleteComment = async (id: number, postId: number) => {
  try {
    await ElMessageBox.confirm('确定删除这条评论吗？', '删除确认', { type: 'warning' })
    const res = await request.delete(`/forum/comments/${id}`)
    if (res.code === 0) {
      ElMessage.success('评论已删除')
      loadComments(postId)
    } else {
      ElMessage.error(res.message || '删除失败')
    }
  } catch (e: any) {
    if (e !== 'cancel') {
      ElMessage.error('删除失败')
    }
  }
}

const formatDate = (dateStr: string) => dateStr ? new Date(dateStr).toLocaleString('zh-CN') : '-'

const getPostTypeLabel = (type: string) => {
  const map: Record<string, string> = { 'NORMAL': '普通帖子', 'FIND_BIRD': '寻鸟启事' }
  return map[type] || type || '-'
}

const getMediaTypeLabel = (type: string) => {
  const map: Record<string, string> = { 'IMAGE': '图片', 'VIDEO': '视频', 'NONE': '纯文字' }
  return map[type] || type || '-'
}

const getMediaTypeIcon = (type: string) => {
  const map: Record<string, any> = { 'IMAGE': Picture, 'VIDEO': VideoPlay, 'NONE': Document }
  return map[type] || Document
}

onMounted(() => { fetchPosts() })
</script>

<template>
  <div class="page-container">
    <div class="page-header">
      <div>
        <h2>
          <el-icon><Document /></el-icon>
          帖子管理
        </h2>
        <p>管理论坛帖子，可查看详情、图片、评论并进行审核删除</p>
      </div>
      <el-button :icon="Refresh" @click="fetchPosts" class="refresh-btn">刷新数据</el-button>
    </div>
    
    <el-card class="search-card">
      <el-form :inline="true">
        <el-form-item label="关键词">
          <el-input v-model="keyword" placeholder="搜索帖子内容" clearable @keyup.enter="handleSearch" style="width: 200px;" />
        </el-form-item>
        <el-form-item label="帖子类型">
          <el-select v-model="postType" placeholder="全部类型" clearable style="width: 140px;">
            <el-option label="全部类型" value="" />
            <el-option label="普通帖子" value="NORMAL" />
            <el-option label="寻鸟启事" value="FIND_BIRD" />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button type="primary" :icon="Search" @click="handleSearch">搜索</el-button>
          <el-button @click="keyword = ''; postType = ''; handleSearch()">重置</el-button>
        </el-form-item>
      </el-form>
    </el-card>
    
    <el-card class="table-card">
      <el-table :data="posts" v-loading="loading" stripe>
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column label="发布者" width="180">
          <template #default="{ row }">
            <div class="author-cell">
              <el-avatar :src="row.authorAvatarUrl" :size="38">{{ row.authorNickname?.charAt(0) }}</el-avatar>
              <div class="author-info">
                <span class="author-name">{{ row.authorNickname || '未知用户' }}</span>
                <span class="author-id">ID: {{ row.authorId }}</span>
              </div>
            </div>
          </template>
        </el-table-column>
        <el-table-column prop="content" label="帖子内容" min-width="280">
          <template #default="{ row }">
            <div class="content-cell">
              <p class="content-text">{{ row.content }}</p>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="互动数据" width="130">
          <template #default="{ row }">
            <div class="stats-cell">
              <span class="stat-item"><el-icon><svg viewBox="0 0 24 24" width="14" height="14"><path fill="currentColor" d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/></svg></el-icon> {{ row.likeCount || 0 }}</span>
              <span class="stat-item"><el-icon><ChatLineSquare /></el-icon> {{ row.commentCount || 0 }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="发布时间" width="170">
          <template #default="{ row }">
            <span class="time-text">{{ formatDate(row.createdAt) }}</span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="200" fixed="right">
          <template #default="{ row }">
            <div class="action-buttons">
              <el-button type="primary" link size="small" :icon="View" @click="showDetail(row.id)">详情</el-button>
              <el-button type="info" link size="small" :icon="ChatLineSquare" @click="loadComments(row.id)">评论</el-button>
              <el-button type="danger" link size="small" :icon="Delete" @click="handleDelete(row.id)">删除</el-button>
            </div>
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
    
    <!-- 帖子详情弹窗 -->
    <el-dialog v-model="detailVisible" title="帖子详情" width="700px" class="detail-dialog">
      <div v-loading="detailLoading">
        <template v-if="currentPost">
          <!-- 作者信息 -->
          <div class="detail-author">
            <el-avatar :src="currentPost.authorAvatarUrl" :size="56">{{ currentPost.authorNickname?.charAt(0) }}</el-avatar>
            <div class="author-info">
              <h3>{{ currentPost.authorNickname }}</h3>
              <span class="publish-time">发布于 {{ formatDate(currentPost.createdAt) }}</span>
            </div>
            <el-tag :type="currentPost.postType === 'FIND_BIRD' ? 'warning' : 'info'" effect="dark">
              {{ getPostTypeLabel(currentPost.postType) }}
            </el-tag>
          </div>
          
          <!-- 帖子内容 -->
          <div class="detail-content">
            <p>{{ currentPost.content }}</p>
          </div>
          
          <!-- 寻鸟信息 -->
          <div v-if="currentPost.postType === 'FIND_BIRD'" class="find-bird-info">
            <h4>寻鸟信息</h4>
            <el-descriptions :column="2" border size="small">
              <el-descriptions-item label="鸟儿名字">{{ currentPost.birdName || '-' }}</el-descriptions-item>
              <el-descriptions-item label="鸟儿品种">{{ currentPost.birdSpecies || '-' }}</el-descriptions-item>
              <el-descriptions-item label="丢失地点">{{ currentPost.lostLocation || '-' }}</el-descriptions-item>
              <el-descriptions-item label="是否找到">
                <el-tag :type="currentPost.isFound ? 'success' : 'danger'" size="small">
                  {{ currentPost.isFound ? '已找到' : '未找到' }}
                </el-tag>
              </el-descriptions-item>
            </el-descriptions>
          </div>
          
          <!-- 媒体内容 -->
          <div class="detail-media" v-if="currentPost.mediaType !== 'NONE'">
            <h4>
              <el-icon><Picture /></el-icon>
              媒体内容
            </h4>
            <div class="media-grid" v-if="currentPost.mediaType === 'IMAGE' && currentPost.mediaUrls?.length">
              <div 
                v-for="(url, i) in currentPost.mediaUrls" 
                :key="i" 
                class="media-item"
                @click="showImagePreview(currentPost.mediaUrls, i)"
              >
                <el-image :src="url" fit="cover" />
                <div class="media-overlay">
                  <el-icon><View /></el-icon>
                </div>
              </div>
            </div>
            <div v-if="currentPost.mediaType === 'VIDEO' && currentPost.videoUrl" class="video-container">
              <video :src="currentPost.videoUrl" controls class="video-player" />
            </div>
          </div>
          
          <!-- 互动数据 -->
          <div class="detail-stats">
            <div class="stat-box">
              <span class="stat-value">{{ currentPost.likeCount || 0 }}</span>
              <span class="stat-label">点赞</span>
            </div>
            <div class="stat-box">
              <span class="stat-value">{{ currentPost.commentCount || 0 }}</span>
              <span class="stat-label">评论</span>
            </div>
            <div class="stat-box">
              <span class="stat-value">{{ currentPost.favoriteCount || 0 }}</span>
              <span class="stat-label">收藏</span>
            </div>
            <div class="stat-box">
              <span class="stat-value">{{ currentPost.viewCount || 0 }}</span>
              <span class="stat-label">浏览</span>
            </div>
          </div>
        </template>
      </div>
      <template #footer>
        <el-button @click="detailVisible = false">关闭</el-button>
        <el-button type="info" :icon="ChatLineSquare" @click="loadComments(currentPost?.id)" v-if="currentPost">
          查看评论 ({{ currentPost?.commentCount || 0 }})
        </el-button>
        <el-button type="danger" :icon="Delete" @click="handleDelete(currentPost?.id)" v-if="currentPost">删除帖子</el-button>
      </template>
    </el-dialog>
    
    <!-- 评论列表弹窗 -->
    <el-dialog v-model="commentsVisible" title="帖子评论" width="650px" class="comments-dialog">
      <div v-loading="commentsLoading">
        <div v-if="comments.length === 0" class="empty-comments">
          <el-icon :size="48"><ChatLineSquare /></el-icon>
          <p>暂无评论</p>
        </div>
        <div v-else class="comments-list">
          <div v-for="comment in comments" :key="comment.id" class="comment-item">
            <el-avatar :src="comment.userAvatarUrl" :size="40">{{ comment.userNickname?.charAt(0) }}</el-avatar>
            <div class="comment-content">
              <div class="comment-header">
                <span class="comment-author">{{ comment.userNickname || '未知用户' }}</span>
                <span class="comment-time">{{ formatDate(comment.createdAt) }}</span>
              </div>
              <p class="comment-text">{{ comment.content }}</p>
              <div class="comment-footer">
                <span class="comment-likes">
                  <el-icon><svg viewBox="0 0 24 24" width="12" height="12"><path fill="currentColor" d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/></svg></el-icon>
                  {{ comment.likeCount || 0 }}
                </span>
                <el-button type="danger" link size="small" @click="handleDeleteComment(comment.id, comment.postId)">删除</el-button>
              </div>
            </div>
          </div>
        </div>
        <el-pagination 
          v-if="commentsTotal > 20"
          v-model:current-page="commentsPage"
          :page-size="20"
          :total="commentsTotal"
          layout="prev, pager, next"
          @current-change="(page: number) => { commentsPage = page; loadComments(currentPost?.id) }"
          class="comments-pagination"
        />
      </div>
    </el-dialog>
    
    <!-- 图片预览 -->
    <el-image-viewer
      v-if="previewVisible"
      :url-list="previewImages"
      :initial-index="previewIndex"
      @close="previewVisible = false"
    />
  </div>
</template>

<style lang="scss" scoped>
.page-container { padding: 28px; }

.refresh-btn {
  &:hover {
    transform: rotate(180deg);
    transition: transform 0.5s ease;
  }
}

.author-cell {
  display: flex;
  align-items: center;
  gap: 12px;
  
  .author-info {
    display: flex;
    flex-direction: column;
    
    .author-name {
      font-weight: 600;
      color: var(--text-primary);
    }
    
    .author-id {
      font-size: 11px;
      color: var(--text-placeholder);
    }
  }
}

.content-cell {
  .content-text {
    margin: 0;
    overflow: hidden;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    color: var(--text-regular);
    line-height: 1.5;
  }
}

.type-tag {
  transition: all var(--transition-fast);
  
  &:hover {
    transform: scale(1.05);
  }
}

.media-cell {
  display: flex;
  align-items: center;
  gap: 6px;
  color: var(--text-secondary);
}

.stats-cell {
  display: flex;
  flex-direction: column;
  gap: 6px;
  
  .stat-item {
    display: flex;
    align-items: center;
    gap: 4px;
    font-size: 13px;
    color: var(--text-secondary);
  }
}

.time-text {
  font-size: 13px;
  color: var(--text-secondary);
}

.action-buttons {
  display: flex;
  gap: 4px;
}

// 详情弹窗样式
.detail-dialog {
  :deep(.el-dialog__body) {
    padding: 20px 24px;
  }
}

.detail-author {
  display: flex;
  align-items: center;
  gap: 16px;
  padding-bottom: 20px;
  border-bottom: 1px solid var(--border-lighter);
  
  .author-info {
    flex: 1;
    
    h3 {
      margin: 0 0 4px;
      font-size: 18px;
      color: var(--text-primary);
    }
    
    .publish-time {
      font-size: 13px;
      color: var(--text-secondary);
    }
  }
}

.detail-content {
  padding: 24px 0;
  
  p {
    margin: 0;
    font-size: 15px;
    line-height: 1.8;
    color: var(--text-primary);
    white-space: pre-wrap;
  }
}

.find-bird-info {
  padding: 20px;
  background: var(--bg-card-hover);
  border-radius: var(--radius-md);
  margin-bottom: 20px;
  
  h4 {
    margin: 0 0 16px;
    font-size: 14px;
    color: var(--warning-color);
    display: flex;
    align-items: center;
    gap: 8px;
  }
}

.detail-media {
  margin-bottom: 24px;
  
  h4 {
    margin: 0 0 16px;
    font-size: 14px;
    color: var(--text-secondary);
    display: flex;
    align-items: center;
    gap: 8px;
  }
  
  .media-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(120px, 1fr));
    gap: 12px;
  }
  
  .media-item {
    position: relative;
    border-radius: var(--radius-md);
    overflow: hidden;
    aspect-ratio: 1;
    cursor: pointer;
    
    .el-image {
      width: 100%;
      height: 100%;
    }
    
    .media-overlay {
      position: absolute;
      inset: 0;
      background: rgba(0, 0, 0, 0.5);
      display: flex;
      align-items: center;
      justify-content: center;
      opacity: 0;
      transition: opacity var(--transition-fast);
      
      .el-icon {
        font-size: 24px;
        color: white;
      }
    }
    
    &:hover .media-overlay {
      opacity: 1;
    }
  }
  
  .video-container {
    border-radius: var(--radius-md);
    overflow: hidden;
    
    .video-player {
      width: 100%;
      max-height: 400px;
      background: #000;
    }
  }
}

.detail-stats {
  display: flex;
  gap: 24px;
  padding: 20px;
  background: var(--bg-card-hover);
  border-radius: var(--radius-md);
  
  .stat-box {
    flex: 1;
    text-align: center;
    
    .stat-value {
      display: block;
      font-size: 24px;
      font-weight: 700;
      color: var(--primary-color);
    }
    
    .stat-label {
      font-size: 12px;
      color: var(--text-secondary);
    }
  }
}

// 评论列表样式
.empty-comments {
  text-align: center;
  padding: 60px 20px;
  color: var(--text-placeholder);
  
  .el-icon {
    margin-bottom: 16px;
  }
  
  p {
    margin: 0;
    font-size: 14px;
  }
}

.comments-list {
  max-height: 500px;
  overflow-y: auto;
}

.comment-item {
  display: flex;
  gap: 14px;
  padding: 16px 0;
  border-bottom: 1px solid var(--border-lighter);
  
  &:last-child {
    border-bottom: none;
  }
  
  .comment-content {
    flex: 1;
    
    .comment-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 8px;
      
      .comment-author {
        font-weight: 600;
        color: var(--text-primary);
      }
      
      .comment-time {
        font-size: 12px;
        color: var(--text-placeholder);
      }
    }
    
    .comment-text {
      margin: 0 0 10px;
      font-size: 14px;
      line-height: 1.6;
      color: var(--text-regular);
    }
    
    .comment-footer {
      display: flex;
      align-items: center;
      justify-content: space-between;
      
      .comment-likes {
        display: flex;
        align-items: center;
        gap: 4px;
        font-size: 12px;
        color: var(--text-secondary);
      }
    }
  }
}

.comments-pagination {
  margin-top: 16px;
  justify-content: center;
}
</style>
