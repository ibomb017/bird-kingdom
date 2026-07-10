<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { Refresh, Check, Close, View, ArrowDown, Warning, Document, Location, CollectionTag, Star, ChatRound, StarFilled } from '@element-plus/icons-vue'
import request from '@/utils/request'

const loading = ref(false)
const reports = ref<any[]>([])
const total = ref(0)
const currentPage = ref(1)
const status = ref('PENDING')

// 详情弹窗
const detailVisible = ref(false)
const currentReport = ref<any>(null)

// 帖子详情弹窗
const postDetailVisible = ref(false)
const postDetail = ref<any>(null)
const postDetailLoading = ref(false)

const fetchReports = async () => {
  loading.value = true
  try {
    const res = await request.get('/forum/reports', {
      params: { page: currentPage.value - 1, size: 20, status: status.value }
    })
    if (res.code === 0) {
      reports.value = res.data.content
      total.value = res.data.totalElements
    }
  } catch (e) { console.error(e) }
  finally { loading.value = false }
}

const handleStatusChange = () => { currentPage.value = 1; fetchReports() }

const showDetail = (item: any) => {
  currentReport.value = item
  detailVisible.value = true
}

const showPostDetail = async (postId: number) => {
  if (!postId) {
    ElMessage.warning('无效的帖子 ID')
    return
  }
  postDetailLoading.value = true
  postDetailVisible.value = true
  try {
    const res = await request.get(`/forum/posts/${postId}`)
    if (res.code === 0) {
      postDetail.value = res.data
    } else {
      postDetail.value = null
      ElMessage.warning('帖子不存在或已删除')
    }
  } catch (e) {
    postDetail.value = null
    ElMessage.error('无法获取帖子内容')
  } finally {
    postDetailLoading.value = false
  }
}

const handleAction = async (id: number, action: string) => {
  try {
    const res = await request.post(`/forum/reports/${id}/handle`, { action })
    if (res.code === 0) {
      ElMessage.success('已处理')
      fetchReports()
      detailVisible.value = false
    } else {
      ElMessage.error(res.message || '操作失败')
    }
  } catch (e) { ElMessage.error('操作失败') }
}

const handleReject = (id: number) => handleAction(id, 'reject')

const formatDate = (dateStr: string) => dateStr ? new Date(dateStr).toLocaleString('zh-CN') : '-'

const getReasonLabel = (reason: string) => {
  const map: Record<string, string> = {
    'SPAM': '垃圾广告',
    'INAPPROPRIATE': '不当内容',
    'HARASSMENT': '骚扰',
    'VIOLENCE': '暴力',
    'OTHER': '其他',
    '垃圾广告或营销信息': '垃圾广告',
    '色情低俗内容': '色情低俗',
    '辱骂攻击或骚扰': '辱骂骚扰',
    '虚假不实信息': '虚假信息',
    '侵犯隐私': '侵犯隐私',
    '其他原因': '其他'
  }
  return map[reason] || reason || '-'
}

const getStatusLabel = (s: string) => {
  const map: Record<string, string> = { 'PENDING': '待处理', 'APPROVED': '已处理', 'REJECTED': '已忽略', 'REVIEWED': '已审核' }
  return map[s] || s
}

const getStatusColor = (s: string): '' | 'success' | 'warning' | 'info' => {
  const map: Record<string, '' | 'success' | 'warning' | 'info'> = { 'PENDING': 'warning', 'APPROVED': 'success', 'REJECTED': 'info', 'REVIEWED': 'success' }
  return map[s] || 'info'
}

onMounted(() => { fetchReports() })
</script>

<template>
  <div class="page-container">
    <div class="page-header">
      <div>
        <h2><el-icon><Warning /></el-icon> 举报审核</h2>
        <p>处理用户提交的内容举报</p>
      </div>
      <el-button :icon="Refresh" @click="fetchReports">刷新</el-button>
    </div>
    
    <el-card class="filter-card">
      <el-radio-group v-model="status" @change="handleStatusChange">
        <el-radio-button label="PENDING">待处理</el-radio-button>
        <el-radio-button label="APPROVED">已处理</el-radio-button>
        <el-radio-button label="REJECTED">已忽略</el-radio-button>
        <el-radio-button label="">全部</el-radio-button>
      </el-radio-group>
    </el-card>
    
    <el-card class="table-card">
      <el-table :data="reports" v-loading="loading" stripe>
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column label="举报人" width="140">
          <template #default="{ row }">
            <div class="user-info">
              <el-avatar :src="row.reporterAvatarUrl" :size="32">{{ row.reporterNickname?.charAt(0) }}</el-avatar>
              <span>{{ row.reporterNickname || '-' }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="举报原因" width="120">
          <template #default="{ row }">
            <el-tag type="danger" size="small">{{ getReasonLabel(row.reason) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="description" label="详细描述" min-width="200" show-overflow-tooltip />
        <el-table-column label="被举报帖子" width="200">
          <template #default="{ row }">
            <div class="post-cell">
              <span class="post-id">帖子 #{{ row.postId }}</span>
              <el-button type="primary" size="small" :icon="View" @click="showPostDetail(row.postId)" class="view-post-btn">查看原帖</el-button>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="100">
          <template #default="{ row }">
            <el-tag :type="getStatusColor(row.status)" size="small">{{ getStatusLabel(row.status) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="举报时间" width="160">
          <template #default="{ row }">{{ formatDate(row.createdAt) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="120" fixed="right">
          <template #default="{ row }">
            <el-button type="primary" link size="small" @click="showDetail(row)">详情与处理</el-button>
          </template>
        </el-table-column>
      </el-table>
      
      <el-pagination v-model:current-page="currentPage" :page-size="20" :total="total" layout="total, prev, pager, next" @current-change="fetchReports" class="pagination" />
    </el-card>
    
    <!-- 举报详情弹窗 -->
    <el-dialog v-model="detailVisible" title="举报详情" width="600px" v-if="currentReport">
      <el-descriptions :column="2" border>
        <el-descriptions-item label="举报ID">{{ currentReport.id }}</el-descriptions-item>
        <el-descriptions-item label="状态"><el-tag :type="getStatusColor(currentReport.status)" size="small">{{ getStatusLabel(currentReport.status) }}</el-tag></el-descriptions-item>
        <el-descriptions-item label="举报人">{{ currentReport.reporterNickname }}</el-descriptions-item>
        <el-descriptions-item label="举报原因"><el-tag type="danger" size="small">{{ getReasonLabel(currentReport.reason) }}</el-tag></el-descriptions-item>
        <el-descriptions-item label="详细描述" :span="2">{{ currentReport.description || '无' }}</el-descriptions-item>
        <el-descriptions-item label="被举报帖子" :span="2">
          <div class="report-post-info">
            <span>帖子 ID: {{ currentReport.postId }}</span>
            <el-button type="primary" size="small" :icon="View" @click="showPostDetail(currentReport.postId)">查看原帖</el-button>
          </div>
        </el-descriptions-item>
        <el-descriptions-item label="帖子内容预览" :span="2" v-if="currentReport.postContent">{{ currentReport.postContent }}</el-descriptions-item>
        <el-descriptions-item label="举报时间" :span="2">{{ formatDate(currentReport.createdAt) }}</el-descriptions-item>
      </el-descriptions>
      <template #footer v-if="currentReport.status === 'PENDING'">
        <el-button type="info" :icon="Close" @click="handleReject(currentReport.id)">忽略举报</el-button>
        <el-dropdown @command="(cmd: string) => handleAction(currentReport.id, cmd)" trigger="click">
          <el-button type="success" :icon="Check">
            处理举报 (采纳)<el-icon class="el-icon--right"><arrow-down /></el-icon>
          </el-button>
          <template #dropdown>
            <el-dropdown-menu>
              <el-dropdown-item command="approve">仅采纳 (保留内容)</el-dropdown-item>
              <el-dropdown-item command="delete_post" divided style="color: #F56C6C">采纳并删除违规帖子</el-dropdown-item>
              <el-dropdown-item command="ban_user" style="color: #F56C6C">采纳并封禁发布用户</el-dropdown-item>
            </el-dropdown-menu>
          </template>
        </el-dropdown>
      </template>
    </el-dialog>

    <!-- 帖子详情弹窗 -->
    <el-dialog v-model="postDetailVisible" title="帖子详情" width="650px">
      <template #header>
        <span class="el-dialog__title"><el-icon><Document /></el-icon> 帖子详情</span>
      </template>
      <div v-loading="postDetailLoading">
        <div v-if="postDetail" class="post-detail-content">
          <!-- 作者信息 -->
          <div class="post-author">
            <el-avatar :src="postDetail.authorAvatarUrl" :size="40">{{ postDetail.authorNickname?.charAt(0) || '?' }}</el-avatar>
            <div class="post-author-info">
              <span class="author-name">{{ postDetail.authorNickname || '未知用户' }}</span>
              <span class="post-time">{{ formatDate(postDetail.createdAt) }}</span>
            </div>
            <el-tag size="small" style="margin-left: auto">{{ postDetail.postType || 'NORMAL' }}</el-tag>
          </div>

          <!-- 帖子文本 -->
          <div class="post-text">{{ postDetail.content || '(无文字内容)' }}</div>

          <!-- 帖子图片 -->
          <div class="post-media" v-if="postDetail.mediaUrls && postDetail.mediaUrls.length > 0">
            <el-image 
              v-for="(url, idx) in postDetail.mediaUrls" 
              :key="idx" 
              :src="url" 
              fit="cover"
              :preview-src-list="postDetail.mediaUrls"
              :initial-index="idx"
              class="post-image"
              lazy
            >
              <template #error>
                <div class="image-error">加载失败</div>
              </template>
            </el-image>
          </div>

          <!-- 帖子视频 -->
          <div class="post-media" v-if="postDetail.videoUrl">
            <video :src="postDetail.videoUrl" controls class="post-video" />
          </div>

          <!-- 位置/鸟类信息 -->
          <div class="post-meta">
            <el-tag v-if="postDetail.locationName" type="info" size="small"><el-icon><Location /></el-icon> {{ postDetail.locationName }}</el-tag>
            <el-tag v-if="postDetail.birdName" type="success" size="small"><el-icon><CollectionTag /></el-icon> {{ postDetail.birdName }}</el-tag>
            <el-tag v-if="postDetail.birdSpecies" size="small">{{ postDetail.birdSpecies }}</el-tag>
          </div>

          <!-- 互动数据 -->
          <div class="post-stats">
            <span><el-icon><Star /></el-icon> {{ postDetail.likeCount || 0 }}</span>
            <span><el-icon><ChatRound /></el-icon> {{ postDetail.commentCount || 0 }}</span>
            <span><el-icon><StarFilled /></el-icon> {{ postDetail.favoriteCount || 0 }}</span>
            <span><el-icon><View /></el-icon> {{ postDetail.viewCount || 0 }}</span>
          </div>
        </div>
        <el-empty v-else-if="!postDetailLoading" description="帖子不存在或已被删除" />
      </div>
    </el-dialog>
  </div>
</template>

<style lang="scss" scoped>
.page-container { padding: 20px; }
.page-header {
  display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;
  h2 { margin: 0 0 8px; color: var(--text-primary); }
  p { margin: 0; color: var(--text-secondary); }
}
.filter-card { margin-bottom: 20px; }
.table-card { background: var(--bg-card); }
.user-info { display: flex; align-items: center; gap: 8px; }
.pagination { margin-top: 20px; justify-content: flex-end; }

.post-cell {
  display: flex;
  align-items: center;
  gap: 8px;
  .post-id {
    color: var(--text-secondary);
    font-size: 13px;
  }
  .view-post-btn {
    flex-shrink: 0;
  }
}

.report-post-info {
  display: flex;
  align-items: center;
  gap: 12px;
}

/* 帖子详情弹窗样式 */
.post-detail-content {
  .post-author {
    display: flex;
    align-items: center;
    gap: 12px;
    padding-bottom: 16px;
    border-bottom: 1px solid var(--el-border-color-lighter);
    margin-bottom: 16px;
    .post-author-info {
      display: flex;
      flex-direction: column;
      .author-name { font-weight: 600; font-size: 15px; }
      .post-time { font-size: 12px; color: var(--text-secondary); margin-top: 2px; }
    }
  }

  .post-text {
    font-size: 15px;
    line-height: 1.7;
    white-space: pre-wrap;
    word-break: break-word;
    margin-bottom: 16px;
    padding: 12px;
    background: var(--el-fill-color-light);
    border-radius: 8px;
  }

  .post-media {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    margin-bottom: 16px;
    .post-image {
      width: 120px;
      height: 120px;
      border-radius: 8px;
      overflow: hidden;
      cursor: pointer;
    }
    .image-error {
      width: 120px;
      height: 120px;
      display: flex;
      align-items: center;
      justify-content: center;
      background: var(--el-fill-color);
      color: var(--text-secondary);
      font-size: 12px;
    }
    .post-video {
      max-width: 100%;
      max-height: 300px;
      border-radius: 8px;
    }
  }

  .post-meta {
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
    margin-bottom: 12px;
  }

  .post-stats {
    display: flex;
    gap: 20px;
    padding-top: 12px;
    border-top: 1px solid var(--el-border-color-lighter);
    font-size: 14px;
    color: var(--text-secondary);
  }
}
</style>
