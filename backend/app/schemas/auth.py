from pydantic import BaseModel, EmailStr, Field


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=100)
    full_name: str = Field(min_length=2, max_length=200)
    business_name: str = Field(min_length=2, max_length=200)
    business_type: str = "RETAIL"


class RegisterResponse(BaseModel):
    success: bool
    message: str
    requires_email_verification: bool = True


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class RefreshRequest(BaseModel):
    refresh_token: str


class PasswordResetRequest(BaseModel):
    email: EmailStr


class PasswordResetConfirm(BaseModel):
    token: str = Field(min_length=32, max_length=300)
    password: str = Field(min_length=8, max_length=100)


class EmailVerificationConfirm(BaseModel):
    token: str = Field(min_length=32, max_length=300)


class GoogleAuthRequest(BaseModel):
    id_token: str = Field(min_length=20)
    business_name: str | None = Field(default=None, max_length=200)
    business_type: str = "RETAIL"


class PasswordResetResponse(BaseModel):
    success: bool
    message: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int


class UserResponse(BaseModel):
    id: str
    email: str
    full_name: str
    role: str
    tenant_id: str
    business_name: str | None = None
    is_active: bool

    model_config = {"from_attributes": True}
