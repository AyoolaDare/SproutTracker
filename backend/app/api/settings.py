from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database import get_db
from app.models.user import User, UserRole
from app.models.tenant import Tenant
from app.models.tax import TaxSettings
from app.middleware.auth import get_current_user, require_roles
from app.schemas.settings import BusinessProfileUpdate, TaxSettingsUpdate, TaxSettingsResponse
from app.services.audit import log_action
from app.services.cache import invalidate_tenant_dashboard

router = APIRouter(prefix="/api/settings", tags=["Settings"])


@router.get("/business-profile")
async def get_business_profile(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Tenant).where(Tenant.id == user.tenant_id))
    tenant = result.scalar_one_or_none()
    if not tenant:
        raise HTTPException(status_code=404, detail="Business not found")

    return {
        "success": True,
        "data": {
            "id": tenant.id,
            "business_name": tenant.business_name,
            "business_type": tenant.business_type.value,
            "tin": tenant.tin,
            "rc_number": tenant.rc_number,
            "currency": tenant.currency,
            "country": tenant.country,
            "address": tenant.address,
            "phone": tenant.phone,
            "email": tenant.email,
            "website": tenant.website,
            "logo_url": tenant.logo_url,
            "bank_name": tenant.bank_name,
            "bank_account_number": tenant.bank_account_number,
            "bank_account_name": tenant.bank_account_name,
            "financial_year_start": tenant.financial_year_start,
            "accounting_basis": tenant.accounting_basis.value,
            "inventory_enabled": tenant.inventory_enabled,
            "vat_registered": tenant.vat_registered,
        },
    }


@router.put("/business-profile")
async def update_business_profile(
    req: BusinessProfileUpdate,
    user: User = Depends(require_roles(UserRole.OWNER, UserRole.ADMIN)),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Tenant).where(Tenant.id == user.tenant_id))
    tenant = result.scalar_one_or_none()
    if not tenant:
        raise HTTPException(status_code=404, detail="Business not found")

    updates = req.model_dump(exclude_unset=True)
    for key, value in updates.items():
        setattr(tenant, key, value)

    await log_action(db, user.tenant_id, user.id, "UPDATE", "BusinessProfile", tenant.id,
                     new_values=updates)
    await db.commit()
    await invalidate_tenant_dashboard(user.tenant_id)
    return {"success": True, "message": "Business profile updated"}


@router.get("/tax")
async def get_tax_settings(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(TaxSettings).where(TaxSettings.tenant_id == user.tenant_id)
    )
    tax = result.scalar_one_or_none()
    if not tax:
        # Create defaults
        tax = TaxSettings(tenant_id=user.tenant_id)
        db.add(tax)
        await db.commit()
        await db.refresh(tax)

    return {"success": True, "data": TaxSettingsResponse.model_validate(tax)}


@router.put("/tax")
async def update_tax_settings(
    req: TaxSettingsUpdate,
    user: User = Depends(require_roles(UserRole.OWNER, UserRole.ADMIN)),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(TaxSettings).where(TaxSettings.tenant_id == user.tenant_id)
    )
    tax = result.scalar_one_or_none()
    if not tax:
        tax = TaxSettings(tenant_id=user.tenant_id)
        db.add(tax)

    updates = req.model_dump(exclude_unset=True)
    for key, value in updates.items():
        setattr(tax, key, value)

    await log_action(db, user.tenant_id, user.id, "UPDATE", "TaxSettings", tax.id,
                     new_values=updates)
    await db.commit()
    await invalidate_tenant_dashboard(user.tenant_id)
    return {"success": True, "message": "Tax settings updated"}
