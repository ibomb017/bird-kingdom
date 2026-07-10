<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { ArrowLeft, ArrowRight } from '@element-plus/icons-vue'
import request from '@/utils/request'

const currentYear = ref(new Date().getFullYear())
const currentMonth = ref(new Date().getMonth() + 1)
const calendarData = ref<Record<string, any>>({})
const loading = ref(false)
const selectedDate = ref<string | null>(null)
const daySlots = ref<any[]>([])
const dayDetailVisible = ref(false)

const monthNames = ['一月', '二月', '三月', '四月', '五月', '六月', '七月', '八月', '九月', '十月', '十一月', '十二月']

const daysInMonth = computed(() => {
  return new Date(currentYear.value, currentMonth.value, 0).getDate()
})

const firstDayOfWeek = computed(() => {
  const day = new Date(currentYear.value, currentMonth.value - 1, 1).getDay()
  return day === 0 ? 7 : day
})

const calendarDays = computed(() => {
  const days = []
  for (let i = 1; i < firstDayOfWeek.value; i++) {
    days.push({ day: null, data: null })
  }
  for (let d = 1; d <= daysInMonth.value; d++) {
    const dateKey = `${currentYear.value}-${String(currentMonth.value).padStart(2, '0')}-${String(d).padStart(2, '0')}`
    days.push({ day: d, dateKey, data: calendarData.value[dateKey] })
  }
  return days
})

const fetchCalendar = async () => {
  loading.value = true
  try {
    const res = await request.get('/splash/calendar', {
      params: { year: currentYear.value, month: currentMonth.value }
    })
    if (res.code === 0) {
      calendarData.value = res.data
    }
  } catch (e) {
    console.error(e)
  } finally {
    loading.value = false
  }
}

const prevMonth = () => {
  if (currentMonth.value === 1) {
    currentMonth.value = 12
    currentYear.value--
  } else {
    currentMonth.value--
  }
  fetchCalendar()
}

const nextMonth = () => {
  if (currentMonth.value === 12) {
    currentMonth.value = 1
    currentYear.value++
  } else {
    currentMonth.value++
  }
  fetchCalendar()
}

const showDayDetail = async (dateKey: string) => {
  if (!dateKey) return
  selectedDate.value = dateKey
  try {
    const res = await request.get(`/splash/date/${dateKey}`)
    if (res.code === 0) {
      daySlots.value = res.data
      dayDetailVisible.value = true
    }
  } catch (e) {
    console.error(e)
  }
}

const getSlotClass = (data: any) => {
  if (!data) return ''
  const ratio = data.bookedSlots / data.totalSlots
  if (ratio === 0) return 'empty'
  if (ratio < 0.5) return 'available'
  if (ratio < 1) return 'partial'
  return 'full'
}

const isToday = (day: number) => {
  const today = new Date()
  return day === today.getDate() && currentMonth.value === today.getMonth() + 1 && currentYear.value === today.getFullYear()
}

onMounted(() => { fetchCalendar() })
</script>

<template>
  <div class="page-container">
    <div class="page-header">
      <h2>开屏日历</h2>
      <p>查看开屏展示位预订情况</p>
    </div>
    
    <el-card class="calendar-card" v-loading="loading">
      <div class="calendar-header">
        <el-button :icon="ArrowLeft" circle @click="prevMonth" />
        <h3>{{ currentYear }}年 {{ monthNames[currentMonth - 1] }}</h3>
        <el-button :icon="ArrowRight" circle @click="nextMonth" />
      </div>
      
      <div class="calendar-legend">
        <span class="legend-item"><span class="dot empty"></span> 无预订</span>
        <span class="legend-item"><span class="dot available"></span> 少量预订</span>
        <span class="legend-item"><span class="dot partial"></span> 部分预订</span>
        <span class="legend-item"><span class="dot full"></span> 已满</span>
      </div>
      
      <div class="calendar-weekdays">
        <div class="weekday">一</div>
        <div class="weekday">二</div>
        <div class="weekday">三</div>
        <div class="weekday">四</div>
        <div class="weekday">五</div>
        <div class="weekday">六</div>
        <div class="weekday">日</div>
      </div>
      
      <div class="calendar-grid">
        <div 
          v-for="(item, index) in calendarDays" 
          :key="index" 
          class="calendar-day"
          :class="[getSlotClass(item.data), { today: item.day && isToday(item.day), empty: !item.day }]"
          @click="item.dateKey && showDayDetail(item.dateKey)"
        >
          <template v-if="item.day">
            <span class="day-number">{{ item.day }}</span>
            <div class="day-info" v-if="item.data">
              <span class="booked">{{ item.data.bookedSlots }}/{{ item.data.totalSlots }}</span>
              <span class="revenue" v-if="item.data.revenue > 0">¥{{ item.data.revenue.toFixed(0) }}</span>
            </div>
          </template>
        </div>
      </div>
    </el-card>
    
    <!-- 日期详情弹窗 -->
    <el-dialog v-model="dayDetailVisible" :title="`${selectedDate} 展示位详情`" width="600px">
      <div v-if="daySlots.length === 0" class="empty-slots">
        <el-empty description="该日期暂无预订" />
      </div>
      <div v-else class="slots-list">
        <div v-for="slot in daySlots" :key="slot.id" class="slot-item">
          <div class="slot-left">
            <el-avatar :src="slot.userAvatarUrl" :size="40">{{ slot.userNickname?.charAt(0) }}</el-avatar>
            <div class="slot-info">
              <span class="user-name">{{ slot.userNickname || '未知用户' }}</span>
              <span class="slot-number">展位 #{{ slot.slotNumber }}</span>
            </div>
          </div>
          <div class="slot-right">
            <el-tag 
              :type="slot.reviewStatus === 'APPROVED' ? 'success' : (slot.reviewStatus === 'REJECTED' ? 'danger' : 'warning')"
              size="small"
            >
              {{ slot.reviewStatus === 'APPROVED' ? '已通过' : (slot.reviewStatus === 'REJECTED' ? '已驳回' : '待审核') }}
            </el-tag>
          </div>
        </div>
      </div>
    </el-dialog>
  </div>
</template>

<style lang="scss" scoped>
.page-container { padding: 20px; }
.page-header {
  margin-bottom: 20px;
  h2 { margin: 0 0 8px; color: var(--text-primary); }
  p { margin: 0; color: var(--text-secondary); }
}
.calendar-card {
  background: var(--bg-card);
  .calendar-header {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 20px;
    margin-bottom: 20px;
    h3 { margin: 0; }
  }
  .calendar-legend {
    display: flex;
    justify-content: center;
    gap: 20px;
    margin-bottom: 20px;
    .legend-item {
      display: flex;
      align-items: center;
      gap: 6px;
      font-size: 12px;
      .dot {
        width: 12px;
        height: 12px;
        border-radius: 50%;
        &.empty { background: rgba(255,255,255,0.1); }
        &.available { background: #67C23A; }
        &.partial { background: #E6A23C; }
        &.full { background: #F56C6C; }
      }
    }
  }
  .calendar-weekdays {
    display: grid;
    grid-template-columns: repeat(7, 1fr);
    gap: 4px;
    margin-bottom: 8px;
    .weekday {
      text-align: center;
      padding: 8px;
      font-weight: 500;
      color: var(--text-secondary);
    }
  }
  .calendar-grid {
    display: grid;
    grid-template-columns: repeat(7, 1fr);
    gap: 4px;
    .calendar-day {
      min-height: 80px;
      padding: 8px;
      background: var(--bg-card-hover);
      border-radius: 8px;
      cursor: pointer;
      transition: all 0.3s;
      &:hover:not(.empty) {
        background: rgba(255,255,255,0.1);
      }
      &.today {
        border: 2px solid #409EFF;
      }
      &.available { background: rgba(103, 194, 58, 0.2); }
      &.partial { background: rgba(230, 162, 60, 0.2); }
      &.full { background: rgba(245, 108, 108, 0.2); }
      &.empty { cursor: default; }
      .day-number {
        font-weight: 500;
        font-size: 16px;
      }
      .day-info {
        margin-top: 8px;
        display: flex;
        flex-direction: column;
        gap: 4px;
        font-size: 12px;
        .booked { color: rgba(255,255,255,0.7); }
        .revenue { color: #E6A23C; }
      }
    }
  }
}
.slots-list {
  .slot-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 12px;
    background: var(--bg-card-hover);
    border-radius: 8px;
    margin-bottom: 8px;
    .slot-left {
      display: flex;
      align-items: center;
      gap: 12px;
      .slot-info {
        display: flex;
        flex-direction: column;
        .user-name { font-weight: 500; }
        .slot-number { font-size: 12px; color: var(--text-secondary); }
      }
    }
  }
}
</style>
