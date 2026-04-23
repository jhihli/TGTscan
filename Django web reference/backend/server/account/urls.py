from django.urls import path
from .views import UserListAPIView, create_user, get_users


urlpatterns = [
    path("user-info/", get_users, name="user-info"),
    path("register/", create_user, name="register"),
    path("users/", UserListAPIView.as_view(), name="user-list"),
]