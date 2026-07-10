<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { Refresh, Check, Close, View, Picture, Calendar } from '@element-plus/icons-vue'
import request from '@/utils/request'

const loading = ref(false)
const slots = ref<any[]>([])
const total = ref(0)
const currentPage = ref(1)
const status = ref('PENDING')

// 详情弹窗
const detailVisible = ref(false)
const currentSlot = ref<any>(null)

const fetchSlots = async () => {
  loading.value = true
  try {
    const res = await request.get('/splash/reviews', {
      params: { page: currentPage.value - 1, size: 20, status: status.value }
    })
    if (res.code === 0) {
      slots.value = res.data.content
      total.value = res.data.totalElements
    }
  } catch (e) { console.error(e) }
  finally { loading.value = false }
}

const handleStatusChange = () => { currentPage.value = 1; fetchSlots() }

const showDetail = (item: any) => {
  currentSlot.value = item
  detailVisible.value = true
}

const handleApprove = async (id: number) => {
  try {
    const res = await request.post(`/splash/reviews/${id}/approve`)
    if (res.code === 0) {
      ElMessage.success('审核通过')
      fetchSlots()
      detailVisible.value = false
    }
  } catch (e) { ElMessage.error('操作失败') }
}

const handleReject = async (id: number) => {
  try {
    const res = await request.post(`/splash/reviews/${id}/reject`, { reason: '图片不符合规范' })
    if (res.code === 0) {
      ElMessage.success('已驳回')
      fetchSlots()
      detailVisible.value = false
    }
  } catch (e) { ElMessage.error('操作失败') }
}

const formatDate = (dateStr: string) => dateStr ? new Date(dateStr).toLocaleDateString('zh-CN') : '-'

const getStatusLabel = (s: string) => {
  const map: Record<string, string> = { 'PENDING': '待审核', 'APPROVED': '已通过', 'REJECTED': '已驳回' }
  return map[s] || s
}

const getStatusColor = (s: string): '' | 'success' | 'warning' | 'danger' => {
  const map: Record<string, '' | 'success' | 'warning' | 'danger'> = { 'PENDING': 'warning', 'APPROVED': 'success', 'REJECTED': 'danger' }
  return map[s] || 'info'
}

onMounted(() => { fetchSlots() })
</script>

<template>
  <div class="page-container">
    <div class="page-header">
      <div>
        <h2>开屏图片审核</h2>
        <p>审核用户提交的开屏庆生图片</p>
      </div>
      <el-button :icon="Refresh" @click="fetchSlots">刷新</el-button>
    </div>
    
    <el-card class="filter-card">
      <el-radio-group v-model="status" @change="handleStatusChange">
        <el-radio-button label="PENDING">待审核</el-radio-button>
        <el-radio-button label="APPROVED">已通过</el-radio-button>
        <el-radio-button label="REJECTED">已驳回</el-radio-button>
        <el-radio-button label="">全部</el-radio-button>
      </el-radio-group>
    </el-card>
    
    <div class="slots-grid" v-loading="loading">
      <el-card v-for="item in slots" :key="item.id" class="slot-card" @click="showDetail(item)">
        <el-image :src="item.imageUrl" fit="cover" class="slot-image">
          <template #error><div class="image-placeholder"><el-icon><Picture /></el-icon></div></template>
        </el-image>
        <div class="slot-info">
          <div class="slot-header">
            <span class="user-name">{{ item.userNickname || '用户' }}</span>
            <el-tag :type="getStatusColor(item.reviewStatus)" size="small">{{ getStatusLabel(item.reviewStatus) }}</el-tag>
          </div>
          <div class="slot-meta">
            <span><el-icon><Calendar /></el-icon> {{ item.displayDate }}</span>
            <span>展位 #{{ item.slotNumber }}</span>
          </div>
        </div>
      </el-card>
      <el-empty v-if="!loading && slots.length === 0" description="暂无待审核内容" />
    </div>
    
    <el-pagination v-if="total > 20" v-model:current-page="currentPage" :page-size="20" :total="total" layout="total, prev, pager, next" @current-change="fetchSlots" class="pagination" />
    
    <!-- 审核详情弹窗 -->
    <el-dialog v-model="detailVisible" title="审核详情" width="550px" v-if="currentSlot">
      <div class="review-content">
        <el-image :src="currentSlot.imageUrl" fit="contain" class="review-image">
          <template #error><div class="image-placeholder large"><el-icon><Picture /></el-icon></div></template>
        </el-image>
        <el-descriptions :column="2" border>
          <el-descriptions-item label="用户">{{ currentSlot.userNickname || '未知' }}</el-descriptions-item>
          <el-descriptions-item label="展示日期">{{ currentSlot.displayDate }}</el-descriptions-item>
          <el-descriptions-item label="展位号">{{ currentSlot.slotNumber }}</el-descriptions-item>
          <el-descriptions-item label="提交时间">{{ formatDate(currentSlot.createdAt) }}</el-descriptions-item>
          <el-descriptions-item label="祝福语" :span="2">{{ currentSlot.message || '无' }}</el-descriptions-item>
        </el-descriptions>
      </div>
      <template #footer v-if="currentSlot.reviewStatus === 'PENDING'">
        <el-button type="danger" :icon="Close" @click="handleReject(currentSlot.id)">驳回</el-button>
        <el-button type="success" :icon="Check" @click="handleApprove(currentSlot.id)">通过</el-button>
      </template>
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
.slots-grid {
  display: grid; grid-template-columns: repeat(auto-fill, minmax(250px, 1fr)); gap: 20px;
}
.slot-card {
  cursor: pointer; transition: all 0.3s; background: var(--bg-card);
  &:hover { transform: translateY(-4px); }
  .slot-image { width: 100%; height: 200px; border-radius: 8px 8px 0 0; }
  .image-placeholder { width: 100%; height: 200px; display: flex; align-items: center; justify-content: center; font-size: 48px; background: var(--bg-card); }
  .slot-info { padding: 12px;
    .slot-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;
      .user-name { font-weight: 500; }
    }
    .slot-meta { font-size: 12px; color: var(--text-secondary); display: flex; gap: 12px; }
  }
}
.pagination { margin-top: 20px; justify-content: flex-end; }
.review-content {
  .review-image { width: 100%; max-height: 300px; border-radius: 8px; margin-bottom: 20px; }
  .image-placeholder.large { height: 200px; font-size: 64px; }
}
</style>
