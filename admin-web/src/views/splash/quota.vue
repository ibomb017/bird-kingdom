<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { Setting, Refresh } from '@element-plus/icons-vue'
import request from '@/utils/request'

const loading = ref(false)
const saving = ref(false)

const quotaConfig = ref({
  splashSlotsPerDay: 10,
  splashPrice: 99
})

const fetchConfig = async () => {
  loading.value = true
  try {
    const res = await request.get('/system/config')
    if (res.code === 0) {
      const data = res.data
      quotaConfig.value.splashSlotsPerDay = data.splashSlotsPerDay ?? 10
      quotaConfig.value.splashPrice = data.splashPrice ?? 99
    }
  } catch (e) {
    console.error('获取配置失败:', e)
  } finally {
    loading.value = false
  }
}

const saveConfig = async () => {
  saving.value = true
  try {
    const res = await request.put('/system/config', {
      splash_slots_per_day: quotaConfig.value.splashSlotsPerDay,
      splash_price: quotaConfig.value.splashPrice
    })
    if (res.code === 0) {
      ElMessage.success('配置已保存')
    }
  } catch (e) {
    ElMessage.error('保存失败')
  } finally {
    saving.value = false
  }
}

onMounted(() => { fetchConfig() })
</script>

<template>
  <div class="page-container" v-loading="loading">
    <div class="page-header">
      <div>
        <h2><el-icon><Setting /></el-icon> 名额配置</h2>
        <p>配置每日开屏展示位数量与定价</p>
      </div>
      <el-button :icon="Refresh" @click="fetchConfig">刷新</el-button>
    </div>
    <el-card class="config-card">
      <el-form :model="quotaConfig" label-width="140px">
        <el-form-item label="每日展位数">
          <el-input-number v-model="quotaConfig.splashSlotsPerDay" :min="1" :max="100" />
          <span class="hint">每天可购买的开屏展示位总数</span>
        </el-form-item>
        <el-form-item label="展位单价 (分)">
          <el-input-number v-model="quotaConfig.splashPrice" :min="1" :max="99900" :step="100" />
          <span class="hint">单位为分，例如 990 = ¥9.90</span>
        </el-form-item>
        <el-form-item>
          <el-button type="primary" :loading="saving" @click="saveConfig">保存配置</el-button>
        </el-form-item>
      </el-form>
    </el-card>
  </div>
</template>

<style lang="scss" scoped>
.page-container { padding: 20px; }
.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
  h2 {
    margin: 0 0 8px;
    color: var(--text-primary);
    display: flex;
    align-items: center;
    gap: 8px;
    .el-icon { color: var(--primary-color); }
  }
  p { margin: 0; color: var(--text-secondary); font-size: 14px; }
}
.config-card {
  background: var(--bg-card);
  border: 1px solid var(--border-light);
  border-radius: 12px;
}
.hint {
  margin-left: 12px;
  font-size: 12px;
  color: var(--text-secondary);
}
</style>
