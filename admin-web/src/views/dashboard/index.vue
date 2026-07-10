<script setup lang="ts">
import { ref, onMounted, nextTick } from 'vue'
import { useRouter } from 'vue-router'
import * as echarts from 'echarts'
import request from '@/utils/request'
import { Refresh, User, Document, Notebook, ChatLineSquare, Warning, ArrowRight, Check, DataLine, Histogram } from '@element-plus/icons-vue'

// 图表类型切换
const chartType = ref<'line' | 'bar'>('line')
const toggleChartType = (type: 'line' | 'bar') => {
  chartType.value = type
  loadUserChart()
}

const router = useRouter()
const loading = ref(true)

// 统计数据
const stats = ref({
  totalUsers: 0,
  totalBirds: 0,
  totalPosts: 0,
  totalComments: 0,
  todayNewUsers: 0,
  todayPosts: 0
})
const todos = ref<any[]>([])

// 图表
const userChartRef = ref<HTMLElement>()
const postDistChartRef = ref<HTMLElement>()

// 主题色
const primaryColor = '#10B981'

const loadData = async () => {
  loading.value = true
  try {
    const [statsRes, todosRes] = await Promise.all([
      request.get('/stats/dashboard'),
      request.get('/stats/todos')
    ])
    
    if (statsRes.code === 0) {
      const overview = statsRes.data.overview || {}
      const cards = statsRes.data.cards || []
      
      stats.value = {
        totalUsers: overview.totalUsers || 0,
        totalBirds: overview.totalBirds || 0,
        totalPosts: overview.totalPosts || 0,
        totalComments: overview.totalComments || 0,
        todayNewUsers: cards.find((c: any) => c.title === '今日新增用户')?.value || 0,
        todayPosts: cards.find((c: any) => c.title === '今日发帖')?.value || 0
      }
    }
    if (todosRes.code === 0) {
      todos.value = todosRes.data || []
    }
    
    await nextTick()
    loadUserChart()
    loadPostDistChart()
  } catch (e) { 
    console.error('加载数据失败:', e) 
  } finally { 
    loading.value = false 
  }
}
const timeRange = ref('7')

const loadUserChart = async () => {
  if (!userChartRef.value) return
  const chart = echarts.init(userChartRef.value)
  
  try {
    const res = await request.get('/stats/user-trend', { params: { days: timeRange.value } })
    if (res.code !== 0) return
    const data = res.data
    
    // 根据主题切换调整图表颜色
    const isDark = document.documentElement.classList.contains('dark')
    const textColor = isDark ? '#E5E7EB' : '#1E293B'
    const gridColor = isDark ? '#374151' : '#E2E8F0'
    const tooltipBg = isDark ? 'rgba(17, 24, 39, 0.95)' : 'rgba(255, 255, 255, 0.95)'
    const tooltipBorder = isDark ? '#374151' : '#E2E8F0'
    const tooltipTextColor = isDark ? '#F0F6FC' : '#1E293B'
    const primaryColor = '#10B981'
    
    chart.setOption({
      backgroundColor: 'transparent',
      tooltip: { 
        trigger: 'axis',
        backgroundColor: tooltipBg,
        borderColor: tooltipBorder,
        textStyle: { color: tooltipTextColor },
        axisPointer: { type: 'shadow' }
      },
      toolbox: { show: false },
      legend: { 
        show: true,
        top: 0, // 紧贴顶部
        left: 0, // 左对齐
        textStyle: { color: textColor, fontSize: 12 },
        selectedMode: 'multiple', // 允许多选，点击隐藏/显示
        itemWidth: 14,
        itemHeight: 10,
        itemGap: 16
      },
      grid: { left: '10', right: '10', bottom: '10', top: '35', containLabel: true },
      xAxis: { 
        type: 'category', 
        data: data.dates, 
        axisLine: { lineStyle: { color: gridColor } }, 
        axisLabel: { color: textColor, margin: 12 },
        axisTick: { show: false }
      },
      yAxis: [
        { 
          type: 'value', 
          axisLine: { show: false }, 
          splitLine: { lineStyle: { color: gridColor, type: 'dashed', opacity: 0.5 } }, 
          axisLabel: { color: textColor } 
        }
      ],
      series: [
        { 
          // 根据图表类型显示不同数据
          name: chartType.value === 'bar' ? '累计用户' : '新增用户', 
          type: chartType.value,
          smooth: true,
          data: chartType.value === 'bar' ? (data.totalUsers || data.newUsers) : data.newUsers,
          itemStyle: { 
            color: primaryColor,
            borderRadius: [4, 4, 0, 0]
          },
          barMaxWidth: 20,
          areaStyle: chartType.value === 'line' ? {
            color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
              { offset: 0, color: 'rgba(16, 185, 129, 0.4)' },
              { offset: 1, color: 'rgba(16, 185, 129, 0.0)' }
            ])
          } : undefined,
          showSymbol: false,
          emphasis: {
            focus: 'series'
          }
        },
        { 
          name: '活跃用户', 
          type: 'line', 
          smooth: true, 
          data: data.activeUsers, 
          itemStyle: { color: '#9CA3AF' },
          lineStyle: { width: 2, type: 'dashed' },
          symbol: 'none',
          emphasis: {
            focus: 'series'
          }
        }
      ]
    })
    
    // 强制resize一次确保布局正确
    setTimeout(() => chart.resize(), 0)
    
    window.addEventListener('resize', () => chart.resize())
  } catch (e) { console.error(e) }
}

const loadPostDistChart = async () => {
  if (!postDistChartRef.value) return
  try {
    const res = await request.get('/stats/post-distribution')
    if (res.code !== 0) return
    const data = res.data
    
    const chart = echarts.init(postDistChartRef.value)
    const isDark = document.documentElement.classList.contains('dark')
    const tooltipBg = isDark ? 'rgba(22, 27, 34, 0.95)' : 'rgba(255, 255, 255, 0.95)'
    const tooltipTextColor = isDark ? '#F0F6FC' : '#1E293B'
    const legendColor = isDark ? '#8B949E' : '#64748B'
    const labelEmphasisColor = isDark ? '#F0F6FC' : '#1E293B'
    
    chart.setOption({
      backgroundColor: 'transparent',
      tooltip: {
        trigger: 'item',
        backgroundColor: tooltipBg,
        borderColor: 'transparent',
        textStyle: { color: tooltipTextColor }
      },
      legend: {
        orient: 'horizontal',
        bottom: '5%',
        left: 'center',
        textStyle: { 
          color: legendColor,
          fontSize: 12
        },
        itemGap: 15
      },
      series: [{
        name: '帖子分布',
        type: 'pie',
        radius: ['35%', '65%'],
        center: ['50%', '45%'],
        avoidLabelOverlap: false,
        itemStyle: {
          borderRadius: 8,
          borderColor: 'transparent',
          borderWidth: 2
        },
        label: {
          show: false
        },
        emphasis: {
          label: {
            show: true,
            fontSize: 14,
            fontWeight: 'bold',
            color: labelEmphasisColor
          },
          itemStyle: {
            shadowBlur: 10,
            shadowOffsetX: 0,
            shadowColor: 'rgba(0, 0, 0, 0.3)'
          }
        },
        labelLine: {
          show: false
        },
        data: data.map((item: any) => ({
          value: item.value,
          name: item.name,
          itemStyle: { color: item.color || primaryColor }
        }))
      }]
    })
    window.addEventListener('resize', () => chart.resize())
  } catch (e) { console.error(e) }
}

const formatNumber = (num: number) => {
  if (num >= 10000) return (num / 10000).toFixed(1) + '万'
  return num?.toLocaleString() || '0'
}

const goToTodo = (path: string) => { router.push(path) }

onMounted(() => { loadData() })
</script>

<template>
  <div class="dashboard" v-loading="loading">
    <!-- 页面头部 -->
    <div class="page-header">
      <div class="header-info">
        <h2><el-icon><Notebook /></el-icon> 工作台</h2>
        <p>APP运营数据概览与待办事项</p>
      </div>
      <!-- 自定义科技感按钮 -->
      <button class="tech-btn" @click="loadData">
        <el-icon><Refresh /></el-icon>
        <span>刷新数据</span>
      </button>
    </div>

    <!-- 核心指标 -->
    <div class="stats-grid">
      <!-- (保持原有 Stat Items 不变，样式在 CSS 中控制) -->
      <div class="stat-item" @click="router.push('/user/list')">
        <div class="stat-icon"><el-icon><User /></el-icon></div>
        <div class="stat-info">
          <span class="stat-value">{{ formatNumber(stats.totalUsers) }}</span>
          <span class="stat-label">总用户数</span>
        </div>
        <div class="stat-extra" v-if="stats.todayNewUsers > 0">
          今日 +{{ stats.todayNewUsers }}
        </div>
      </div>
      <div class="stat-item" @click="router.push('/bird/list')">
        <div class="stat-icon"><el-icon><Notebook /></el-icon></div>
        <div class="stat-info">
          <span class="stat-value">{{ formatNumber(stats.totalBirds) }}</span>
          <span class="stat-label">鸟档案</span>
        </div>
      </div>
      <div class="stat-item" @click="router.push('/forum/posts')">
        <div class="stat-icon"><el-icon><Document /></el-icon></div>
        <div class="stat-info">
          <span class="stat-value">{{ formatNumber(stats.totalPosts) }}</span>
          <span class="stat-label">帖子总数</span>
        </div>
        <div class="stat-extra" v-if="stats.todayPosts > 0">
          今日 +{{ stats.todayPosts }}
        </div>
      </div>
      <div class="stat-item" @click="router.push('/forum/comments')">
        <div class="stat-icon"><el-icon><ChatLineSquare /></el-icon></div>
        <div class="stat-info">
          <span class="stat-value">{{ formatNumber(stats.totalComments) }}</span>
          <span class="stat-label">评论总数</span>
        </div>
      </div>
    </div>
    
    <!-- 主要内容区 -->
    <div class="main-content-top">
      <!-- 用户趋势图表模块 -->
      <div class="chart-section glass-panel">
        <div class="chart-header">
          <div class="header-left">
            <h3>用户增长趋势</h3>
          </div>
          
          <!-- 自定义图表切换器 -->
          <div class="chart-switcher">
            <div 
              class="switch-item" 
              :class="{ active: chartType === 'line' }"
              @click="toggleChartType('line')"
              title="折线图"
            >
              <el-icon><DataLine /></el-icon>
            </div>
            <div 
              class="switch-item" 
              :class="{ active: chartType === 'bar' }"
              @click="toggleChartType('bar')"
              title="柱状图"
            >
              <el-icon><Histogram /></el-icon>
            </div>
          </div>
        </div>
        
        <div ref="userChartRef" class="chart-box"></div>
        
        <!-- 自定义时间范围选择器 -->
        <div class="time-selector">
          <div 
            v-for="item in [{ l: '近7天', v: '7' }, { l: '近30天', v: '30' }, { l: '近3个月', v: '90' }, { l: '近1年', v: '365' }]"
            :key="item.v"
            class="time-tab"
            :class="{ active: timeRange === item.v }"
            @click="timeRange = item.v; loadUserChart()"
          >
            {{ item.l }}
          </div>
        </div>
      </div>
      
      <!-- 待办事项 (保持结构，样式优化) -->
      <div class="todo-section glass-panel">
        <div class="section-header">
          <h3>待处理事项</h3>
          <span v-if="todos.length > 0" class="todo-count">{{ todos.length }}</span>
        </div>
        <div class="todo-list">
          <div 
            v-for="todo in todos" 
            :key="todo.title" 
            class="todo-item"
            @click="goToTodo(todo.path)"
          >
            <div class="todo-info">
              <span class="todo-title">{{ todo.title }}</span>
              <span class="todo-badge">{{ todo.count }}</span>
            </div>
            <el-icon class="arrow-icon"><ArrowRight /></el-icon>
          </div>
          <div v-if="todos.length === 0" class="todo-empty">
            <el-icon :size="32"><Check /></el-icon>
            <span>暂无待办事项</span>
            <p>所有审核任务已完成</p>
          </div>
        </div>
        
        <div class="quick-links">
          <h4>快速入口</h4>
          <div class="links-grid">
            <div class="link-item" @click="router.push('/user/list')">用户管理</div>
            <div class="link-item" @click="router.push('/forum/posts')">帖子管理</div>
            <div class="link-item" @click="router.push('/splash/review')">开屏审核</div>
            <div class="link-item" @click="router.push('/encyclopedia/species')">品种百科</div>
          </div>
        </div>
      </div>
    </div>
    
    <!-- 主要内容区 - 下层：帖子分布 -->
    <div class="main-content-bottom">
      <div class="chart-section post-dist-section glass-panel">
        <div class="section-header">
          <h3>帖子类型分布</h3>
        </div>
        <div ref="postDistChartRef" class="chart-box"></div>
      </div>
    </div>
  </div>
</template>

<style lang="scss" scoped>
// 基础变量覆盖
:root {
  --primary-color: #10B981;
}

.dashboard {
  padding: 24px;
  color: var(--text-primary);
}

// 玻璃拟态面板基类
.glass-panel {
  background: var(--bg-card);
  backdrop-filter: blur(12px);
  border: 1px solid var(--border-light);
  border-radius: 16px;
  padding: 24px;
  box-shadow: var(--shadow-md);
}

// 头部
.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 32px;
  
  h2 {
    font-size: 24px;
    font-weight: 600;
    color: var(--text-primary);
    display: flex;
    align-items: center;
    gap: 12px;
    margin: 0 0 4px 0;
    
    .el-icon { color: var(--primary-color); }
  }
  
  p { margin: 0; color: var(--text-secondary); font-size: 14px; }
}

// 科技感按钮
.tech-btn {
  background: var(--primary-subtle);
  border: 1px solid rgba(16, 185, 129, 0.3);
  color: var(--primary-color);
  padding: 8px 16px;
  border-radius: 8px;
  display: flex;
  align-items: center;
  gap: 8px;
  cursor: pointer;
  transition: all 0.3s ease;
  font-size: 14px;
  
  &:hover {
    background: rgba(16, 185, 129, 0.2);
    box-shadow: 0 0 12px rgba(16, 185, 129, 0.3);
    transform: translateY(-1px);
    border-color: var(--primary-color);
    color: var(--text-primary);
  }
  
  &:active { transform: scale(0.98); }
}

// 统计卡片
.stats-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 20px;
  margin-bottom: 24px;
}

.stat-item {
  background: var(--gradient-card);
  border: 1px solid var(--border-light);
  border-radius: 16px;
  padding: 20px;
  display: flex;
  align-items: center;
  gap: 16px;
  cursor: pointer;
  transition: all 0.3s ease;
  
  &:hover {
    border-color: var(--primary-color);
    box-shadow: var(--shadow-glow);
    transform: translateY(-4px);
    
    .stat-icon {
      background: var(--primary-color);
      color: var(--text-primary);
      box-shadow: 0 0 10px rgba(16, 185, 129, 0.5);
    }
  }
  
  .stat-icon {
    width: 48px;
    height: 48px;
    border-radius: 12px;
    background: var(--primary-subtle);
    color: var(--primary-color);
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 24px;
    transition: all 0.3s;
  }
  
  .stat-info {
    display: flex;
    flex-direction: column;
    
    .stat-value { font-size: 24px; font-weight: 700; color: var(--text-primary); }
    .stat-label { font-size: 13px; color: var(--text-secondary); margin-top: 2px; }
  }
  
  .stat-extra {
    font-size: 12px;
    color: var(--primary-color);
    padding: 4px 8px;
    background: var(--primary-subtle);
    border-radius: 4px;
  }
}

// 主布局
.main-content-top {
  display: grid;
  grid-template-columns: 2fr 1fr;
  gap: 24px;
  margin-bottom: 24px;
}

.main-content-bottom {
  display: grid;
  grid-template-columns: 1fr;
  gap: 24px;
}

// 图表区域
.chart-section {
  display: flex;
  flex-direction: column;
  height: 420px;
}

.chart-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
  
  .header-left {
    display: flex;
    flex-direction: column;
    gap: 8px;
    
    h3 { margin: 0; color: var(--text-primary); font-size: 18px; }
    
    .legend-custom {
      display: flex;
      gap: 16px;
      font-size: 12px;
      
      .legend-item {
        display: flex;
        align-items: center;
        gap: 6px;
        color: var(--text-secondary);
        
        .dot { width: 8px; height: 8px; border-radius: 50%; }
        
        &.new .dot { background: var(--primary-color); box-shadow: 0 0 6px rgba(16, 185, 129, 0.4); }
        &.active .dot { background: var(--text-secondary); }
      }
    }
  }
}

// 图表切换器
.chart-switcher {
  display: flex;
  background: var(--bg-elevated);
  border-radius: 8px;
  padding: 2px;
  border: 1px solid var(--border-light);
  
  .switch-item {
    width: 36px;
    height: 32px;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    border-radius: 6px;
    color: var(--text-placeholder);
    transition: all 0.3s;
    
    &:hover { color: var(--text-primary); }
    
    &.active {
      background: var(--primary-subtle);
      color: var(--primary-color);
      box-shadow: 0 0 10px rgba(16, 185, 129, 0.1) inset;
    }
  }
}

.chart-box {
  flex: 1;
  width: 100%;
}

// 时间选择器 Tab
.time-selector {
  display: flex;
  justify-content: center;
  gap: 4px;
  margin-top: 16px;
  padding-top: 16px;
  border-top: 1px solid var(--border-lighter);
  
  .time-tab {
    padding: 6px 16px;
    font-size: 13px;
    color: var(--text-placeholder);
    cursor: pointer;
    border-radius: 6px;
    transition: all 0.3s;
    position: relative;
    
    &:hover { color: var(--text-regular); background: var(--bg-card-hover); }
    
    &.active {
      color: var(--primary-color);
      background: var(--primary-subtle);
      font-weight: 500;
      box-shadow: 0 4px 12px rgba(16, 185, 129, 0.1);
      
      &::after {
        content: '';
        position: absolute;
        bottom: 0;
        left: 50%;
        transform: translateX(-50%);
        width: 16px;
        height: 2px;
        background: var(--primary-color);
        border-radius: 2px;
        box-shadow: 0 0 4px var(--primary-color);
      }
    }
  }
}

// 待办事项
.todo-section {
  display: flex;
  flex-direction: column;
  
  .section-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 20px;
    
    h3 { margin: 0; color: var(--text-primary); font-size: 18px; }
    
    .todo-count {
      background: var(--danger-color);
      color: white;
      padding: 2px 8px;
      border-radius: 12px;
      font-size: 12px;
      font-weight: bold;
    }
  }
  
  .todo-list {
    display: flex;
    flex-direction: column;
    gap: 10px;
  }

  .todo-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 12px 16px;
    background: var(--bg-card-hover);
    border-radius: 10px;
    cursor: pointer;
    transition: all 0.25s;
    border: 1px solid transparent;
    
    &:hover {
      background: var(--primary-subtle);
      border-color: rgba(16, 185, 129, 0.2);
      transform: translateX(4px);
      box-shadow: var(--shadow-glow);
      
      .arrow-icon { 
        opacity: 1; 
        color: var(--primary-color);
      }
    }
    
    .todo-info {
      display: flex;
      align-items: center;
      gap: 12px;
      
      .todo-title {
        font-size: 14px;
        color: var(--text-regular);
      }
      
      .todo-badge {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        min-width: 24px;
        height: 24px;
        padding: 0 8px;
        background: var(--danger-color);
        color: white;
        border-radius: 12px;
        font-size: 12px;
        font-weight: 600;
      }
    }
    
    .arrow-icon {
      opacity: 0.3;
      color: var(--text-placeholder);
      transition: all 0.25s;
    }
  }

  .todo-empty {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    color: var(--text-placeholder);
    padding: 40px 0;
    gap: 12px;
    
    .el-icon { color: var(--primary-color); opacity: 0.5; }
    
    span {
      font-size: 14px;
      font-weight: 500;
      color: var(--text-regular);
    }
    
    p {
      margin: 0;
      font-size: 12px;
      color: var(--text-placeholder);
    }
  }
  
  .quick-links {
    margin-top: auto;
    padding-top: 24px;
    border-top: 1px solid var(--border-lighter);
    
    h4 { color: var(--text-secondary); font-size: 13px; margin: 0 0 16px 0; font-weight: 500; }
    
    .links-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 12px;
      
      .link-item {
        background: var(--bg-card-hover);
        padding: 10px;
        text-align: center;
        border-radius: 8px;
        font-size: 13px;
        color: var(--text-regular);
        cursor: pointer;
        transition: all 0.2s;
        border: 1px solid transparent;
        
        &:hover {
          background: var(--primary-subtle);
          border-color: rgba(16, 185, 129, 0.2);
          color: var(--primary-color);
          box-shadow: var(--shadow-glow);
        }
      }
    }
  }
}

.post-dist-section {
  .chart-box {
    height: 350px;
  }
}

@media (max-width: 1200px) {
  .main-content-top { grid-template-columns: 1fr; }
  .stats-grid { grid-template-columns: repeat(2, 1fr); }
}

@media (max-width: 768px) {
  .stats-grid { grid-template-columns: 1fr; }
}
</style>
