from django.contrib.auth.models import AbstractUser
from django.db import models

class UserRole(models.TextChoices):
    ADMIN = "admin", "Admin"
    MANAGER = "manager", "Manager"
    VZ_USER = "vz_user", "VZ User"
    R2_USER = "r2_user", "R2 User"
    N_USER = "n_user", "N User"

class CustomUser(AbstractUser):
    role = models.CharField(
        max_length=10,
        choices=UserRole.choices,
        default=UserRole.N_USER,  # Default role for new users
        blank=False,  # Ensure role is not blank
        null=False,
    )

    USERNAME_FIELD = "username"  # Log in with username
    REQUIRED_FIELDS = []  # No extra required fields

    # Add related_name to groups to avoid conflict with default User model
    groups = models.ManyToManyField(
        'auth.Group',
        related_name='customuser_set',  # Avoid clashes with the default User model
        blank=True
    )
    
    user_permissions = models.ManyToManyField(
        'auth.Permission',
        related_name='customuser_set',  # Avoid clashes with the default User model
        blank=True
    )

    def __str__(self):
        return f"{self.username} ({self.role})"

    @property
    def is_admin_or_manager(self):
        """Check if the user is an Admin or Manager."""
        return self.role in [UserRole.ADMIN, UserRole.MANAGER]
