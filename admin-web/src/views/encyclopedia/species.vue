<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { Search, Refresh } from '@element-plus/icons-vue'
import request from '@/utils/request'

const loading = ref(false)
const species = ref<any[]>([])
const total = ref(0)
const currentPage = ref(1)
const keyword = ref('')
const category = ref('')

// 详情弹窗
const detailVisible = ref(false)
const currentSpecies = ref<any>(null)

const fetchSpecies = async () => {
  loading.value = true
  try {
    const params: any = { page: currentPage.value - 1, size: 20 }
    if (keyword.value) params.keyword = keyword.value
    if (category.value) params.category = category.value
    
    const res = await request.get('/encyclopedia/species', { params })
    if (res.code === 0) {
      species.value = res.data.content
      total.value = res.data.totalElements
    }
  } catch (e) { console.error(e) }
  finally { loading.value = false }
}

const handleSearch = () => { currentPage.value = 1; fetchSpecies() }
const handlePageChange = (page: number) => { currentPage.value = page; fetchSpecies() }

const showDetail = (item: any) => {
  currentSpecies.value = item
  detailVisible.value = true
}

onMounted(() => { fetchSpecies() })
</script>

<template>
  <div class="page-container">
    <div class="page-header">
      <div>
        <h2> 品种知识库</h2>
        <p>管理鸟类品种百科数据</p>
      </div>
      <el-button :icon="Refresh" @click="fetchSpecies">刷新</el-button>
    </div>
    
    <el-card class="search-card">
      <el-form :inline="true">
        <el-form-item label="关键词">
          <el-input v-model="keyword" placeholder="品种名称" clearable @keyup.enter="handleSearch" style="width: 180px;" />
        </el-form-item>
        <el-form-item label="分类">
          <el-select v-model="category" placeholder="全部" clearable style="width: 140px;">
            <el-option label="全部" value="" />
            <el-option label="鹦鹉" value="鹦鹉" />
            <el-option label="雀类" value="雀类" />
            <el-option label="观赏鸟" value="观赏鸟" />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button type="primary" :icon="Search" @click="handleSearch">搜索</el-button>
          <el-button @click="keyword = ''; category = ''; handleSearch()">重置</el-button>
        </el-form-item>
      </el-form>
    </el-card>
    
    <div class="species-grid" v-loading="loading">
      <el-card v-for="item in species" :key="item.id" class="species-card" shadow="hover" @click="showDetail(item)">
        <el-image :src="item.coverImageUrl || item.imageUrl" fit="cover" class="species-image">
          <template #error><div class="image-placeholder"></div></template>
        </el-image>
        <div class="species-info">
          <h4>{{ item.name }}</h4>
          <el-tag size="small" type="info">{{ item.category }}</el-tag>
          <p class="species-desc">{{ item.description?.substring(0, 50) }}...</p>
        </div>
      </el-card>
      <el-empty v-if="!loading && species.length === 0" description="暂无数据" />
    </div>
    
    <el-pagination v-if="total > 20" v-model:current-page="currentPage" :page-size="20" :total="total" layout="total, prev, pager, next" @current-change="handlePageChange" class="pagination" />
    
    <!-- 详情弹窗 -->
    <el-dialog v-model="detailVisible" :title="currentSpecies?.name" width="650px" v-if="currentSpecies">
      <div class="species-detail">
        <el-image :src="currentSpecies.coverImageUrl || currentSpecies.imageUrl" fit="cover" class="detail-image">
          <template #error><div class="image-placeholder large"></div></template>
        </el-image>
        <el-descriptions :column="2" border>
          <el-descriptions-item label="ID">{{ currentSpecies.id }}</el-descriptions-item>
          <el-descriptions-item label="分类">{{ currentSpecies.category }}</el-descriptions-item>
          <el-descriptions-item label="体长">{{ currentSpecies.bodyLengthRange || '-' }}</el-descriptions-item>
          <el-descriptions-item label="体重">{{ currentSpecies.weightRange || '-' }}</el-descriptions-item>
          <el-descriptions-item label="价格区间" :span="2">¥{{ currentSpecies.priceMin || 0 }} - ¥{{ currentSpecies.priceMax || 0 }}</el-descriptions-item>
          <el-descriptions-item label="标签" :span="2">
            <el-tag v-for="tag in (currentSpecies.tags?.split(',') || [])" :key="tag" size="small" style="margin: 2px;">{{ tag }}</el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="简介" :span="2">{{ currentSpecies.description || '暂无' }}</el-descriptions-item>
        </el-descriptions>
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
.search-card { 
  margin-bottom: 20px; 
  background: var(--bg-card);
  border: 1px solid var(--border-light);
}
.species-grid {
  display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap: 20px;
}
.species-card {
  cursor: pointer; 
  transition: all 0.3s; 
  background: var(--bg-card);
  border: 1px solid var(--border-light);
  
  &:hover { 
    transform: translateY(-4px); 
    border-color: var(--primary-color);
    box-shadow: var(--shadow-glow);
  }
  .species-image { width: 100%; height: 150px; border-radius: 8px 8px 0 0; }
  .image-placeholder { 
    width: 100%; height: 150px; display: flex; align-items: center; justify-content: center; 
    font-size: 48px; background: var(--bg-elevated); color: var(--text-placeholder);
  }
  .species-info { 
    padding: 12px;
    h4 { margin: 0 0 8px; font-size: 16px; color: var(--text-primary); }
    .species-desc { margin: 8px 0 0; font-size: 12px; color: var(--text-secondary); line-height: 1.4; }
  }
}
.pagination { margin-top: 20px; justify-content: flex-end; }
.species-detail {
  .detail-image { width: 100%; height: 200px; border-radius: 8px; margin-bottom: 20px; }
  .image-placeholder.large { height: 200px; font-size: 64px; }
}
</style>
