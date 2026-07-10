<script setup lang="ts">
import { ref, onMounted, nextTick } from 'vue'
import * as echarts from 'echarts'
import request from '@/utils/request'
import { Refresh, Money, GoldMedal, Ticket, TrendCharts, Timer, DataLine, Histogram } from '@element-plus/icons-vue'

const loading = ref(false)

// 商业化数据
const businessStats = ref({
  totalRevenue: 0,
  vipRevenue: 0,
  splashRevenue: 0,
  vipUsers: 0,
  splashOrders: 0,
  monthlyGrowth: 0
})

// 图表引用
const revenueChartRef = ref<HTMLElement>()
const vipChartRef = ref<HTMLElement>()

// 收入趋势图表状态
const revenueChartType = ref<'line' | 'bar'>('line')
const revenueTimeRange = ref('7')

const toggleRevenueChartType = (type: 'line' | 'bar') => {
  revenueChartType.value = type
  loadRevenueChart()
}

// 主题色 - 根据主题调整
const primaryColor = '#10B981'
const goldColor = '#F59E0B'

// 根据主题获取文字颜色
const getThemeColors = () => {
  const isDark = document.documentElement.classList.contains('dark')
  return {
    textColor: isDark ? '#9CA3AF' : '#64748B',
    gridColor: isDark ? '#374151' : '#E2E8F0',
    tooltipBg: isDark ? 'rgba(17, 24, 39, 0.95)' : 'rgba(255, 255, 255, 0.95)',
    tooltipBorder: isDark ? '#374151' : '#E2E8F0',
    tooltipText: isDark ? '#F0F6FC' : '#1E293B',
    labelColor: isDark ? '#F3F4F6' : '#1E293B'
  }
}

const loadData = async () => {
  loading.value = true
  try {
    // 加载商业化统计数据
    const [dashRes, revenueRes] = await Promise.all([
      request.get('/stats/dashboard'),
      request.get('/stats/revenue-trend', { params: { days: revenueTimeRange.value } })
    ])
    
    if (dashRes.code === 0) {
      businessStats.value.vipUsers = dashRes.data.overview?.vipUsers || 0
    }
    
    if (revenueRes.code === 0) {
      const data = revenueRes.data
      // 计算总收入
      const vipTotal = (data.vipRevenue || []).reduce((sum: number, v: number) => sum + v, 0)
      const splashTotal = (data.splashRevenue || []).reduce((sum: number, v: number) => sum + v, 0)
      businessStats.value.vipRevenue = vipTotal
      businessStats.value.splashRevenue = splashTotal
      businessStats.value.totalRevenue = vipTotal + splashTotal
    }
    
    await nextTick()
    loadRevenueChart()
    loadVipChart()
  } catch (e) { console.error(e) }
  finally { loading.value = false }
}

// 收入趋势图
const loadRevenueChart = async () => {
  if (!revenueChartRef.value) return
  try {
    const res = await request.get('/stats/revenue-trend', { params: { days: revenueTimeRange.value } })
    if (res.code !== 0) return
    const data = res.data
    const chart = echarts.init(revenueChartRef.value)
    
    // 根据图表类型设置不同的配置
    const isLine = revenueChartType.value === 'line'
    const theme = getThemeColors()
    
    chart.setOption({
      backgroundColor: 'transparent',
      tooltip: { 
        trigger: 'axis',
        backgroundColor: theme.tooltipBg,
        borderColor: theme.tooltipBorder,
        textStyle: { color: theme.tooltipText },
        axisPointer: { type: 'shadow' },
        formatter: (params: any) => { 
          let r = params[0].name + '<br/>'; 
          params.forEach((p: any) => { 
            r += `${p.marker}${p.seriesName}: ¥${p.value.toFixed(2)}<br/>` 
          }); 
          return r 
        }
      },
      toolbox: { show: false },
      legend: { 
        show: true,
        top: 0, // 紧贴顶部
        left: 0, // 左对齐
        textStyle: { color: theme.textColor, fontSize: 12 },
        selectedMode: 'multiple',
        itemWidth: 14,
        itemHeight: 10,
        itemGap: 16
      },
      grid: { left: '10', right: '10', bottom: '10', top: '35', containLabel: true },
      xAxis: { 
        type: 'category', 
        data: data.dates, 
        axisLine: { lineStyle: { color: theme.gridColor } }, 
        axisLabel: { color: theme.textColor, margin: 12 },
        axisTick: { show: false },
        boundaryGap: !isLine
      },
      yAxis: { 
        type: 'value', 
        axisLine: { show: false }, 
        splitLine: { lineStyle: { color: theme.gridColor, type: 'dashed', opacity: 0.5 } }, 
        axisLabel: { color: theme.textColor, formatter: '¥{value}' } 
      },
      series: [
        { 
          // 折线图显示累计，柱状图显示每日
          name: isLine ? '累计VIP收入' : 'VIP订阅', 
          type: revenueChartType.value, 
          smooth: true, 
          data: data.vipRevenue, 
          itemStyle: { 
            color: goldColor,
            borderRadius: [4, 4, 0, 0]
          }, 
          lineStyle: { width: 3 },
          barMaxWidth: 20,
          areaStyle: isLine ? { 
            color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
              { offset: 0, color: 'rgba(245, 158, 11, 0.4)' },
              { offset: 1, color: 'rgba(245, 158, 11, 0)' }
            ])
          } : undefined,
          showSymbol: false,
          emphasis: { focus: 'series' }
        },
        { 
          name: isLine ? '累计开屏收入' : '开屏收入', 
          type: revenueChartType.value, 
          smooth: true, 
          data: data.splashRevenue, 
          itemStyle: { 
            color: primaryColor,
            borderRadius: [4, 4, 0, 0]
          }, 
          lineStyle: { width: 3 },
          barMaxWidth: 20,
          areaStyle: isLine ? { 
            color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
              { offset: 0, color: 'rgba(16, 185, 129, 0.4)' },
              { offset: 1, color: 'rgba(16, 185, 129, 0)' }
            ])
          } : undefined,
          showSymbol: false,
          emphasis: { focus: 'series' }
        }
      ]
    })
    
    setTimeout(() => chart.resize(), 0)
    window.addEventListener('resize', () => chart.resize())
  } catch (e) { console.error(e) }
}

// VIP用户分布图 — 从后端实时获取数据
const loadVipChart = async () => {
  if (!vipChartRef.value) return
  const chart = echarts.init(vipChartRef.value)
  const theme = getThemeColors()
  
  // 从后端获取真实 VIP 转化数据
  let vipCount = 0
  let normalCount = 0
  let coupleVipCount = 0
  try {
    const res = await request.get('/stats/vip-conversion')
    if (res.code === 0) {
      const d = res.data
      vipCount = d.vipUsers || 0
      coupleVipCount = d.coupleVipUsers || 0
      normalCount = (d.totalUsers || 0) - vipCount
      // 同步更新顶部卡片
      businessStats.value.vipUsers = vipCount
    }
  } catch (e) {
    console.error('获取VIP数据失败:', e)
  }

  const chartData = []
  if (vipCount > 0) chartData.push({ value: vipCount, name: 'VIP用户', itemStyle: { color: goldColor } })
  if (coupleVipCount > 0) chartData.push({ value: coupleVipCount, name: '情侣VIP', itemStyle: { color: '#EC4899' } })
  chartData.push({ value: normalCount || 1, name: '普通用户', itemStyle: { color: '#6B7280' } })

  chart.setOption({
    backgroundColor: 'transparent',
    tooltip: { 
      trigger: 'item', 
      backgroundColor: theme.tooltipBg, 
      borderColor: 'transparent', 
      textStyle: { color: theme.tooltipText },
      formatter: '{b}: {c} ({d}%)'
    },
    legend: { 
      orient: 'horizontal',
      bottom: 0,
      textStyle: { color: theme.textColor },
      itemWidth: 12,
      itemHeight: 12,
      itemGap: 20
    },
    series: [{ 
      type: 'pie', 
      radius: ['45%', '70%'], 
      center: ['50%', '45%'], 
      avoidLabelOverlap: false, 
      label: { show: false },
      emphasis: { 
        label: { 
          show: true, 
          fontSize: 14, 
          fontWeight: 'bold',
          color: theme.labelColor
        },
        itemStyle: {
          shadowBlur: 20,
          shadowColor: 'rgba(0,0,0,0.3)'
        }
      },
      itemStyle: {
        borderRadius: 6,
        borderColor: 'var(--bg-card)',
        borderWidth: 2
      },
      data: chartData
    }]
  })
  window.addEventListener('resize', () => chart.resize())
}

const formatCurrency = (num: number) => {
  return '¥' + num.toFixed(2)
}

const getTimeRangeLabel = () => {
  const labels: Record<string, string> = {
    '7': '近7天',
    '30': '近30天',
    '90': '近3个月',
    '365': '近1年'
  }
  return labels[revenueTimeRange.value] || '近7天'
}

onMounted(() => { loadData() })
</script>

<template>
  <div class="statistics-page" v-loading="loading">
    <!-- 页面头部 -->
    <div class="page-header">
      <div class="header-info">
        <h2>
          <el-icon><TrendCharts /></el-icon>
          数据统计
        </h2>
        <p>商业化数据分析与收入统计</p>
      </div>
      <button class="tech-btn" @click="loadData">
        <el-icon><Refresh /></el-icon>
        <span>刷新数据</span>
      </button>
    </div>

    <!-- 收入概览 -->
    <div class="revenue-cards">
      <div class="revenue-card total">
        <div class="card-icon">
          <el-icon><Money /></el-icon>
        </div>
        <div class="card-content">
          <span class="card-value">{{ formatCurrency(businessStats.totalRevenue) }}</span>
          <span class="card-label">累计收入（{{ getTimeRangeLabel() }}）</span>
        </div>
      </div>
      
      <div class="revenue-card">
        <div class="card-icon vip">
          <el-icon><GoldMedal /></el-icon>
        </div>
        <div class="card-content">
          <span class="card-value">{{ formatCurrency(businessStats.vipRevenue) }}</span>
          <span class="card-label">VIP订阅收入</span>
        </div>
      </div>
      
      <div class="revenue-card">
        <div class="card-icon splash">
          <el-icon><Ticket /></el-icon>
        </div>
        <div class="card-content">
          <span class="card-value">{{ formatCurrency(businessStats.splashRevenue) }}</span>
          <span class="card-label">开屏收入</span>
        </div>
      </div>
      
      <div class="revenue-card">
        <div class="card-icon users">
          <el-icon><GoldMedal /></el-icon>
        </div>
        <div class="card-content">
          <span class="card-value">{{ businessStats.vipUsers }}</span>
          <span class="card-label">VIP用户数</span>
        </div>
      </div>
    </div>
    
    <!-- 图表区域 -->
    <div class="charts-area">
      <!-- 收入趋势图表 - 仿用户增长趋势样式 -->
      <div class="chart-panel glass-panel main">
        <div class="chart-header">
          <div class="header-left">
            <h3>收入趋势</h3>
          </div>
          
          <!-- 图表切换器 -->
          <div class="chart-switcher">
            <div 
              class="switch-item" 
              :class="{ active: revenueChartType === 'line' }"
              @click="toggleRevenueChartType('line')"
              title="折线图"
            >
              <el-icon><DataLine /></el-icon>
            </div>
            <div 
              class="switch-item" 
              :class="{ active: revenueChartType === 'bar' }"
              @click="toggleRevenueChartType('bar')"
              title="柱状图"
            >
              <el-icon><Histogram /></el-icon>
            </div>
          </div>
        </div>
        
        <div ref="revenueChartRef" class="chart-box"></div>
        
        <!-- 时间范围选择器 -->
        <div class="time-selector">
          <div 
            v-for="item in [{ l: '近7天', v: '7' }, { l: '近30天', v: '30' }, { l: '近3个月', v: '90' }, { l: '近1年', v: '365' }]"
            :key="item.v"
            class="time-tab"
            :class="{ active: revenueTimeRange === item.v }"
            @click="revenueTimeRange = item.v; loadRevenueChart()"
          >
            {{ item.l }}
          </div>
        </div>
      </div>
      
      <div class="chart-panel glass-panel">
        <div class="section-header">
          <h3>用户构成</h3>
        </div>
        <div ref="vipChartRef" class="chart-box"></div>
      </div>
    </div>
    
    <!-- 数据说明 -->
    <div class="data-notes">
      <div class="note-item">
        <el-icon><Timer /></el-icon>
        <span>数据更新时间：{{ new Date().toLocaleString('zh-CN') }}</span>
      </div>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.statistics-page {
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

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 32px;
  
  .header-info {
    h2 {
      margin: 0 0 4px;
      color: var(--text-primary);
      font-size: 24px;
      font-weight: 600;
      display: flex;
      align-items: center;
      gap: 12px;
      
      .el-icon { color: var(--primary-color); }
    }
    
    p {
      margin: 0;
      color: var(--text-secondary);
      font-size: 14px;
    }
  }
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

.revenue-cards {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 20px;
  margin-bottom: 24px;
}

.revenue-card {
  background: var(--gradient-card);
  border: 1px solid var(--border-light);
  border-radius: 16px;
  padding: 20px;
  display: flex;
  align-items: center;
  gap: 16px;
  transition: all 0.3s ease;
  
  &:hover {
    border-color: var(--primary-color);
    box-shadow: var(--shadow-glow);
    transform: translateY(-4px);
    
    .card-icon {
      transform: scale(1.1);
    }
  }
  
  &.total {
    background: linear-gradient(135deg, rgba(16, 185, 129, 0.15) 0%, rgba(16, 185, 129, 0.05) 100%);
    border-color: rgba(16, 185, 129, 0.3);
    
    .card-value { color: var(--primary-color); }
  }
  
  .card-icon {
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
    
    &.vip { 
      background: rgba(245, 158, 11, 0.1); 
      color: #F59E0B; 
    }
    &.splash { 
      background: rgba(96, 165, 250, 0.1); 
      color: #60A5FA; 
    }
    &.users { 
      background: rgba(245, 158, 11, 0.1); 
      color: #F59E0B; 
    }
  }
  
  .card-content {
    display: flex;
    flex-direction: column;
    
    .card-value {
      font-size: 24px;
      font-weight: 700;
      color: var(--text-primary);
    }
    
    .card-label {
      font-size: 13px;
      color: var(--text-secondary);
      margin-top: 2px;
    }
  }
}

.charts-area {
  display: grid;
  grid-template-columns: 2fr 1fr;
  gap: 24px;
  margin-bottom: 24px;
}

.chart-panel {
  display: flex;
  flex-direction: column;
  
  &.main {
    height: 420px;
  }
  
  .section-header {
    margin-bottom: 20px;
    
    h3 {
      margin: 0;
      font-size: 18px;
      font-weight: 600;
      color: var(--text-primary);
    }
  }
  
  .chart-box {
    flex: 1;
    width: 100%;
    min-height: 280px;
  }
}

// 图表头部
.chart-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
  
  .header-left {
    display: flex;
    flex-direction: column;
    gap: 8px;
    
    h3 { 
      margin: 0; 
      color: var(--text-primary); 
      font-size: 18px; 
    }
    
    .legend-custom {
      display: flex;
      gap: 16px;
      font-size: 12px;
      
      .legend-item {
        display: flex;
        align-items: center;
        gap: 6px;
        color: var(--text-secondary);
        
        .dot { 
          width: 8px; 
          height: 8px; 
          border-radius: 50%; 
        }
        
        &.vip .dot { 
          background: #F59E0B; 
          box-shadow: 0 0 6px rgba(245, 158, 11, 0.4); 
        }
        &.splash .dot { 
          background: var(--primary-color); 
          box-shadow: 0 0 6px rgba(16, 185, 129, 0.4);
        }
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
    
    &:hover { 
      color: var(--text-regular); 
      background: var(--bg-card-hover); 
    }
    
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

.data-notes {
  display: flex;
  justify-content: flex-end;
  
  .note-item {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 12px;
    color: var(--text-placeholder);
  }
}

@media (max-width: 1280px) {
  .revenue-cards { grid-template-columns: repeat(2, 1fr); }
  .charts-area { grid-template-columns: 1fr; }
}

@media (max-width: 768px) {
  .revenue-cards { grid-template-columns: 1fr; }
}
</style>
