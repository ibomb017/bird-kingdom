<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { Search, Refresh, View } from '@element-plus/icons-vue'
import request from '@/utils/request'

const loading = ref(false)
const birds = ref<any[]>([])
const total = ref(0)
const currentPage = ref(1)
const pageSize = ref(20)
const keyword = ref('')
const status = ref('')

const fetchBirds = async () => {
  loading.value = true
  try {
    const params: any = { page: currentPage.value - 1, size: pageSize.value }
    if (keyword.value) params.keyword = keyword.value
    if (status.value) params.status = status.value
    
    const res = await request.get('/birds', { params })
    if (res.code === 0) {
      birds.value = res.data.content
      total.value = res.data.totalElements
    }
  } catch (e) {
    console.error(e)
  } finally {
    loading.value = false
  }
}

const handleSearch = () => {
  currentPage.value = 1
  fetchBirds()
}

const handlePageChange = (page: number) => {
  currentPage.value = page
  fetchBirds()
}

const formatDate = (dateStr: string) => {
  if (!dateStr) return '-'
  return new Date(dateStr).toLocaleDateString('zh-CN')
}

const getGenderLabel = (gender: string) => {
  const map: Record<string, string> = { 'male': '公', 'female': '母', 'unknown': '未知' }
  return map[gender] || gender || '未知'
}

onMounted(() => { fetchBirds() })
</script>

<template>
  <div class="page-container">
    <div class="page-header">
      <h2>鸟档案管理</h2>
      <p>查看平台所有用户创建的鸟儿档案</p>
    </div>
    
    <el-card class="search-card">
      <el-form :inline="true">
        <el-form-item label="关键词">
          <el-input v-model="keyword" placeholder="昵称/品种" clearable @keyup.enter="handleSearch" />
        </el-form-item>
        <el-form-item label="状态">
          <el-select v-model="status" placeholder="全部" clearable>
            <el-option label="正常" value="" />
            <el-option label="已删除" value="deleted" />
            <el-option label="走失中" value="lost" />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button type="primary" :icon="Search" @click="handleSearch">搜索</el-button>
          <el-button :icon="Refresh" @click="keyword = ''; status = ''; handleSearch()">重置</el-button>
        </el-form-item>
      </el-form>
    </el-card>
    
    <el-card class="table-card">
      <el-table :data="birds" v-loading="loading" stripe>
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column label="鸟儿" min-width="200">
          <template #default="{ row }">
            <div class="bird-info">
              <el-avatar :src="row.avatarUrl" :size="40"></el-avatar>
              <div class="bird-detail">
                <span class="nickname">{{ row.nickname }}</span>
                <span class="species">{{ row.species }}</span>
              </div>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="性别" width="80">
          <template #default="{ row }">{{ getGenderLabel(row.gender) }}</template>
        </el-table-column>
        <el-table-column prop="featherColor" label="羽色" width="100" />
        <el-table-column label="主人" width="120">
          <template #default="{ row }">{{ row.ownerNickname || '-' }}</template>
        </el-table-column>
        <el-table-column label="出生日期" width="120">
          <template #default="{ row }">{{ formatDate(row.hatchDate) }}</template>
        </el-table-column>
        <el-table-column label="状态" width="100">
          <template #default="{ row }">
            <el-tag v-if="row.isLost" type="danger" size="small">走失</el-tag>
            <el-tag v-else-if="row.isDeleted" type="info" size="small">已删除</el-tag>
            <el-tag v-else type="success" size="small">正常</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="100" fixed="right">
          <template #default="{ row }">
            <el-button type="primary" link :icon="View">详情</el-button>
          </template>
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
.search-card { margin-bottom: 20px; }
.table-card { background: var(--bg-card); }
.bird-info {
  display: flex;
  align-items: center;
  gap: 12px;
  .bird-detail {
    display: flex;
    flex-direction: column;
    .nickname { font-weight: 500; }
    .species { font-size: 12px; color: var(--text-secondary); }
  }
}
.pagination { margin-top: 20px; justify-content: flex-end; }
</style>
