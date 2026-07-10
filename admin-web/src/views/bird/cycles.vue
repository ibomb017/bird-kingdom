<script setup lang="ts">
// 生理周期管理
</script>
<template>
  <div class="page-container">
    <div class="page-header"><h2>生理周期</h2><p>查看鸟儿的生理周期记录</p></div>
    <el-card><el-empty description="暂无周期数据（需要后端实现周期查询接口）" /></el-card>
  </div>
</template>
<style lang="scss" scoped>
.page-container { padding: 20px; }
.page-header { margin-bottom: 20px; h2 { margin: 0 0 8px; color: var(--text-primary); } p { margin: 0; color: var(--text-secondary); } }
</style>
