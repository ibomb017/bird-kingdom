<script setup lang="ts">
// 通知管理页面
</script>
<template>
  <div class="page-container">
    <div class="page-header"><h2>通知管理</h2><p>查看和管理系统通知</p></div>
    <el-card><el-empty description="暂无通知数据（需要后端实现通知查询接口）" /></el-card>
  </div>
</template>
<style lang="scss" scoped>
.page-container { padding: 20px; }
.page-header { margin-bottom: 20px; h2 { margin: 0 0 8px; color: var(--text-primary); } p { margin: 0; color: var(--text-secondary); } }
</style>
