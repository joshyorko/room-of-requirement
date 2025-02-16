from django_filters import rest_framework as filters
from django.db.models import Q
from django.utils import timezone
from datetime import datetime
from .models import Task

class TaskFilter(filters.FilterSet):
    # Date range filters with proper timezone handling
    created_after = filters.IsoDateTimeFilter(field_name='created_at', lookup_expr='gte')
    created_before = filters.IsoDateTimeFilter(field_name='created_at', lookup_expr='lte')
    due_after = filters.IsoDateTimeFilter(field_name='due_date', lookup_expr='gte')
    due_before = filters.IsoDateTimeFilter(field_name='due_date', lookup_expr='lte')
    
    # Multiple value filters
    status = filters.MultipleChoiceFilter(choices=Task.Status.choices)
    priority = filters.MultipleChoiceFilter(choices=Task.Priority.choices)
    risk_level = filters.MultipleChoiceFilter(choices=Task.RiskLevel.choices)
    
    # Text search filters
    search = filters.CharFilter(method='search_filter')
    
    # Boolean filters
    is_overdue = filters.BooleanFilter(method='overdue_filter')
    has_notes = filters.BooleanFilter(field_name='intelligence_notes', 
                                    lookup_expr='isnull',
                                    exclude=True)
    
    class Meta:
        model = Task
        fields = {
            'assignee': ['exact'],
            'created_by': ['exact'],
            'status': ['exact'],
            'priority': ['exact', 'in'],  # Allow filtering by multiple priorities
            'risk_level': ['exact', 'gte', 'lte'],  # Allow range filtering on risk level
        }

    def search_filter(self, queryset, name, value):
        """
        Full-text search across title, description, and intelligence notes
        """
        return queryset.filter(
            Q(title__icontains=value) |
            Q(description__icontains=value) |
            Q(intelligence_notes__icontains=value)
        )

    def overdue_filter(self, queryset, name, value):
        """
        Filter for overdue tasks based on due_date and current status
        """
        now = timezone.now()
        if value:  # Show overdue tasks
            return queryset.filter(
                due_date__lt=now,
                status__in=[Task.Status.TODO, Task.Status.IN_PROGRESS]
            )
        # Show non-overdue tasks
        return queryset.exclude(
            due_date__lt=now,
            status__in=[Task.Status.TODO, Task.Status.IN_PROGRESS]
        )