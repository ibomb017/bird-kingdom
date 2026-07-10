<script setup lang="ts">
// 共养关系
</script>
<template>
  <div class="page-container">
    <div class="page-header"><h2>共养关系</h2><p>查看鸟儿的共养关系</p></div>
    <el-card><el-empty description="暂无共养数据（需要后端实现共养查询接口）" /></el-card>
  </div>
</template>
<style lang="scss" scoped>
.page-container { padding: 20px; }
.page-header { margin-bottom: 20px; h2 { margin: 0 0 8px; color: var(--text-primary); } p { margin: 0; color: var(--text-secondary); } }
</style>
