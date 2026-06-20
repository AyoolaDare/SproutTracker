import hashlib
import secrets
from datetime import datetime, timedelta, timezone
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Request
from fastapi.security import HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database import get_db
from app.models.user import User, UserRole
from app.models.tenant import Tenant
from app.models.tax import TaxSettings
from app.middleware.auth import (
    hash_password,
    verify_password,
    create_access_token,
    create_refresh_token,
    decode_access_token,
    decode_refresh_token,
    get_current_user,
    revoke_token_jti,
    security,
    token_ttl_seconds,
)
from app.schemas.auth import (
    EmailVerificationConfirm,
    GoogleAuthRequest,
    RegisterRequest,
    RegisterResponse,
    LoginRequest,
    RefreshRequest,
    PasswordResetConfirm,
    PasswordResetRequest,
    PasswordResetResponse,
    TokenResponse,
    UserResponse,
)
from app.config import get_settings
from app.services.email import (
    send_email_verification_email,
    send_password_setup_email,
    send_welcome_email,
)

router = APIRouter(prefix="/api/auth", tags=["Authentication"])
settings = get_settings()

MAX_FAILED_ATTEMPTS = 5
LOCKOUT_MINUTES = 15
PASSWORD_RESET_MINUTES = 60
EMAIL_VERIFICATION_HOURS = 24


def hash_reset_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def issue_password_reset_token(user: User) -> str:
    token = secrets.token_urlsafe(48)
    user.password_reset_token_hash = hash_reset_token(token)
    user.password_reset_expires_at = datetime.now(timezone.utc) + timedelta(
        minutes=PASSWORD_RESET_MINUTES
    )
    return token


def issue_email_verification_token(user: User) -> str:
    token = secrets.token_urlsafe(48)
    user.email_verification_token_hash = hash_reset_token(token)
    user.email_verification_expires_at = datetime.now(timezone.utc) + timedelta(
        hours=EMAIL_VERIFICATION_HOURS
    )
    return token


def token_response_for(user: User) -> TokenResponse:
    token_data = {"sub": user.id, "tenant_id": user.tenant_id, "role": user.role.value}
    return TokenResponse(
        access_token=create_access_token(token_data),
        refresh_token=create_refresh_token(token_data),
        expires_in=settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES * 60,
    )


@router.post("/register", response_model=RegisterResponse)
async def register(
    req: RegisterRequest,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
):
    # Check if email already exists
    result = await db.execute(select(User).where(User.email == req.email))
    if result.scalar_one_or_none():
        raise HTTPException(status_code=409, detail="Email already registered")

    # Create tenant (business)
    tenant = Tenant(
        business_name=req.business_name,
        business_type=req.business_type,
    )
    db.add(tenant)
    await db.flush()

    # Create default tax settings
    tax_settings = TaxSettings(tenant_id=tenant.id)
    db.add(tax_settings)

    # Create user (owner)
    user = User(
        tenant_id=tenant.id,
        email=req.email,
        password_hash=hash_password(req.password),
        password_set_at=datetime.now(timezone.utc),
        full_name=req.full_name,
        role=UserRole.OWNER,
        is_active=False,
    )
    db.add(user)
    token = issue_email_verification_token(user)
    await db.commit()

    verify_url = f"{settings.FRONTEND_URL.rstrip('/')}/verify-email?token={token}"
    background_tasks.add_task(send_email_verification_email, user.email, verify_url)
    return RegisterResponse(
        success=True,
        message="Account created. Check your email to verify your account.",
        requires_email_verification=True,
    )


@router.post("/login", response_model=TokenResponse)
async def login(req: LoginRequest, request: Request, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == req.email))
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(status_code=401, detail="Invalid email or password")

    # Check lockout
    if user.is_locked:
        raise HTTPException(
            status_code=403,
            detail="Account locked due to too many failed attempts. Try again later.",
        )

    if user.email_verified_at is None:
        raise HTTPException(
            status_code=403,
            detail={
                "code": "EMAIL_VERIFICATION_REQUIRED",
                "message": "Verify your email address before signing in.",
            },
        )

    if user.password_set_at is None:
        raise HTTPException(
            status_code=403,
            detail={
                "code": "PASSWORD_SETUP_REQUIRED",
                "message": "This migrated account needs a new Sprout Track password.",
            },
        )

    # Verify password
    if not verify_password(req.password, user.password_hash):
        user.failed_attempts += 1
        if user.failed_attempts >= MAX_FAILED_ATTEMPTS:
            user.locked_until = datetime.now(timezone.utc) + timedelta(minutes=LOCKOUT_MINUTES)
        await db.commit()
        raise HTTPException(status_code=401, detail="Invalid email or password")

    if not user.is_active:
        raise HTTPException(status_code=403, detail="Account is deactivated")

    # Successful login — reset failed attempts
    user.failed_attempts = 0
    user.locked_until = None
    user.last_login_at = datetime.now(timezone.utc)
    await db.commit()

    # Get business name for response
    tenant_result = await db.execute(select(Tenant).where(Tenant.id == user.tenant_id))
    tenant = tenant_result.scalar_one_or_none()

    return token_response_for(user)


@router.post("/email/verify", response_model=PasswordResetResponse)
async def verify_email(
    req: EmailVerificationConfirm,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
):
    token_hash = hash_reset_token(req.token)
    result = await db.execute(
        select(User).where(User.email_verification_token_hash == token_hash)
    )
    user = result.scalar_one_or_none()
    now = datetime.now(timezone.utc)
    if not user or not user.email_verification_expires_at or user.email_verification_expires_at < now:
        raise HTTPException(status_code=400, detail="Invalid or expired verification link")

    user.email_verified_at = now
    user.email_verification_token_hash = None
    user.email_verification_expires_at = None
    user.is_active = True
    await db.commit()

    background_tasks.add_task(send_welcome_email, user.email, user.full_name)
    return PasswordResetResponse(success=True, message="Email verified. You can now sign in.")


@router.post("/email/resend", response_model=PasswordResetResponse)
async def resend_verification_email(
    req: PasswordResetRequest,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.email == req.email))
    user = result.scalar_one_or_none()
    if user and user.email_verified_at is None:
        token = issue_email_verification_token(user)
        await db.commit()
        verify_url = f"{settings.FRONTEND_URL.rstrip('/')}/verify-email?token={token}"
        background_tasks.add_task(send_email_verification_email, user.email, verify_url)

    return PasswordResetResponse(
        success=True,
        message="If that account needs verification, a new email has been sent.",
    )


@router.post("/google", response_model=TokenResponse)
async def google_auth(req: GoogleAuthRequest, db: AsyncSession = Depends(get_db)):
    if not settings.GOOGLE_CLIENT_ID:
        raise HTTPException(status_code=503, detail="Google sign-in is not configured")

    try:
        from google.auth.transport import requests as google_requests
        from google.oauth2 import id_token as google_id_token
    except ImportError:
        raise HTTPException(status_code=503, detail="Google auth dependency is not installed")

    try:
        payload = google_id_token.verify_oauth2_token(
            req.id_token,
            google_requests.Request(),
            settings.GOOGLE_CLIENT_ID,
        )
    except ValueError:
        raise HTTPException(status_code=401, detail="Invalid Google token")

    if not payload.get("email_verified"):
        raise HTTPException(status_code=403, detail="Google email is not verified")

    email = str(payload["email"]).lower()
    subject = str(payload["sub"])
    full_name = payload.get("name") or email.split("@")[0]

    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()
    if not user:
        tenant = Tenant(
            business_name=req.business_name or f"{full_name}'s Business",
            business_type=req.business_type,
        )
        db.add(tenant)
        await db.flush()
        db.add(TaxSettings(tenant_id=tenant.id))
        user = User(
            tenant_id=tenant.id,
            email=email,
            password_hash=hash_password(secrets.token_urlsafe(32)),
            password_set_at=None,
            email_verified_at=datetime.now(timezone.utc),
            full_name=full_name,
            role=UserRole.OWNER,
            is_active=True,
            oauth_provider="google",
            oauth_subject=subject,
        )
        db.add(user)
    else:
        user.email_verified_at = user.email_verified_at or datetime.now(timezone.utc)
        user.is_active = True
        user.oauth_provider = user.oauth_provider or "google"
        user.oauth_subject = user.oauth_subject or subject

    await db.commit()
    await db.refresh(user)
    return token_response_for(user)


@router.post("/password-reset/request", response_model=PasswordResetResponse)
async def request_password_reset(
    req: PasswordResetRequest,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.email == req.email))
    user = result.scalar_one_or_none()
    if user:
        token = issue_password_reset_token(user)
        await db.commit()
        setup_url = f"{settings.FRONTEND_URL.rstrip('/')}/reset-password?token={token}"
        background_tasks.add_task(send_password_setup_email, user.email, setup_url)

    # Do not reveal whether an email exists.
    return PasswordResetResponse(
        success=True,
        message="If that email exists, a password setup link can be sent.",
    )


@router.post("/password-reset/confirm", response_model=PasswordResetResponse)
async def confirm_password_reset(
    req: PasswordResetConfirm,
    db: AsyncSession = Depends(get_db),
):
    token_hash = hash_reset_token(req.token)
    result = await db.execute(
        select(User).where(User.password_reset_token_hash == token_hash)
    )
    user = result.scalar_one_or_none()
    now = datetime.now(timezone.utc)
    if not user or not user.password_reset_expires_at or user.password_reset_expires_at < now:
        raise HTTPException(status_code=400, detail="Invalid or expired password reset token")

    user.password_hash = hash_password(req.password)
    user.password_set_at = now
    user.password_reset_token_hash = None
    user.password_reset_expires_at = None
    user.failed_attempts = 0
    user.locked_until = None
    user.is_active = True
    await db.commit()

    return PasswordResetResponse(
        success=True,
        message="Password set successfully. You can now log in.",
    )


@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(req: RefreshRequest, db: AsyncSession = Depends(get_db)):
    payload = decode_refresh_token(req.refresh_token)
    user_id = payload.get("sub")

    result = await db.execute(select(User).where(User.id == user_id, User.is_active == True))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=401, detail="User not found")

    token_data = {"sub": user.id, "tenant_id": user.tenant_id, "role": user.role.value}
    return TokenResponse(
        access_token=create_access_token(token_data),
        refresh_token=create_refresh_token(token_data),
        expires_in=settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES * 60,
    )


@router.post("/logout")
async def logout():
    # JWT is stateless — client discards tokens
    return {"success": True, "message": "Logged out successfully"}


@router.post("/revoke")
async def revoke_current_access_token(
    credentials: HTTPAuthorizationCredentials = Depends(security),
):
    payload = decode_access_token(credentials.credentials)
    await revoke_token_jti(payload.get("jti"), token_ttl_seconds(payload))
    return {"success": True, "message": "Current access token revoked"}


@router.get("/me", response_model=UserResponse)
async def get_me(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    tenant_result = await db.execute(select(Tenant).where(Tenant.id == user.tenant_id))
    tenant = tenant_result.scalar_one_or_none()

    return UserResponse(
        id=user.id,
        email=user.email,
        full_name=user.full_name,
        role=user.role.value,
        tenant_id=user.tenant_id,
        business_name=tenant.business_name if tenant else None,
        is_active=user.is_active,
    )
