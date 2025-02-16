from rest_framework import viewsets, permissions, filters, generics
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from django.db import models
from .models import Task
from .serializers import TaskSerializer, UserRegistrationSerializer, UserSerializer
from .permissions import IsApprovedUser
from django.contrib.auth.models import User
from .filters import TaskFilter
from django.utils import timezone
from django.db.models.functions import Cast
from django.db.models import CharField, Q

class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    permission_classes = (permissions.AllowAny,)
    serializer_class = UserRegistrationSerializer

class CurrentUserView(generics.RetrieveAPIView):
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        return self.request.user

class TaskPermission(permissions.BasePermission):
    def has_object_permission(self, request, view, obj):
        # Read permissions are allowed to any authenticated user
        if request.method in permissions.SAFE_METHODS:
            return bool(request.user and 
                      (request.user.is_authenticated and 
                       (request.user.is_superuser or 
                        obj.assignee == request.user or 
                        obj.created_by == request.user)))
        
        # Write permissions are only allowed to task creator or superuser
        return bool(request.user and 
                   (request.user.is_superuser or 
                    obj.created_by == request.user))

class TaskViewSet(viewsets.ModelViewSet):
    queryset = Task.objects.all()
    serializer_class = TaskSerializer
    permission_classes = [IsApprovedUser, TaskPermission]
    filterset_class = TaskFilter
    
    filter_backends = [
        DjangoFilterBackend,
        filters.SearchFilter,
        filters.OrderingFilter,
    ]
    
    # Full-text search fields
    search_fields = ['title', 'description', 'intelligence_notes']
    
    # Ordering fields
    ordering_fields = [
        'created_at', 'updated_at', 'due_date', 'title',
        'priority', 'risk_level', 'status'
    ]
    ordering = ['-created_at']  # Default ordering

    def get_queryset(self):
        """
        Filter tasks based on user's role and apply custom ordering
        """
        queryset = Task.objects.all()
        
        # Apply user role filtering
        if not self.request.user.is_superuser:
            queryset = queryset.filter(
                models.Q(assignee=self.request.user) |
                models.Q(created_by=self.request.user)
            )

        # Handle custom ordering for choice fields
        ordering = self.request.query_params.get('ordering', '-created_at')
        if ordering:
            # Handle multiple ordering fields
            order_fields = ordering.split(',')
            for field in order_fields:
                field_name = field.lstrip('-')
                if field_name in ['priority', 'status']:
                    # For choice fields, use the display value for ordering
                    if field.startswith('-'):
                        queryset = queryset.annotate(
                            **{f"{field_name}_display": Cast(field_name, CharField())}
                        ).order_by(f"-{field_name}_display")
                    else:
                        queryset = queryset.annotate(
                            **{f"{field_name}_display": Cast(field_name, CharField())}
                        ).order_by(f"{field_name}_display")
                else:
                    queryset = queryset.order_by(field)

        return queryset

    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user)

    @action(detail=False, methods=['get'])
    def my_tasks(self, request):
        """Get tasks assigned to the current user"""
        tasks = self.get_queryset().filter(assignee=request.user)
        tasks = self.filter_queryset(tasks)
        page = self.paginate_queryset(tasks)
        if page is not None:
            serializer = self.get_serializer(page, many=True)
            return self.get_paginated_response(serializer.data)
        serializer = self.get_serializer(tasks, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=['get'])
    def overdue(self, request):
        """Get overdue tasks"""
        tasks = self.get_queryset().filter(
            due_date__lt=timezone.now(),
            status__in=[Task.Status.TODO, Task.Status.IN_PROGRESS]
        )
        tasks = self.filter_queryset(tasks)
        page = self.paginate_queryset(tasks)
        if page is not None:
            serializer = self.get_serializer(page, many=True)
            return self.get_paginated_response(serializer.data)
        serializer = self.get_serializer(tasks, many=True)
        return Response(serializer.data)

class TaskIntelligenceView(APIView):
    permission_classes = [IsApprovedUser]
    
    def post(self, request):
        """
        Trigger automated task analysis and updates.
        This endpoint simulates ML-driven task analysis and provides intelligent suggestions.
        """
        # Get tasks that need analysis (not completed and have due dates)
        tasks = Task.objects.filter(
            ~Q(status=Task.Status.DONE),
            due_date__isnull=False
        )
        
        updates = []
        for task in tasks:
            # Simulate ML analysis
            prediction = self._analyze_task(task)
            
            # Update task with predictions
            task.predicted_completion = prediction['predicted_completion']
            task.intelligence_notes = prediction['intelligence_notes']
            task.save()
            
            updates.append({
                'task_id': task.id,
                'title': task.title,
                'predictions': prediction
            })
        
        return Response({
            'message': 'Task intelligence updates completed',
            'updates': updates
        })
    
    def _analyze_task(self, task):
        """
        Simulate ML-based task analysis.
        In a real implementation, this would connect to an ML service.
        """
        # Simple rule-based simulation
        days_until_due = (task.due_date - timezone.now()).days if task.due_date else 0
        overdue = task.is_overdue()
        
        # Simulate intelligent analysis
        if overdue:
            predicted_completion = task.due_date + timezone.timedelta(days=3)
            notes = "ALERT: Task is overdue. Recommend immediate attention and resource reallocation."
        elif days_until_due < 3:
            predicted_completion = task.due_date
            notes = "WARNING: Task due soon. Consider priority escalation."
        else:
            predicted_completion = task.due_date - timezone.timedelta(days=1)
            notes = "Task on track. No immediate actions required."
            
        if task.priority == Task.Priority.HIGH:
            notes += "\nHigh priority task - recommend daily progress reviews."
        
        return {
            'predicted_completion': predicted_completion,
            'intelligence_notes': notes
        }
