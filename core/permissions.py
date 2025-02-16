from rest_framework import permissions

class IsApprovedUser(permissions.BasePermission):
    """
    Custom permission to only allow approved users to access endpoints.
    """
    def has_permission(self, request, view):
        return bool(
            request.user and
            request.user.is_authenticated and
            hasattr(request.user, 'profile') and
            request.user.profile.is_approved
        )