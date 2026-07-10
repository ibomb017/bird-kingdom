<script setup lang="ts">
// 用户关系页面 - 关注/粉丝统计
</script>
<template>
  <div class="page-container">
    <div class="page-header"><h2>用户关系</h2><p>查看用户关注与粉丝关系</p></div>
    <el-card><el-empty description="暂无关系数据（需要后端实现关系查询接口）" /></el-card>
  </div>
</template>
<style lang="scss" scoped>
.page-container { padding: 20px; }
.page-header { margin-bottom: 20px; h2 { margin: 0 0 8px; color: var(--text-primary); } p { margin: 0; color: var(--text-secondary); } }
</style>
