import { createRouter, createWebHistory, type RouteRecordRaw } from 'vue-router'
import NProgress from 'nprogress'
import 'nprogress/nprogress.css'
import { useUserStore } from '@/stores/user'

import Layout from '@/layout/index.vue'

// 合理的路由配置
const routes: RouteRecordRaw[] = [
    {
        path: '/login',
        name: 'Login',
        component: () => import('@/views/login/index.vue'),
        meta: { title: '登录', hidden: true }
    },
    {
        path: '/',
        component: Layout,
        redirect: '/dashboard',
        children: [
            {
                path: 'dashboard',
                name: 'Dashboard',
                component: () => import('@/views/dashboard/index.vue'),
                meta: { title: '工作台', icon: 'HomeFilled' }
            }
        ]
    },
    // ========== 用户管理 ==========
    {
        path: '/user',
        component: Layout,
        redirect: '/user/list',
        meta: { title: '用户管理', icon: 'User' },
        children: [
            {
                path: 'list',
                name: 'UserList',
                component: () => import('@/views/user/list.vue'),
                meta: { title: '用户列表', icon: 'UserFilled' }
            },
            {
                path: 'vip',
                name: 'VipUsers',
                component: () => import('@/views/user/vip.vue'),
                meta: { title: 'VIP用户', icon: 'GoldMedal' }
            }
        ]
    },
    // ========== 鸟舍管理 ==========
    {
        path: '/bird',
        component: Layout,
        redirect: '/bird/list',
        meta: { title: '鸟舍管理', icon: 'Chicken' },
        children: [
            {
                path: 'list',
                name: 'BirdList',
                component: () => import('@/views/bird/list.vue'),
                meta: { title: '鸟档案', icon: 'Document' }
            },
            {
                path: 'logs',
                name: 'BirdLogs',
                component: () => import('@/views/bird/logs.vue'),
                meta: { title: '饲养日志', icon: 'Notebook' }
            }
        ]
    },
    // ========== 论坛社区 ==========
    {
        path: '/forum',
        component: Layout,
        redirect: '/forum/posts',
        meta: { title: '论坛社区', icon: 'ChatLineSquare' },
        children: [
            {
                path: 'posts',
                name: 'ForumPosts',
                component: () => import('@/views/forum/posts.vue'),
                meta: { title: '帖子管理', icon: 'Document' }
            },
            {
                path: 'comments',
                name: 'ForumComments',
                component: () => import('@/views/forum/comments.vue'),
                meta: { title: '评论管理', icon: 'ChatDotRound' }
            },
            {
                path: 'reports',
                name: 'ForumReports',
                component: () => import('@/views/forum/reports.vue'),
                meta: { title: '举报审核', icon: 'WarningFilled' }
            }
        ]
    },
    // ========== 品种百科 ==========
    {
        path: '/encyclopedia',
        component: Layout,
        redirect: '/encyclopedia/species',
        meta: { title: '品种百科', icon: 'Reading' },
        children: [
            {
                path: 'species',
                name: 'EncyclopediaSpecies',
                component: () => import('@/views/encyclopedia/species.vue'),
                meta: { title: '品种知识库', icon: 'Collection' }
            },
            {
                path: 'foods',
                name: 'EncyclopediaFoods',
                component: () => import('@/views/encyclopedia/foods.vue'),
                meta: { title: '食物安全库', icon: 'Food' }
            },
            {
                path: 'symptoms',
                name: 'EncyclopediaSymptoms',
                component: () => import('@/views/encyclopedia/symptoms.vue'),
                meta: { title: '症状速查', icon: 'FirstAidKit' }
            },
            {
                path: 'parrots',
                name: 'EncyclopediaParrots',
                component: () => import('@/views/encyclopedia/parrots.vue'),
                meta: { title: '鹦鹉品种库', icon: 'Chicken' }
            }
        ]
    },
    // ========== 开屏庆生 ==========
    {
        path: '/splash',
        component: Layout,
        redirect: '/splash/review',
        meta: { title: '开屏庆生', icon: 'Present' },
        children: [
            {
                path: 'review',
                name: 'SplashReview',
                component: () => import('@/views/splash/review.vue'),
                meta: { title: '图片审核', icon: 'View' }
            },
            {
                path: 'calendar',
                name: 'SplashCalendar',
                component: () => import('@/views/splash/calendar.vue'),
                meta: { title: '展示日历', icon: 'Calendar' }
            }
        ]
    },
    // ========== 数据统计 (合并成一个综合页面) ==========
    {
        path: '/statistics',
        component: Layout,
        redirect: '/statistics/index',
        children: [
            {
                path: 'index',
                name: 'Statistics',
                component: () => import('@/views/statistics/index.vue'),
                meta: { title: '数据统计', icon: 'DataLine' }
            }
        ]
    },
    // ========== 系统配置 (合并成一个综合页面) ==========
    {
        path: '/system',
        component: Layout,
        redirect: '/system/index',
        children: [
            {
                path: 'index',
                name: 'SystemManagement',
                component: () => import('@/views/system/index.vue'),
                meta: { title: '系统配置', icon: 'Setting' }
            }
        ]
    },
    // ========== 404 ==========
    {
        path: '/:pathMatch(.*)*',
        name: 'NotFound',
        component: () => import('@/views/error/404.vue'),
        meta: { title: '404', hidden: true }
    }
]

const router = createRouter({
    history: createWebHistory('/admin/'),
    routes
})

router.beforeEach(async (to, _from, next) => {
    NProgress.start()
    document.title = `${to.meta.title || '管理后台'} - Bird Kingdom Admin`

    const userStore = useUserStore()
    const token = userStore.token

    if (to.path === '/login') {
        next()
    } else if (!token) {
        next('/login')
    } else {
        next()
    }
})

router.afterEach(() => {
    NProgress.done()
})

export default router
