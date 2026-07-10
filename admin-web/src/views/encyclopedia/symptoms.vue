<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { Search, Refresh, FirstAid } from '@element-plus/icons-vue'
import request from '@/utils/request'

const loading = ref(false)
const symptoms = ref<any[]>([])
const total = ref(0)
const currentPage = ref(1)
const keyword = ref('')
const severity = ref('')

// 详情弹窗
const detailVisible = ref(false)
const currentSymptom = ref<any>(null)

const fetchSymptoms = async () => {
  loading.value = true
  try {
    const params: any = { page: currentPage.value - 1, size: 20 }
    if (keyword.value) params.keyword = keyword.value
    if (severity.value) params.severity = severity.value
    
    const res = await request.get('/encyclopedia/symptoms', { params })
    if (res.code === 0) {
      symptoms.value = res.data.content
      total.value = res.data.totalElements
    }
  } catch (e) { console.error(e) }
  finally { loading.value = false }
}

const handleSearch = () => { currentPage.value = 1; fetchSymptoms() }
const handlePageChange = (page: number) => { currentPage.value = page; fetchSymptoms() }

const showDetail = (item: any) => {
  currentSymptom.value = item
  detailVisible.value = true
}

const getSeverityLabel = (level: string) => {
  const map: Record<string, string> = { 'LOW': '轻微', 'MEDIUM': '中等', 'HIGH': '严重', 'CRITICAL': '紧急' }
  return map[level] || level || '-'
}

const getSeverityColor = (level: string): '' | 'success' | 'warning' | 'danger' => {
  const map: Record<string, '' | 'success' | 'warning' | 'danger'> = { 'LOW': 'success', 'MEDIUM': 'warning', 'HIGH': 'danger', 'CRITICAL': 'danger' }
  return map[level] || 'info'
}

onMounted(() => { fetchSymptoms() })
</script>

<template>
  <div class="page-container">
    <div class="page-header">
      <div>
        <h2><el-icon><FirstAid /></el-icon> 症状速查</h2>
        <p>管理鸟类常见症状及处理方法</p>
      </div>
      <el-button :icon="Refresh" @click="fetchSymptoms">刷新</el-button>
    </div>
    
    <el-card class="search-card">
      <el-form :inline="true">
        <el-form-item label="关键词">
          <el-input v-model="keyword" placeholder="症状名称" clearable @keyup.enter="handleSearch" style="width: 180px;" />
        </el-form-item>
        <el-form-item label="严重程度">
          <el-select v-model="severity" placeholder="全部" clearable style="width: 120px;">
            <el-option label="全部" value="" />
            <el-option label="轻微" value="LOW" />
            <el-option label="中等" value="MEDIUM" />
            <el-option label="严重" value="HIGH" />
            <el-option label="紧急" value="CRITICAL" />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button type="primary" :icon="Search" @click="handleSearch">搜索</el-button>
          <el-button @click="keyword = ''; severity = ''; handleSearch()">重置</el-button>
        </el-form-item>
      </el-form>
    </el-card>
    
    <div class="symptoms-grid" v-loading="loading">
      <el-card v-for="item in symptoms" :key="item.id" class="symptom-card" @click="showDetail(item)">
        <div class="symptom-header">
          <h4>{{ item.name }}</h4>
          <el-tag :type="getSeverityColor(item.severity)" size="small">{{ getSeverityLabel(item.severity) }}</el-tag>
        </div>
        <p class="symptom-desc">{{ item.description?.substring(0, 80) }}...</p>
        <div class="symptom-tags" v-if="item.relatedSymptoms">
          <el-tag v-for="tag in item.relatedSymptoms.split(',').slice(0, 3)" :key="tag" size="small" type="info" style="margin: 2px;">{{ tag }}</el-tag>
        </div>
      </el-card>
      <el-empty v-if="!loading && symptoms.length === 0" description="暂无数据" />
    </div>
    
    <el-pagination v-if="total > 20" v-model:current-page="currentPage" :page-size="20" :total="total" layout="total, prev, pager, next" @current-change="handlePageChange" class="pagination" />
    
    <!-- 详情弹窗 -->
    <el-dialog v-model="detailVisible" :title="currentSymptom?.name" width="600px" v-if="currentSymptom">
      <el-descriptions :column="1" border>
        <el-descriptions-item label="症状名称">{{ currentSymptom.name }}</el-descriptions-item>
        <el-descriptions-item label="严重程度"><el-tag :type="getSeverityColor(currentSymptom.severity)">{{ getSeverityLabel(currentSymptom.severity) }}</el-tag></el-descriptions-item>
        <el-descriptions-item label="症状描述">{{ currentSymptom.description || '暂无' }}</el-descriptions-item>
        <el-descriptions-item label="可能原因">{{ currentSymptom.possibleCauses || '暂无' }}</el-descriptions-item>
        <el-descriptions-item label="建议处理">{{ currentSymptom.suggestedActions || '暂无' }}</el-descriptions-item>
        <el-descriptions-item label="紧急程度提示">{{ currentSymptom.urgencyNote || '暂无' }}</el-descriptions-item>
      </el-descriptions>
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
.search-card { 
  margin-bottom: 20px; 
  background: var(--bg-card);
  border: 1px solid var(--border-light);
}
.symptoms-grid {
  display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 16px;
}
.symptom-card {
  background: var(--bg-card); 
  border: 1px solid var(--border-light);
  cursor: pointer; 
  transition: all 0.3s;
  
  &:hover { 
    transform: translateY(-4px); 
    border-color: var(--primary-color);
    box-shadow: var(--shadow-glow); 
  }
  .symptom-header { 
    display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px;
    h4 { margin: 0; color: var(--text-primary); }
  }
  .symptom-desc { 
    margin: 0 0 12px; font-size: 13px; color: var(--text-secondary); line-height: 1.5; 
  }
}
.pagination { margin-top: 20px; justify-content: flex-end; }
</style>
