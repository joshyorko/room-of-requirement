from django.db.models.signals import pre_save, post_save
from django.dispatch import receiver
from django.utils import timezone
from django.core.mail import send_mail
from django.conf import settings
from .models import Task

@receiver(pre_save, sender=Task)
def task_status_change(sender, instance, **kwargs):
    if not instance.pk:  # New instance
        return
    
    try:
        old_instance = Task.objects.get(pk=instance.pk)
        if old_instance.status != instance.status:
            if instance.status == Task.Status.DONE:
                instance.completed_at = timezone.now()
            elif old_instance.status == Task.Status.DONE:
                instance.completed_at = None
    except Task.DoesNotExist:
        pass

@receiver(post_save, sender=Task)
def notify_task_assignment(sender, instance, created, **kwargs):
    if created and settings.DEBUG is False:  # Only send emails in production
        subject = f'New Task Assignment: {instance.title}'
        message = f'''
        You have been assigned a new task:
        
        Title: {instance.title}
        Description: {instance.description}
        Due Date: {instance.due_date}
        
        Please review it at your earliest convenience.
        '''
        try:
            send_mail(
                subject,
                message,
                settings.DEFAULT_FROM_EMAIL,
                [instance.assignee.email],
                fail_silently=True,
            )
        except Exception:
            # Log the error in production
            pass