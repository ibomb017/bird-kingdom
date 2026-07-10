<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Search, Refresh, Plus, Edit, Delete, View, Check, Close, Warning } from '@element-plus/icons-vue'
import request from '@/utils/request'

interface Food {
  id: number
  category: string
  foodName: string
  intro: string
  nutrition: string
  precautions: string
  safetyLevel: string
  status: number
}

const loading = ref(false)
const foods = ref<Food[]>([])
const total = ref(0)
const currentPage = ref(1)
const pageSize = ref(50)
const keyword = ref('')
const safetyLevel = ref('')

// 详情/编辑弹窗
const dialogVisible = ref(false)
const dialogMode = ref<'view' | 'create' | 'edit'>('view')
const currentFood = ref<Partial<Food>>({})
const formLoading = ref(false)

// 分类选项
const categories = ['水果', '蔬菜', '谷物', '坚果', '肉类', '蛋奶', '其他']
const safetyLevels = [
  { value: 'SAFE', label: '安全', color: 'var(--success-color)' },
  { value: 'CAUTION', label: '谨慎', color: 'var(--warning-color)' },
  { value: 'DANGER', label: '禁止', color: 'var(--danger-color)' }
]

const fetchFoods = async () => {
  loading.value = true
  try {
    const params: any = { page: currentPage.value - 1, size: pageSize.value }
    if (keyword.value) params.keyword = keyword.value
    if (safetyLevel.value) params.safetyLevel = safetyLevel.value
    
    const res = await request.get('/encyclopedia/foods', { params })
    if (res.code === 0) {
      foods.value = res.data.content
      total.value = res.data.totalElements
    }
  } catch (e) { console.error(e) }
  finally { loading.value = false }
}

const handleSearch = () => { currentPage.value = 1; fetchFoods() }
const handlePageChange = (page: number) => { currentPage.value = page; fetchFoods() }

// 查看详情
const showDetail = async (id: number) => {
  try {
    const res = await request.get(`/encyclopedia/foods/${id}`)
    if (res.code === 0) {
      currentFood.value = res.data
      dialogMode.value = 'view'
      dialogVisible.value = true
    }
  } catch (e) { console.error(e) }
}

// 新增食物
const showCreate = () => {
  currentFood.value = { category: '', foodName: '', intro: '', nutrition: '', precautions: '', safetyLevel: 'SAFE' }
  dialogMode.value = 'create'
  dialogVisible.value = true
}

// 编辑食物
const showEdit = async (id: number) => {
  try {
    const res = await request.get(`/encyclopedia/foods/${id}`)
    if (res.code === 0) {
      currentFood.value = res.data
      dialogMode.value = 'edit'
      dialogVisible.value = true
    }
  } catch (e) { console.error(e) }
}

// 保存食物
const handleSave = async () => {
  if (!currentFood.value.foodName || !currentFood.value.category || !currentFood.value.safetyLevel) {
    ElMessage.warning('请填写必填项')
    return
  }
  
  formLoading.value = true
  try {
    let res
    if (dialogMode.value === 'create') {
      res = await request.post('/encyclopedia/foods', currentFood.value)
    } else {
      res = await request.put(`/encyclopedia/foods/${currentFood.value.id}`, currentFood.value)
    }
    
    if (res.code === 0) {
      ElMessage.success(dialogMode.value === 'create' ? '创建成功' : '更新成功')
      dialogVisible.value = false
      fetchFoods()
    } else {
      ElMessage.error(res.message)
    }
  } catch (e) { ElMessage.error('操作失败') }
  finally { formLoading.value = false }
}

// 删除食物
const handleDelete = async (food: Food) => {
  await ElMessageBox.confirm(`确定删除「${food.foodName}」吗？此操作不可恢复。`, '删除确认', { 
    type: 'warning',
    confirmButtonText: '删除',
    cancelButtonText: '取消'
  })
  
  try {
    const res = await request.delete(`/encyclopedia/foods/${food.id}`)
    if (res.code === 0) {
      ElMessage.success('删除成功')
      fetchFoods()
    }
  } catch (e) { ElMessage.error('删除失败') }
}

const getSafetyInfo = (level: string) => {
  return safetyLevels.find(s => s.value === level) || { label: level, color: 'var(--text-secondary)' }
}

const dialogTitle = computed(() => {
  const titles = { view: '食物详情', create: '新增食物', edit: '编辑食物' }
  return titles[dialogMode.value]
})

onMounted(() => { fetchFoods() })
</script>

<template>
  <div class="page-container">
    <!-- 页面头部 -->
    <div class="page-header">
      <div class="header-info">
        <h2>
          <el-icon><Warning /></el-icon>
          食物安全库
        </h2>
        <p>管理鸟类可食用食物的安全等级与营养信息</p>
      </div>
      <div class="header-actions">
        <el-button @click="fetchFoods" :icon="Refresh">刷新</el-button>
        <el-button type="primary" @click="showCreate" :icon="Plus">新增食物</el-button>
      </div>
    </div>
    
    <!-- 搜索筛选 -->
    <div class="filter-bar">
      <el-input 
        v-model="keyword" 
        placeholder="搜索食物名称" 
        clearable 
        @keyup.enter="handleSearch"
        :prefix-icon="Search"
        class="search-input"
      />
      <el-select v-model="safetyLevel" placeholder="安全等级" clearable class="filter-select">
        <el-option label="全部等级" value="" />
        <el-option v-for="s in safetyLevels" :key="s.value" :label="s.label" :value="s.value" />
      </el-select>
      <el-button type="primary" @click="handleSearch" :icon="Search">搜索</el-button>
      <el-button @click="keyword = ''; safetyLevel = ''; handleSearch()">重置</el-button>
    </div>
    
    <!-- 数据表格 -->
    <div class="data-table" v-loading="loading">
      <el-table :data="foods" stripe style="width: 100%" :row-class-name="tableRowClassName">
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column prop="foodName" label="食物名称" min-width="140">
          <template #default="{ row }">
            <span class="food-name" @click="showDetail(row.id)">{{ row.foodName }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="category" label="分类" width="100" />
        <el-table-column label="安全等级" width="120">
          <template #default="{ row }">
            <div class="safety-badge" :style="{ '--badge-color': getSafetyInfo(row.safetyLevel).color }">
              <el-icon v-if="row.safetyLevel === 'SAFE'"><Check /></el-icon>
              <el-icon v-else-if="row.safetyLevel === 'CAUTION'"><Warning /></el-icon>
              <el-icon v-else><Close /></el-icon>
              {{ getSafetyInfo(row.safetyLevel).label }}
            </div>
          </template>
        </el-table-column>
        <el-table-column prop="intro" label="简介" min-width="300" show-overflow-tooltip>
          <template #default="{ row }">
            <span class="intro-text">{{ row.intro || '-' }}</span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="180" fixed="right">
          <template #default="{ row }">
            <div class="action-btns">
              <el-button type="primary" link size="small" @click="showDetail(row.id)" :icon="View">详情</el-button>
              <el-button type="primary" link size="small" @click="showEdit(row.id)" :icon="Edit">编辑</el-button>
              <el-button type="danger" link size="small" @click="handleDelete(row)" :icon="Delete">删除</el-button>
            </div>
          </template>
        </el-table-column>
      </el-table>
      
      <div class="pagination-wrapper">
        <el-pagination 
          v-model:current-page="currentPage" 
          :page-size="pageSize" 
          :total="total" 
          layout="total, prev, pager, next, jumper" 
          @current-change="handlePageChange"
        />
      </div>
    </div>
    
    <!-- 详情/编辑弹窗 -->
    <el-dialog 
      v-model="dialogVisible" 
      :title="dialogTitle" 
      width="680px"
      :close-on-click-modal="dialogMode === 'view'"
    >
      <div class="food-form" v-if="currentFood">
        <!-- 查看模式 -->
        <template v-if="dialogMode === 'view'">
          <div class="detail-header">
            <div class="safety-badge large" :style="{ '--badge-color': getSafetyInfo(currentFood.safetyLevel || '').color }">
              <el-icon v-if="currentFood.safetyLevel === 'SAFE'"><Check /></el-icon>
              <el-icon v-else-if="currentFood.safetyLevel === 'CAUTION'"><Warning /></el-icon>
              <el-icon v-else><Close /></el-icon>
              {{ getSafetyInfo(currentFood.safetyLevel || '').label }}
            </div>
            <div class="detail-title">
              <h3>{{ currentFood.foodName }}</h3>
              <span class="category-tag">{{ currentFood.category }}</span>
            </div>
          </div>
          
          <div class="detail-section">
            <h4>简介</h4>
            <p>{{ currentFood.intro || '暂无' }}</p>
          </div>
          
          <div class="detail-section">
            <h4>营养价值</h4>
            <p>{{ currentFood.nutrition || '暂无' }}</p>
          </div>
          
          <div class="detail-section">
            <h4>注意事项</h4>
            <p>{{ currentFood.precautions || '暂无' }}</p>
          </div>
        </template>
        
        <!-- 编辑/创建模式 -->
        <template v-else>
          <el-form :model="currentFood" label-width="100px" label-position="left">
            <el-form-item label="食物名称" required>
              <el-input v-model="currentFood.foodName" placeholder="请输入食物名称" />
            </el-form-item>
            <el-form-item label="分类" required>
              <el-select v-model="currentFood.category" placeholder="请选择分类" style="width: 100%">
                <el-option v-for="cat in categories" :key="cat" :label="cat" :value="cat" />
              </el-select>
            </el-form-item>
            <el-form-item label="安全等级" required>
              <el-radio-group v-model="currentFood.safetyLevel">
                <el-radio-button v-for="s in safetyLevels" :key="s.value" :value="s.value">
                  {{ s.label }}
                </el-radio-button>
              </el-radio-group>
            </el-form-item>
            <el-form-item label="简介">
              <el-input v-model="currentFood.intro" type="textarea" :rows="3" placeholder="请输入简介" />
            </el-form-item>
            <el-form-item label="营养价值">
              <el-input v-model="currentFood.nutrition" type="textarea" :rows="3" placeholder="请输入营养价值说明" />
            </el-form-item>
            <el-form-item label="注意事项">
              <el-input v-model="currentFood.precautions" type="textarea" :rows="3" placeholder="请输入注意事项" />
            </el-form-item>
          </el-form>
        </template>
      </div>
      
      <template #footer>
        <template v-if="dialogMode === 'view'">
          <el-button @click="dialogVisible = false">关闭</el-button>
          <el-button type="primary" @click="showEdit(currentFood.id!)">编辑</el-button>
        </template>
        <template v-else>
          <el-button @click="dialogVisible = false">取消</el-button>
          <el-button type="primary" @click="handleSave" :loading="formLoading">保存</el-button>
        </template>
      </template>
    </el-dialog>
  </div>
</template>

<style lang="scss" scoped>
.page-container {
  padding: 24px;
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 24px;
  
  .header-info {
    h2 {
      margin: 0 0 8px;
      color: var(--text-primary);
      font-size: 24px;
      font-weight: 600;
      display: flex;
      align-items: center;
      gap: 10px;
      
      .el-icon {
        color: var(--primary-color);
      }
    }
    
    p {
      margin: 0;
      color: var(--text-secondary);
      font-size: 14px;
    }
  }
  
  .header-actions {
    display: flex;
    gap: 12px;
  }
}

.filter-bar {
  display: flex;
  gap: 12px;
  margin-bottom: 20px;
  padding: 20px;
  background: var(--bg-card);
  border-radius: var(--radius-lg);
  border: 1px solid var(--border-lighter);
  
  .search-input {
    width: 280px;
  }
  
  .filter-select {
    width: 140px;
  }
}

.data-table {
  background: var(--bg-card);
  border-radius: var(--radius-lg);
  border: 1px solid var(--border-lighter);
  overflow: hidden;
  
  .el-table {
    --el-table-border-color: var(--border-lighter);
  }
  
  .food-name {
    color: var(--primary-color);
    cursor: pointer;
    font-weight: 500;
    transition: color 0.2s;
    
    &:hover {
      color: var(--primary-light);
    }
  }
  
  .intro-text {
    color: var(--text-secondary);
    font-size: 13px;
  }
  
  .action-btns {
    display: flex;
    gap: 4px;
  }
}

.safety-badge {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 4px 12px;
  border-radius: 20px;
  font-size: 13px;
  font-weight: 500;
  background: color-mix(in srgb, var(--badge-color) 15%, transparent);
  color: var(--badge-color);
  
  &.large {
    padding: 8px 16px;
    font-size: 14px;
  }
}

.pagination-wrapper {
  padding: 20px;
  display: flex;
  justify-content: flex-end;
}

// 弹窗样式
.food-form {
  .detail-header {
    display: flex;
    align-items: center;
    gap: 16px;
    margin-bottom: 24px;
    padding-bottom: 20px;
    border-bottom: 1px solid var(--border-lighter);
    
    .detail-title {
      h3 {
        margin: 0 0 8px;
        font-size: 20px;
        color: var(--text-primary);
      }
      
      .category-tag {
        padding: 4px 10px;
        background: var(--bg-content);
        border-radius: 4px;
        font-size: 12px;
        color: var(--text-secondary);
      }
    }
  }
  
  .detail-section {
    margin-bottom: 20px;
    
    h4 {
      margin: 0 0 10px;
      font-size: 14px;
      color: var(--text-secondary);
      font-weight: 500;
    }
    
    p {
      margin: 0;
      line-height: 1.7;
      color: var(--text-primary);
      white-space: pre-wrap;
    }
  }
}
</style>
