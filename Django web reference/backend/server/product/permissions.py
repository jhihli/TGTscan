from rest_framework.permissions import BasePermission
from django.conf import settings


class HasScannerApiKey(BasePermission):
    """Grants access when the request carries a valid X-Api-Key header."""

    def has_permission(self, request, view):
        key = request.META.get('HTTP_X_API_KEY', '')
        expected = getattr(settings, 'SCANNER_API_KEY', '')
        return bool(expected and key == expected)
