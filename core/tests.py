from django.test import TestCase
from django.contrib.auth.models import User
from django.utils import timezone
from datetime import timedelta
from rest_framework.test import APITestCase, APIClient
from rest_framework import status
from rest_framework.authtoken.models import Token
from .models import Task, UserProfile

class TaskModelTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(username='testuser', password='testpass')
        self.assignee = User.objects.create_user(username='assignee', password='testpass')
        # Approve users for task tests
        self.user.profile.is_approved = True
        self.user.profile.save()
        self.assignee.profile.is_approved = True
        self.assignee.profile.save()
        
    def test_task_creation(self):
        task = Task.objects.create(
            title='Test Task',
            description='Test Description',
            assignee=self.assignee,
            created_by=self.user,
            status=Task.Status.TODO
        )
        self.assertEqual(task.title, 'Test Task')
        self.assertEqual(task.status, Task.Status.TODO)
        
    def test_is_overdue(self):
        # Test overdue task
        overdue_task = Task.objects.create(
            title='Overdue Task',
            assignee=self.assignee,
            created_by=self.user,
            due_date=timezone.now() - timezone.timedelta(days=1)
        )
        self.assertTrue(overdue_task.is_overdue())
        
        # Test future task
        future_task = Task.objects.create(
            title='Future Task',
            assignee=self.assignee,
            created_by=self.user,
            due_date=timezone.now() + timezone.timedelta(days=1)
        )
        self.assertFalse(future_task.is_overdue())

class TaskAPITests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(username='testuser', password='testpass')
        self.assignee = User.objects.create_user(username='assignee', password='testpass')
        # Approve the user for API tests
        self.user.profile.is_approved = True
        self.user.profile.save()
        self.assignee.profile.is_approved = True
        self.assignee.profile.save()
        
        self.token = Token.objects.create(user=self.user)
        self.client = APIClient()
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.token.key}')
        
        self.task_data = {
            'title': 'API Test Task',
            'description': 'Test Description',
            'assignee_id': self.assignee.id,
            'status': Task.Status.TODO,
            'due_date': timezone.now().isoformat()
        }
        
    def test_create_task(self):
        response = self.client.post('/api/tasks/', self.task_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(Task.objects.count(), 1)
        self.assertEqual(Task.objects.get().title, 'API Test Task')
        
    def test_list_tasks(self):
        # Create a task
        Task.objects.create(
            title='Test Task',
            assignee=self.assignee,
            created_by=self.user
        )
        response = self.client.get('/api/tasks/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
        
    def test_update_task(self):
        task = Task.objects.create(
            title='Original Title',
            assignee=self.assignee,
            created_by=self.user
        )
        response = self.client.patch(
            f'/api/tasks/{task.id}/',
            {'title': 'Updated Title'},
            format='json'
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(Task.objects.get(id=task.id).title, 'Updated Title')
        
    def test_delete_task(self):
        task = Task.objects.create(
            title='Test Task',
            assignee=self.assignee,
            created_by=self.user
        )
        response = self.client.delete(f'/api/tasks/{task.id}/')
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        self.assertEqual(Task.objects.count(), 0)
        
    def test_unauthorized_access(self):
        # Test without authentication
        client = APIClient()
        response = client.get('/api/tasks/')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
        
    def test_my_tasks_endpoint(self):
        # Create tasks
        Task.objects.create(title='My Task', assignee=self.user, created_by=self.assignee)
        Task.objects.create(title='Other Task', assignee=self.assignee, created_by=self.user)
        
        response = self.client.get('/api/tasks/my_tasks/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]['title'], 'My Task')

class RegistrationTests(APITestCase):
    def test_user_registration(self):
        data = {
            'username': 'testuser',
            'email': 'test@example.com',
            'password': 'testpass123',
            'confirm_password': 'testpass123'
        }
        response = self.client.post('/api/register/', data)
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        user = User.objects.get(username='testuser')
        self.assertFalse(user.profile.is_approved)

    def test_password_mismatch(self):
        data = {
            'username': 'testuser',
            'email': 'test@example.com',
            'password': 'testpass123',
            'confirm_password': 'wrongpass'
        }
        response = self.client.post('/api/register/', data)
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

class ApprovalPermissionTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser',
            password='testpass123'
        )
        self.client.force_authenticate(user=self.user)

    def test_unapproved_user_access(self):
        # Ensure unapproved user cannot access protected endpoints
        response = self.client.get('/api/tasks/')
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_approved_user_access(self):
        # Approve the user
        self.user.profile.is_approved = True
        self.user.profile.save()
        
        response = self.client.get('/api/tasks/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)

class DashboardAPITests(APITestCase):
    def setUp(self):
        # Create test users
        self.user = User.objects.create_user(username='testuser', password='testpass')
        self.assignee = User.objects.create_user(username='assignee', password='testpass')
        
        # Approve users
        self.user.profile.is_approved = True
        self.user.profile.save()
        self.assignee.profile.is_approved = True
        self.assignee.profile.save()
        
        # Create authentication token
        self.token = Token.objects.create(user=self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.token.key}')

        # Create test tasks with various states
        Task.objects.create(
            title='High Priority Task',
            assignee=self.user,
            created_by=self.assignee,
            priority=Task.Priority.HIGH,
            risk_level=Task.RiskLevel.HIGH,
            status=Task.Status.TODO
        )
        Task.objects.create(
            title='Completed Task',
            assignee=self.user,
            created_by=self.assignee,
            status=Task.Status.DONE,
            priority=Task.Priority.MEDIUM
        )
        Task.objects.create(
            title='Overdue Task',
            assignee=self.user,
            created_by=self.assignee,
            due_date=timezone.now() - timedelta(days=1),
            status=Task.Status.TODO
        )

    def test_dashboard_summary(self):
        response = self.client.get('/api/dashboard/summary/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        data = response.data
        
        self.assertEqual(data['total_tasks'], 3)
        self.assertEqual(data['overdue_tasks'], 1)
        self.assertTrue('status_distribution' in data)
        self.assertTrue('priority_distribution' in data)
        self.assertTrue('risk_distribution' in data)

    def test_dashboard_trends(self):
        response = self.client.get('/api/dashboard/trends/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        data = response.data

        self.assertTrue('daily_completion' in data)
        self.assertTrue('daily_creation' in data)
        self.assertTrue('delay_metrics' in data)
        self.assertTrue('prediction_accuracy' in data)

    def test_unapproved_user_access(self):
        # Create unapproved user
        unapproved = User.objects.create_user(username='unapproved', password='testpass')
        token = Token.objects.create(user=unapproved)
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {token.key}')

        # Test both endpoints
        summary_response = self.client.get('/api/dashboard/summary/')
        trends_response = self.client.get('/api/dashboard/trends/')

        self.assertEqual(summary_response.status_code, status.HTTP_403_FORBIDDEN)
        self.assertEqual(trends_response.status_code, status.HTTP_403_FORBIDDEN)

class TaskFilterTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(username='testuser', password='testpass')
        self.assignee = User.objects.create_user(username='assignee', password='testpass')
        
        # Approve users
        self.user.profile.is_approved = True
        self.user.profile.save()
        self.assignee.profile.is_approved = True
        self.assignee.profile.save()
        
        # Authenticate
        self.token = Token.objects.create(user=self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.token.key}')
        
        # Create test tasks with various attributes
        self.tasks = [
            Task.objects.create(
                title='High Priority Task',
                description='Important task',
                assignee=self.user,
                created_by=self.assignee,
                priority=Task.Priority.HIGH,
                risk_level=Task.RiskLevel.HIGH,
                status=Task.Status.TODO,
                intelligence_notes='Critical milestone'
            ),
            Task.objects.create(
                title='Medium Task',
                assignee=self.user,
                created_by=self.assignee,
                priority=Task.Priority.MEDIUM,
                risk_level=Task.RiskLevel.MEDIUM,
                status=Task.Status.IN_PROGRESS
            ),
            Task.objects.create(
                title='Low Priority Past Due',
                assignee=self.user,
                created_by=self.assignee,
                priority=Task.Priority.LOW,
                due_date=timezone.now() - timedelta(days=1),
                status=Task.Status.TODO
            )
        ]

    def test_priority_filter(self):
        response = self.client.get('/api/tasks/', {'priority': Task.Priority.HIGH})
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]['priority'], Task.Priority.HIGH)

    def test_status_filter(self):
        response = self.client.get('/api/tasks/', {'status': Task.Status.TODO})
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 2)
        self.assertTrue(all(task['status'] == Task.Status.TODO for task in response.data))

    def test_multiple_filters(self):
        response = self.client.get(
            '/api/tasks/',
            {'status': Task.Status.TODO, 'priority': Task.Priority.HIGH}
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]['title'], 'High Priority Task')

    def test_search_filter(self):
        response = self.client.get('/api/tasks/', {'search': 'Critical'})
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]['title'], 'High Priority Task')

    def test_overdue_filter(self):
        response = self.client.get('/api/tasks/', {'is_overdue': 'true'})
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]['title'], 'Low Priority Past Due')

    def test_ordering(self):
        # Create additional test task to ensure proper ordering
        Task.objects.create(
            title='Additional High Priority Task',
            assignee=self.user,
            created_by=self.assignee,
            priority=Task.Priority.HIGH,
            status=Task.Status.TODO
        )

        # Test ordering by priority (HIGH to LOW)
        response = self.client.get('/api/tasks/', {'ordering': 'priority'})
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        priorities = [task['priority'] for task in response.data]
        
        # Verify ascending order: CRITICAL -> HIGH -> MEDIUM -> LOW
        self.assertTrue(
            all(priorities[i] <= priorities[i+1] for i in range(len(priorities)-1)),
            "Tasks should be ordered by priority in ascending order"
        )

        # Test reverse ordering (LOW to HIGH)
        response = self.client.get('/api/tasks/', {'ordering': '-priority'})
        priorities = [task['priority'] for task in response.data]
        
        # Verify descending order: LOW -> MEDIUM -> HIGH -> CRITICAL
        self.assertTrue(
            all(priorities[i] >= priorities[i+1] for i in range(len(priorities)-1)),
            "Tasks should be ordered by priority in descending order"
        )

        # Test ordering by due_date
        response = self.client.get('/api/tasks/', {'ordering': 'due_date'})
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        due_dates = [task.get('due_date') for task in response.data]
        
        # Verify ascending due date order
        self.assertTrue(
            all(
                (not d1 or not d2) or d1 <= d2  # Handle None values
                for d1, d2 in zip(due_dates[:-1], due_dates[1:])
            ),
            "Tasks should be ordered by due date in ascending order"
        )

    def test_date_range_filter(self):
        today = timezone.now()
        yesterday = today - timedelta(days=1)
        tomorrow = today + timedelta(days=1)

        # Create a task with a specific due date
        Task.objects.create(
            title='Date Range Test Task',
            assignee=self.user,
            created_by=self.assignee,
            due_date=today,
            status=Task.Status.TODO
        )
        
        response = self.client.get(
            '/api/tasks/',
            {
                'due_after': yesterday.isoformat(),
                'due_before': tomorrow.isoformat()
            }
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(len(response.data) > 0)
        self.assertTrue(any(task['title'] == 'Date Range Test Task' for task in response.data))
