<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { Search, Refresh, Document, Picture, Star, View, StarFilled } from '@element-plus/icons-vue'
import request from '@/utils/request'

const loading = ref(false)
const logs = ref<any[]>([])
const total = ref(0)
const currentPage = ref(1)
const pageSize = ref(20)
const keyword = ref('')

const fetchLogs = async () => {
  loading.value = true
  try {
    const params: any = { page: currentPage.value - 1, size: pageSize.value }
    if (keyword.value) params.keyword = keyword.value
    
    const res = await request.get('/bird-logs', { params })
    if (res.code === 0) {
      logs.value = res.data.content
      total.value = res.data.totalElements
    }
  } catch (e) { console.error(e) }
  finally { loading.value = false }
}

const handleSearch = () => { currentPage.value = 1; fetchLogs() }
const handlePageChange = (page: number) => { currentPage.value = page; fetchLogs() }

const formatDate = (dateStr: string) => {
  if (!dateStr) return '-'
  const d = new Date(dateStr)
  return `${d.getFullYear()}/${(d.getMonth()+1).toString().padStart(2,'0')}/${d.getDate().toString().padStart(2,'0')} ${d.getHours().toString().padStart(2,'0')}:${d.getMinutes().toString().padStart(2,'0')}`
}

// 构建日志摘要信息
const getLogSummary = (row: any) => {
  const parts: string[] = []
  if (row.weight != null) parts.push(`体重: ${row.weight}g`)
  if (row.mood) parts.push(`心情: ${row.mood}`)
  if (row.behavior) parts.push(`行为: ${row.behavior}`)
  if (row.healthScore != null) parts.push(`健康评分: ${row.healthScore}`)
  if (row.notes) parts.push(row.notes)
  return parts.join(' · ') || '-'
}

// 判定日志类型（从数据字段推断）
const getLogType = (row: any) => {
  if (row.weight != null) return { label: '体重', color: 'success' as const }
  if (row.mood) return { label: '心情', color: 'warning' as const }
  if (row.behavior) return { label: '行为', color: '' as const }
  if (row.healthScore != null) return { label: '健康', color: 'danger' as const }
  if (row.notes) return { label: '笔记', color: 'info' as const }
  return { label: '日志', color: 'info' as const }
}

onMounted(() => { fetchLogs() })
</script>

<template>
  <div class="page-container">
    <div class="page-header">
      <div class="header-info">
        <h2><el-icon><Document /></el-icon> 饲养日志</h2>
        <p>查看用户记录的鸟儿饲养日志，共 {{ total }} 条记录</p>
      </div>
      <button class="tech-btn" @click="fetchLogs">
        <el-icon><Refresh /></el-icon>
        <span>刷新</span>
      </button>
    </div>
    
    <div class="search-panel glass-panel">
      <el-form :inline="true">
        <el-form-item label="关键词">
          <el-input v-model="keyword" placeholder="鸟儿名/内容" clearable @keyup.enter="handleSearch" style="width: 200px;" />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" :icon="Search" @click="handleSearch">搜索</el-button>
          <el-button @click="keyword = ''; handleSearch()">重置</el-button>
        </el-form-item>
      </el-form>
    </div>
    
    <div class="table-panel glass-panel">
      <el-table :data="logs" v-loading="loading" stripe>
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column label="鸟儿" min-width="180">
          <template #default="{ row }">
            <div class="bird-info">
              <el-avatar :src="row.birdAvatarUrl" :size="36" shape="square">
                <span><el-icon><Picture /></el-icon></span>
              </el-avatar>
              <div class="bird-detail">
                <span class="bird-name">{{ row.birdNickname || '-' }}</span>
                <span class="bird-species" v-if="row.birdSpecies">{{ row.birdSpecies }}</span>
              </div>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="类型" width="90">
          <template #default="{ row }">
            <el-tag :type="getLogType(row).color" size="small">{{ getLogType(row).label }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="详情" min-width="250">
          <template #default="{ row }">
            <div class="log-detail">
              <span v-if="row.weight != null" class="detail-item weight">
                <el-icon><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" width="14" height="14"><path d="M12 3a4 4 0 014 4c0 .73-.19 1.41-.54 2H18a2 2 0 012 2v9a2 2 0 01-2 2H6a2 2 0 01-2-2v-9c0-1.1.9-2 2-2h2.54A3.96 3.96 0 018 7a4 4 0 014-4zm0 2a2 2 0 100 4 2 2 0 000-4z"/></svg></el-icon>
                {{ row.weight }}g
              </span>
              <span v-if="row.mood" class="detail-item mood"><el-icon><Star /></el-icon> {{ row.mood }}</span>
              <span v-if="row.behavior" class="detail-item behavior"><el-icon><View /></el-icon> {{ row.behavior }}</span>
              <span v-if="row.healthScore != null" class="detail-item health"><el-icon><StarFilled /></el-icon> {{ row.healthScore }}分</span>
              <span v-if="row.notes" class="detail-item notes">{{ row.notes }}</span>
              <span v-if="!row.weight && !row.mood && !row.behavior && !row.healthScore && !row.notes" class="detail-item empty">-</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="记录日期" width="140">
          <template #default="{ row }">
            <span class="log-date">{{ formatDate(row.logDate) }}</span>
          </template>
        </el-table-column>
        <el-table-column label="创建时间" width="140">
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
    </div>
  </div>
</template>

<style lang="scss" scoped>
.page-container { padding: 24px; color: var(--text-primary); }

.glass-panel {
  background: var(--bg-card);
  backdrop-filter: blur(12px);
  border: 1px solid var(--border-light);
  border-radius: 16px;
  padding: 20px 24px;
  box-shadow: var(--shadow-md);
}

.page-header {
  display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px;
  .header-info {
    h2 { margin: 0 0 4px; color: var(--text-primary); font-size: 24px; font-weight: 600; }
    p { margin: 0; color: var(--text-secondary); font-size: 14px; }
  }
}

.tech-btn {
  background: var(--primary-subtle);
  border: 1px solid rgba(16, 185, 129, 0.3);
  color: var(--primary-color);
  padding: 8px 16px;
  border-radius: 8px;
  display: flex;
  align-items: center;
  gap: 8px;
  cursor: pointer;
  transition: all 0.3s ease;
  font-size: 14px;
  &:hover {
    background: rgba(16, 185, 129, 0.2);
    box-shadow: 0 0 12px rgba(16, 185, 129, 0.3);
    transform: translateY(-1px);
    border-color: var(--primary-color);
  }
}

.search-panel { margin-bottom: 20px; }

.bird-info { 
  display: flex; 
  align-items: center; 
  gap: 10px; 
  .bird-detail {
    display: flex;
    flex-direction: column;
    .bird-name { font-weight: 500; color: var(--text-primary); }
    .bird-species { font-size: 12px; color: var(--text-secondary); }
  }
}

.log-detail {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  align-items: center;
  
  .detail-item {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    font-size: 13px;
    
    &.weight {
      color: var(--primary-color);
      font-weight: 600;
      background: rgba(16, 185, 129, 0.1);
      padding: 2px 8px;
      border-radius: 6px;
    }
    &.mood { color: #F59E0B; }
    &.behavior { color: #60A5FA; }
    &.health { color: #EC4899; }
    &.notes { color: var(--text-secondary); }
    &.empty { color: var(--text-placeholder); }
  }
}

.log-date {
  color: var(--text-secondary);
  font-size: 13px;
}

.pagination { margin-top: 20px; justify-content: flex-end; }
</style>
