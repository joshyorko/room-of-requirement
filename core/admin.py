from django.contrib import admin
from django.utils.html import format_html
from django.utils import timezone
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.contrib.auth.models import User
from .models import UserProfile, Task

class UserProfileInline(admin.StackedInline):
    model = UserProfile
    can_delete = False
    verbose_name_plural = 'Profile'

def approve_users(modeladmin, request, queryset):
    for user in queryset:
        user.profile.is_approved = True
        user.profile.save()
approve_users.short_description = "Mark selected users as approved"

def unapprove_users(modeladmin, request, queryset):
    for user in queryset:
        user.profile.is_approved = False
        user.profile.save()
unapprove_users.short_description = "Mark selected users as unapproved"

class UserAdmin(BaseUserAdmin):
    inlines = (UserProfileInline,)
    list_display = ('username', 'email', 'first_name', 'last_name', 'is_staff', 'get_is_approved')
    actions = [approve_users, unapprove_users]

    def get_is_approved(self, obj):
        return obj.profile.is_approved
    get_is_approved.short_description = 'Approved'
    get_is_approved.boolean = True

# Re-register UserAdmin
admin.site.unregister(User)
admin.site.register(User, UserAdmin)

@admin.register(Task)
class TaskAdmin(admin.ModelAdmin):
    list_display = ('title', 'assignee', 'due_date', 'status', 'priority', 'risk_level', 'created_by', 'colored_status')
    list_filter = ('status', 'priority', 'risk_level', 'assignee', 'created_by', 'due_date')
    search_fields = ('title', 'description', 'intelligence_notes', 'assignee__username', 'created_by__username')
    date_hierarchy = 'created_at'
    
    actions = ['mark_as_done', 'mark_as_in_progress']
    readonly_fields = ('created_at', 'updated_at', 'created_by')
    fieldsets = (
        ('Task Information', {
            'fields': ('title', 'description', 'status', 'priority', 'risk_level')
        }),
        ('Assignment', {
            'fields': ('assignee', 'due_date', 'predicted_completion')
        }),
        ('Analytics', {
            'fields': ('intelligence_notes',),
            'classes': ('collapse',)
        }),
        ('Metadata', {
            'fields': ('created_by', 'created_at', 'updated_at'),
            'classes': ('collapse',)
        })
    )

    def colored_status(self, obj):
        colors = {
            Task.Status.TODO: 'orange',
            Task.Status.IN_PROGRESS: 'blue',
            Task.Status.DONE: 'green',
        }
        return format_html(
            '<span style="color: {};">{}</span>',
            colors[obj.status],
            obj.get_status_display()
        )
    colored_status.short_description = 'Status'

    def mark_as_done(self, request, queryset):
        queryset.update(status=Task.Status.DONE)
    mark_as_done.short_description = "Mark selected tasks as done"

    def mark_as_in_progress(self, request, queryset):
        queryset.update(status=Task.Status.IN_PROGRESS)
    mark_as_in_progress.short_description = "Mark selected tasks as in progress"

    def save_model(self, request, obj, form, change):
        if not change:  # If creating new object
            obj.created_by = request.user
        super().save_model(request, obj, form, change)
