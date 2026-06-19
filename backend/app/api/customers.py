from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, or_
from app.database import get_db
from app.models.user import User
from app.models.customer import Customer
from app.middleware.auth import get_current_user
from app.schemas.customer import CustomerCreate, CustomerUpdate, CustomerResponse
from app.services.audit import log_action
from app.services.cache import invalidate_tenant_dashboard

router = APIRouter(prefix="/api/customers", tags=["Customers"])


@router.get("")
async def list_customers(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    search: str | None = None,
    status: str | None = None,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    query = select(Customer).where(Customer.tenant_id == user.tenant_id)

    if search:
        query = query.where(
            or_(
                Customer.name.ilike(f"%{search}%"),
                Customer.email.ilike(f"%{search}%"),
                Customer.phone.ilike(f"%{search}%"),
                Customer.company.ilike(f"%{search}%"),
            )
        )
    if status:
        query = query.where(Customer.status == status)

    # Count
    count_query = select(func.count()).select_from(query.subquery())
    total = (await db.execute(count_query)).scalar() or 0

    # Paginate
    query = query.order_by(Customer.created_at.desc())
    query = query.offset((page - 1) * limit).limit(limit)
    result = await db.execute(query)
    customers = result.scalars().all()

    return {
        "success": True,
        "data": [CustomerResponse.model_validate(c) for c in customers],
        "pagination": {
            "page": page,
            "limit": limit,
            "total": total,
            "total_pages": (total + limit - 1) // limit,
        },
    }


@router.get("/{customer_id}", response_model=CustomerResponse)
async def get_customer(
    customer_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Customer).where(
            Customer.id == customer_id, Customer.tenant_id == user.tenant_id
        )
    )
    customer = result.scalar_one_or_none()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")
    return CustomerResponse.model_validate(customer)


@router.post("", response_model=CustomerResponse, status_code=201)
async def create_customer(
    req: CustomerCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    customer = Customer(
        tenant_id=user.tenant_id,
        **req.model_dump(),
    )
    db.add(customer)

    await log_action(db, user.tenant_id, user.id, "CREATE", "Customer", customer.id,
                     new_values=req.model_dump())
    await db.commit()
    await invalidate_tenant_dashboard(user.tenant_id)
    await db.refresh(customer)
    return CustomerResponse.model_validate(customer)


@router.put("/{customer_id}", response_model=CustomerResponse)
async def update_customer(
    customer_id: str,
    req: CustomerUpdate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Customer).where(
            Customer.id == customer_id, Customer.tenant_id == user.tenant_id
        )
    )
    customer = result.scalar_one_or_none()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")

    old_values = {k: getattr(customer, k) for k in req.model_dump(exclude_unset=True)}
    updates = req.model_dump(exclude_unset=True)
    for key, value in updates.items():
        setattr(customer, key, value)

    await log_action(db, user.tenant_id, user.id, "UPDATE", "Customer", customer_id,
                     old_values=old_values, new_values=updates)
    await db.commit()
    await invalidate_tenant_dashboard(user.tenant_id)
    await db.refresh(customer)
    return CustomerResponse.model_validate(customer)


@router.delete("/{customer_id}")
async def delete_customer(
    customer_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Customer).where(
            Customer.id == customer_id, Customer.tenant_id == user.tenant_id
        )
    )
    customer = result.scalar_one_or_none()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")

    await log_action(db, user.tenant_id, user.id, "DELETE", "Customer", customer_id)
    await db.delete(customer)
    await db.commit()
    await invalidate_tenant_dashboard(user.tenant_id)
    return {"success": True, "message": "Customer deleted"}
