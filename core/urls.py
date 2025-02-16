from django.urls import path, include
from rest_framework.routers import DefaultRouter
from rest_framework.authtoken import views as auth_views
from . import views
from . import dashboard_views

router = DefaultRouter()
router.register(r'tasks', views.TaskViewSet, basename='task')

app_name = 'core'

urlpatterns = [
    path('register/', views.RegisterView.as_view(), name='register'),
    path('users/me/', views.CurrentUserView.as_view(), name='current-user'),
    path('dashboard/summary/', dashboard_views.DashboardSummaryView.as_view(), name='dashboard-summary'),
    path('dashboard/trends/', dashboard_views.DashboardTrendsView.as_view(), name='dashboard-trends'),
    path('tasks/auto-update/', views.TaskIntelligenceView.as_view(), name='task-intelligence'),
    path('', include(router.urls)),
    path('api-token-auth/', auth_views.obtain_auth_token, name='api_token_auth'),
]