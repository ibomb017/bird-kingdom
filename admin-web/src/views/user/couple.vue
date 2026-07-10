<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { Refresh } from '@element-plus/icons-vue'
import request from '@/utils/request'

const loading = ref(false)
const couples = ref<any[]>([])
const total = ref(0)

const fetchCouples = async () => {
  loading.value = true
  try {
    const res = await request.get('/users/couples', { params: { page: 0, size: 50 } })
    if (res.code === 0) {
      couples.value = res.data.content
      total.value = res.data.totalElements
    }
  } catch (e) { console.error(e) }
  finally { loading.value = false }
}

const formatDate = (dateStr: string) => dateStr ? new Date(dateStr).toLocaleDateString('zh-CN') : '-'

onMounted(() => { fetchCouples() })
</script>

<template>
  <div class="page-container">
    <div class="page-header">
      <h2>情侣绑定</h2>
      <p>查看情侣账号绑定关系</p>
    </div>
    
    <el-card class="action-bar">
      <el-button :icon="Refresh" @click="fetchCouples">刷新</el-button>
    </el-card>
    
    <div v-if="couples.length === 0 && !loading" class="empty-state">
      <el-empty description="暂无情侣绑定数据" />
    </div>
    
    <div v-else class="couples-grid">
      <el-card v-for="item in couples" :key="item.id" class="couple-card">
        <div class="couple-pair">
          <div class="person">
            <el-avatar :src="item.avatarUrl" :size="60">{{ item.nickname?.charAt(0) }}</el-avatar>
            <span class="name">{{ item.nickname }}</span>
          </div>
          <div class="heart"></div>
          <div class="person">
            <el-avatar :src="item.partnerAvatarUrl" :size="60">{{ item.partnerNickname?.charAt(0) }}</el-avatar>
            <span class="name">{{ item.partnerNickname || '未知' }}</span>
          </div>
        </div>
        <div class="couple-info">
          <span>绑定时间: {{ formatDate(item.createdAt) }}</span>
        </div>
      </el-card>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.page-container { padding: 20px; }
.page-header { margin-bottom: 20px; h2 { margin: 0 0 8px; color: var(--text-primary); } p { margin: 0; color: var(--text-secondary); } }
.action-bar { margin-bottom: 20px; }
.empty-state { padding: 60px 0; text-align: center; }
.couples-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 20px; }
.couple-card {
  background: var(--bg-card);
  .couple-pair { display: flex; align-items: center; justify-content: center; gap: 20px; padding: 20px 0;
    .person { display: flex; flex-direction: column; align-items: center; gap: 8px; .name { font-weight: 500; } }
    .heart { font-size: 24px; }
  }
  .couple-info { text-align: center; padding-top: 12px; border-top: 1px solid rgba(255,255,255,0.1); font-size: 13px; color: var(--text-secondary); }
}
</style>
