from django.db.models import Count, Avg, Q, F, ExpressionWrapper, FloatField, DurationField
from django.db.models.functions import ExtractWeek, ExtractYear, Now, TruncDay
from django.utils import timezone
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from datetime import timedelta
from .models import Task
from .permissions import IsApprovedUser

class DashboardSummaryView(APIView):
    permission_classes = [IsAuthenticated, IsApprovedUser]

    def get(self, request):
        # Get base queryset based on user's role
        if request.user.is_superuser:
            tasks = Task.objects.all()
        else:
            tasks = Task.objects.filter(
                Q(assignee=request.user) | Q(created_by=request.user)
            )

        # Basic statistics
        total_tasks = tasks.count()
        overdue_tasks = tasks.filter(
            due_date__lt=timezone.now(),
            status__in=[Task.Status.TODO, Task.Status.IN_PROGRESS]
        ).count()

        # Tasks by status
        status_distribution = tasks.values('status').annotate(
            count=Count('id')
        )

        # Tasks by priority
        priority_distribution = tasks.values('priority').annotate(
            count=Count('id')
        )

        # Risk level distribution
        risk_distribution = tasks.values('risk_level').annotate(
            count=Count('id')
        )

        # Completion rate (last 30 days)
        thirty_days_ago = timezone.now() - timedelta(days=30)
        completed_tasks = tasks.filter(
            status=Task.Status.DONE,
            updated_at__gte=thirty_days_ago
        ).count()
        new_tasks = tasks.filter(created_at__gte=thirty_days_ago).count()
        completion_rate = (completed_tasks / new_tasks * 100) if new_tasks > 0 else 0

        # Average completion time for done tasks
        avg_completion_time = tasks.filter(
            status=Task.Status.DONE
        ).exclude(
            created_at=None
        ).aggregate(
            avg_time=Avg(ExpressionWrapper(
                F('updated_at') - F('created_at'),
                output_field=DurationField()
            ))
        )['avg_time']

        return Response({
            'total_tasks': total_tasks,
            'overdue_tasks': overdue_tasks,
            'completion_rate': round(completion_rate, 2),
            'avg_completion_time': avg_completion_time.total_seconds() if avg_completion_time else None,
            'status_distribution': status_distribution,
            'priority_distribution': priority_distribution,
            'risk_distribution': risk_distribution
        })

class DashboardTrendsView(APIView):
    permission_classes = [IsAuthenticated, IsApprovedUser]

    def get(self, request):
        # Get base queryset based on user's role
        if request.user.is_superuser:
            tasks = Task.objects.all()
        else:
            tasks = Task.objects.filter(
                Q(assignee=request.user) | Q(created_by=request.user)
            )

        # Get the last 30 days of data
        thirty_days_ago = timezone.now() - timedelta(days=30)
        
        # Daily completion trends
        daily_completion = tasks.filter(
            status=Task.Status.DONE,
            updated_at__gte=thirty_days_ago
        ).annotate(
            day=TruncDay('updated_at')
        ).values('day').annotate(
            completed=Count('id')
        ).order_by('day')

        # Daily creation trends
        daily_creation = tasks.filter(
            created_at__gte=thirty_days_ago
        ).annotate(
            day=TruncDay('created_at')
        ).values('day').annotate(
            created=Count('id')
        ).order_by('day')

        # Delay analysis
        delayed_tasks = tasks.filter(
            due_date__lt=F('updated_at'),
            status=Task.Status.DONE
        ).annotate(
            delay=ExpressionWrapper(
                F('updated_at') - F('due_date'),
                output_field=DurationField()
            )
        ).aggregate(
            avg_delay=Avg('delay'),
            total_delayed=Count('id')
        )

        # Priority shifts (tasks with priority changes)
        priority_changes = tasks.exclude(
            priority=F('priority')
        ).count()

        return Response({
            'daily_completion': daily_completion,
            'daily_creation': daily_creation,
            'delay_metrics': {
                'average_delay': delayed_tasks['avg_delay'].total_seconds() if delayed_tasks['avg_delay'] else None,
                'total_delayed_tasks': delayed_tasks['total_delayed']
            },
            'priority_changes': priority_changes,
            'prediction_accuracy': {
                'enabled': False,
                'message': 'ML predictions not yet implemented'
            }
        })