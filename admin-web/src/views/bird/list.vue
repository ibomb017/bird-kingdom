<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { Search, Refresh, View, Notebook } from '@element-plus/icons-vue'
import request from '@/utils/request'

const loading = ref(false)
const birds = ref<any[]>([])
const total = ref(0)
const currentPage = ref(1)
const pageSize = ref(20)
const keyword = ref('')
const status = ref('')

// 详情弹窗
const detailVisible = ref(false)
const currentBird = ref<any>(null)
const detailLoading = ref(false)

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
  } catch (e) { console.error(e) }
  finally { loading.value = false }
}

const handleSearch = () => { currentPage.value = 1; fetchBirds() }
const handlePageChange = (page: number) => { currentPage.value = page; fetchBirds() }

const showDetail = async (id: number) => {
  detailLoading.value = true
  detailVisible.value = true
  try {
    const res = await request.get(`/birds/${id}`)
    if (res.code === 0) {
      currentBird.value = res.data
    }
  } catch (e) { console.error(e) }
  finally { detailLoading.value = false }
}

const formatDate = (dateStr: string) => dateStr ? new Date(dateStr).toLocaleDateString('zh-CN') : '-'

const getGenderLabel = (gender: string) => {
  const map: Record<string, string> = { 'male': '公', 'female': '母', 'unknown': '未知' }
  return map[gender] || gender || '未知'
}

const getAge = (hatchDate: string) => {
  if (!hatchDate) return '-'
  const birth = new Date(hatchDate)
  const now = new Date()
  const months = (now.getFullYear() - birth.getFullYear()) * 12 + (now.getMonth() - birth.getMonth())
  if (months < 1) return '不足1个月'
  if (months < 12) return `${months}个月`
  const years = Math.floor(months / 12)
  const remainMonths = months % 12
  return remainMonths > 0 ? `${years}岁${remainMonths}个月` : `${years}岁`
}

onMounted(() => { fetchBirds() })
</script>

<template>
  <div class="page-container">
    <div class="page-header">
      <div>
        <h2>
          <el-icon><Notebook /></el-icon>
          鸟档案管理
        </h2>
        <p>查看平台所有用户创建的鸟儿档案</p>
      </div>
      <el-button :icon="Refresh" @click="fetchBirds">刷新</el-button>
    </div>
    
    <el-card class="search-card">
      <el-form :inline="true">
        <el-form-item label="关键词">
          <el-input v-model="keyword" placeholder="昵称/品种" clearable @keyup.enter="handleSearch" style="width: 180px;" />
        </el-form-item>
        <el-form-item label="状态">
          <el-select v-model="status" placeholder="全部" clearable style="width: 120px;">
            <el-option label="全部" value="" />
            <el-option label="正常" value="normal" />
            <el-option label="走失中" value="lost" />
            <el-option label="已删除" value="deleted" />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button type="primary" :icon="Search" @click="handleSearch">搜索</el-button>
          <el-button @click="keyword = ''; status = ''; handleSearch()">重置</el-button>
        </el-form-item>
      </el-form>
    </el-card>
    
    <el-card class="table-card">
      <el-table :data="birds" v-loading="loading" stripe>
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column label="鸟儿信息" min-width="220">
          <template #default="{ row }">
            <div class="bird-info">
              <el-avatar :src="row.avatarUrl" :size="50" shape="square">{{ row.nickname?.charAt(0) }}</el-avatar>
              <div class="bird-detail">
                <span class="nickname">{{ row.nickname }}</span>
                <span class="species">{{ row.species }}</span>
              </div>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="性别" width="80">
          <template #default="{ row }">
            <span class="gender-text">{{ getGenderLabel(row.gender) }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="featherColor" label="羽色" width="100">
          <template #default="{ row }">{{ row.featherColor || '-' }}</template>
        </el-table-column>
        <el-table-column label="年龄" width="110">
          <template #default="{ row }">{{ getAge(row.hatchDate) }}</template>
        </el-table-column>
        <el-table-column label="主人" width="120">
          <template #default="{ row }">{{ row.ownerNickname || '-' }}</template>
        </el-table-column>
        <el-table-column label="状态" width="100">
          <template #default="{ row }">
            <span :class="['status-text', row.isLost ? 'lost' : row.isDeleted ? 'deleted' : 'normal']">
              {{ row.isLost ? '走失' : row.isDeleted ? '已删除' : '正常' }}
            </span>
          </template>
        </el-table-column>
        <el-table-column label="创建时间" width="110">
          <template #default="{ row }">
            <span class="time-text">{{ formatDate(row.createdAt) }}</span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="80" fixed="right">
          <template #default="{ row }">
            <el-button type="primary" link size="small" @click="showDetail(row.id)">详情</el-button>
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
    
    <!-- 详情弹窗 -->
    <el-dialog v-model="detailVisible" title="鸟儿详情" width="550px">
      <div v-loading="detailLoading">
        <template v-if="currentBird">
          <div class="bird-detail-header">
            <el-avatar :src="currentBird.avatarUrl" :size="80" shape="square">{{ currentBird.nickname?.charAt(0) }}</el-avatar>
            <div class="bird-title">
              <h3>{{ currentBird.nickname }}</h3>
              <span class="species-label">{{ currentBird.species }}</span>
            </div>
          </div>
          <el-descriptions :column="2" border>
            <el-descriptions-item label="ID">{{ currentBird.id }}</el-descriptions-item>
            <el-descriptions-item label="性别">{{ getGenderLabel(currentBird.gender) }}</el-descriptions-item>
            <el-descriptions-item label="羽色">{{ currentBird.featherColor || '-' }}</el-descriptions-item>
            <el-descriptions-item label="年龄">{{ getAge(currentBird.hatchDate) }}</el-descriptions-item>
            <el-descriptions-item label="出生日期">{{ formatDate(currentBird.hatchDate) }}</el-descriptions-item>
            <el-descriptions-item label="体重">{{ currentBird.weight ? currentBird.weight + 'g' : '-' }}</el-descriptions-item>
            <el-descriptions-item label="主人">{{ currentBird.ownerNickname || '-' }}</el-descriptions-item>
            <el-descriptions-item label="主人ID">{{ currentBird.userId }}</el-descriptions-item>
            <el-descriptions-item label="创建时间" :span="2">{{ formatDate(currentBird.createdAt) }}</el-descriptions-item>
            <el-descriptions-item label="状态" :span="2">
              <span :class="['status-text', currentBird.isLost ? 'lost' : currentBird.isDeleted ? 'deleted' : 'normal']">
                {{ currentBird.isLost ? '走失中' : currentBird.isDeleted ? '已删除' : '正常' }}
              </span>
            </el-descriptions-item>
          </el-descriptions>
        </template>
      </div>
      <template #footer>
        <el-button @click="detailVisible = false">关闭</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style lang="scss" scoped>
.bird-info {
  display: flex;
  align-items: center;
  gap: 12px;
  
  .el-avatar {
    border: 2px solid var(--border-lighter);
    flex-shrink: 0;
  }
  
  .bird-detail {
    display: flex;
    flex-direction: column;
    min-width: 0;
    
    .nickname {
      font-weight: 600;
      color: var(--text-primary);
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    
    .species {
      font-size: 12px;
      color: var(--text-secondary);
    }
  }
}

.gender-text {
  color: var(--text-primary);
}

.status-text {
  font-size: 13px;
  
  &.normal {
    color: var(--primary-color);
  }
  
  &.lost {
    color: var(--warning-color);
  }
  
  &.deleted {
    color: var(--text-disabled);
  }
}

.time-text {
  font-size: 13px;
  color: var(--text-secondary);
}

.bird-detail-header {
  display: flex;
  align-items: center;
  gap: 20px;
  padding-bottom: 20px;
  margin-bottom: 20px;
  border-bottom: 1px solid var(--border-lighter);
  
  .el-avatar {
    border: 2px solid var(--border-lighter);
  }
  
  .bird-title {
    h3 {
      margin: 0 0 8px;
      font-size: 20px;
      color: var(--text-primary);
    }
    
    .species-label {
      display: inline-block;
      padding: 4px 12px;
      background: var(--primary-subtle);
      color: var(--primary-color);
      border-radius: 20px;
      font-size: 12px;
    }
  }
}
</style>
