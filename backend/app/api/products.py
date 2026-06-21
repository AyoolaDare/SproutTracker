import uuid
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, or_
from sqlalchemy.orm import selectinload
from app.database import get_db
from app.models.user import User
from app.models.product import Product
from app.models.inventory import InventoryBatch
from app.middleware.auth import get_current_user
from app.schemas.product import ProductCreate, ProductUpdate, ProductResponse
from app.services.audit import log_action
from app.services.cache import invalidate_tenant_dashboard

router = APIRouter(prefix="/api/products", tags=["Products"])


def product_to_response(product: Product) -> dict:
    """Convert product model to response dict with computed fields."""
    batches = product.batches if product.batches else []
    current_stock = sum(b.remaining_quantity for b in batches if not b.is_exhausted)
    active_batches = [b for b in batches if b.remaining_quantity > 0]
    total_qty = sum(b.remaining_quantity for b in active_batches)
    total_cost = sum(b.remaining_quantity * float(b.unit_cost) for b in active_batches)
    avg_cost = total_cost / total_qty if total_qty > 0 else 0
    selling_price = float(product.selling_price)
    margin_percent = (
        ((selling_price - avg_cost) / selling_price) * 100
        if selling_price > 0 and avg_cost > 0 else 0
    )

    return ProductResponse(
        id=product.id,
        name=product.name,
        sku=product.sku,
        description=product.description,
        category=product.category,
        selling_price=selling_price,
        track_inventory=product.track_inventory,
        reorder_level=product.reorder_level,
        vat_applicable=product.vat_applicable,
        is_active=product.is_active,
        current_stock=current_stock,
        average_cost=round(avg_cost, 2),
        margin_percent=round(margin_percent, 1),
        created_at=product.created_at,
    )


@router.get("")
async def list_products(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    search: str | None = None,
    category: str | None = None,
    is_active: bool | None = None,
    low_stock: bool = False,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    query = (
        select(Product)
        .options(selectinload(Product.batches))
        .where(Product.tenant_id == user.tenant_id)
    )

    if search:
        query = query.where(
            or_(
                Product.name.ilike(f"%{search}%"),
                Product.sku.ilike(f"%{search}%"),
                Product.category.ilike(f"%{search}%"),
            )
        )
    if category:
        query = query.where(Product.category == category)
    if is_active is not None:
        query = query.where(Product.is_active == is_active)

    # Count
    count_q = select(func.count(Product.id)).where(Product.tenant_id == user.tenant_id)
    if search:
        count_q = count_q.where(
            or_(
                Product.name.ilike(f"%{search}%"),
                Product.sku.ilike(f"%{search}%"),
            )
        )
    total = (await db.execute(count_q)).scalar() or 0

    query = query.order_by(Product.created_at.desc())
    query = query.offset((page - 1) * limit).limit(limit)
    result = await db.execute(query)
    products = result.scalars().unique().all()

    data = [product_to_response(p) for p in products]

    # Filter low stock on computed field
    if low_stock:
        data = [p for p in data if p.current_stock <= p.reorder_level and p.track_inventory]

    return {
        "success": True,
        "data": data,
        "pagination": {
            "page": page,
            "limit": limit,
            "total": total,
            "total_pages": (total + limit - 1) // limit,
        },
    }


@router.get("/{product_id}")
async def get_product(
    product_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Product)
        .options(selectinload(Product.batches))
        .where(Product.id == product_id, Product.tenant_id == user.tenant_id)
    )
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    return {"success": True, "data": product_to_response(product)}


@router.post("", status_code=201)
async def create_product(
    req: ProductCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    sku = req.sku or f"{req.name[:3].upper().replace(' ', '')}-{uuid.uuid4().hex[:6].upper()}"

    # Check SKU uniqueness within tenant
    existing = await db.execute(
        select(Product).where(
            Product.tenant_id == user.tenant_id, Product.sku == sku
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="SKU already exists")

    data = req.model_dump()
    data['sku'] = sku
    product = Product(tenant_id=user.tenant_id, **data)
    db.add(product)
    await log_action(db, user.tenant_id, user.id, "CREATE", "Product", product.id,
                     new_values=data)
    await db.commit()
    await invalidate_tenant_dashboard(user.tenant_id)

    # Reload with batches
    result = await db.execute(
        select(Product).options(selectinload(Product.batches)).where(Product.id == product.id)
    )
    product = result.scalar_one()
    return {"success": True, "data": product_to_response(product)}


@router.put("/{product_id}")
async def update_product(
    product_id: str,
    req: ProductUpdate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Product)
        .options(selectinload(Product.batches))
        .where(Product.id == product_id, Product.tenant_id == user.tenant_id)
    )
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    updates = req.model_dump(exclude_unset=True)

    # Check SKU uniqueness if changing
    if "sku" in updates:
        existing = await db.execute(
            select(Product).where(
                Product.tenant_id == user.tenant_id,
                Product.sku == updates["sku"],
                Product.id != product_id,
            )
        )
        if existing.scalar_one_or_none():
            raise HTTPException(status_code=400, detail="SKU already exists")

    for key, value in updates.items():
        setattr(product, key, value)

    await log_action(db, user.tenant_id, user.id, "UPDATE", "Product", product_id,
                     new_values=updates)
    await db.commit()
    await invalidate_tenant_dashboard(user.tenant_id)
    await db.refresh(product)
    return {"success": True, "data": product_to_response(product)}


@router.delete("/{product_id}")
async def delete_product(
    product_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Product).where(
            Product.id == product_id, Product.tenant_id == user.tenant_id
        )
    )
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    await log_action(db, user.tenant_id, user.id, "DELETE", "Product", product_id)
    await db.delete(product)
    await db.commit()
    await invalidate_tenant_dashboard(user.tenant_id)
    return {"success": True, "message": "Product deleted"}
