<script setup lang="ts">
// 点赞收藏统计
</script>
<template>
  <div class="page-container">
    <div class="page-header"><h2>点赞/收藏</h2><p>查看帖子点赞和收藏统计</p></div>
    <el-card><el-empty description="暂无统计数据（需要后端实现统计接口）" /></el-card>
  </div>
</template>
<style lang="scss" scoped>
.page-container { padding: 20px; }
.page-header { margin-bottom: 20px; h2 { margin: 0 0 8px; color: var(--text-primary); } p { margin: 0; color: var(--text-secondary); } }
</style>
