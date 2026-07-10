<script setup lang="ts">
// 用户反馈页面 - 暂无数据表
</script>
<template>
  <div class="page-container">
    <div class="page-header"><h2>用户反馈</h2><p>查看用户提交的反馈意见</p></div>
    <el-card><el-empty description="暂无反馈数据（需要后端实现反馈表）" /></el-card>
  </div>
</template>
<style lang="scss" scoped>
.page-container { padding: 20px; }
.page-header { margin-bottom: 20px; h2 { margin: 0 0 8px; color: var(--text-primary); } p { margin: 0; color: var(--text-secondary); } }
</style>
