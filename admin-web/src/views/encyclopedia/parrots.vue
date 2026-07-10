<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { Search, Refresh } from '@element-plus/icons-vue'
import request from '@/utils/request'

const loading = ref(false)
const parrots = ref<any[]>([])
const total = ref(0)
const currentPage = ref(1)
const keyword = ref('')
const category = ref('')
const categories = ref<any[]>([])

const fetchParrots = async () => {
  loading.value = true
  try {
    const params: any = { page: currentPage.value - 1, size: 20 }
    if (keyword.value) params.keyword = keyword.value
    if (category.value) params.category = category.value
    
    const res = await request.get('/encyclopedia/parrots', { params })
    if (res.code === 0) {
      parrots.value = res.data.content
      total.value = res.data.totalElements
    }
  } catch (e) { console.error(e) }
  finally { loading.value = false }
}

const loadCategories = async () => {
  try {
    const res = await request.get('/encyclopedia/parrots/categories')
    if (res.code === 0) {
      categories.value = res.data
    }
  } catch (e) { console.error(e) }
}

const handleSearch = () => { currentPage.value = 1; fetchParrots() }

const formatWeight = (min: number, max: number) => {
  if (!min && !max) return '-'
  if (min === max) return `${min}g`
  return `${min || '?'} - ${max || '?'}g`
}

onMounted(() => { fetchParrots(); loadCategories() })
</script>

<template>
  <div class="page-container">
    <div class="page-header">
      <div>
        <h2> 鹦鹉品种库</h2>
        <p>鹦鹉专属品种库，包含体重、繁殖周期等数据</p>
      </div>
      <el-button :icon="Refresh" @click="fetchParrots">刷新</el-button>
    </div>
    
    <el-card class="search-card">
      <el-form :inline="true">
        <el-form-item label="搜索">
          <el-input v-model="keyword" placeholder="品种名称" clearable @keyup.enter="handleSearch" style="width: 180px;" />
        </el-form-item>
        <el-form-item label="分类">
          <el-select v-model="category" placeholder="全部" clearable @change="handleSearch" style="width: 140px;">
            <el-option label="全部" value="" />
            <el-option v-for="c in categories" :key="c.category" :label="`${c.category} (${c.count})`" :value="c.category" />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button type="primary" :icon="Search" @click="handleSearch">搜索</el-button>
        </el-form-item>
      </el-form>
    </el-card>
    
    <el-card class="table-card">
      <el-table :data="parrots" v-loading="loading" stripe>
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column prop="name" label="品种名称" min-width="150" />
        <el-table-column prop="category" label="分类" width="120">
          <template #default="{ row }">
            <el-tag size="small">{{ row.category }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="体重范围" width="130">
          <template #default="{ row }">{{ formatWeight(row.weightMin, row.weightMax) }}</template>
        </el-table-column>
        <el-table-column label="孵化期" width="100">
          <template #default="{ row }">{{ row.incubationDays ? `${row.incubationDays}天` : '-' }}</template>
        </el-table-column>
        <el-table-column label="每窝蛋数" width="100">
          <template #default="{ row }">
            {{ row.clutchSizeMin && row.clutchSizeMax ? `${row.clutchSizeMin}-${row.clutchSizeMax}枚` : '-' }}
          </template>
        </el-table-column>
        <el-table-column label="换羽期" width="120">
          <template #default="{ row }">
            {{ row.moltingDurationMin && row.moltingDurationMax ? `${row.moltingDurationMin}-${row.moltingDurationMax}天` : '-' }}
          </template>
        </el-table-column>
      </el-table>
      
      <el-pagination v-model:current-page="currentPage" :page-size="20" :total="total" 
        layout="total, prev, pager, next" @current-change="fetchParrots" class="pagination" />
    </el-card>
    
    <el-empty v-if="!loading && parrots.length === 0" description="暂无鹦鹉品种数据" />
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
.table-card { 
  background: var(--bg-card); 
  border: 1px solid var(--border-light);
}
.pagination { margin-top: 20px; justify-content: flex-end; }
</style>
