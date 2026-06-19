from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from sqlalchemy.orm import selectinload
from app.database import get_db
from app.models.user import User
from app.models.product import Product
from app.models.inventory import StockMovement, InventoryBatch
from app.middleware.auth import get_current_user
from app.schemas.product import ReceiveStockRequest, AdjustStockRequest, StockMovementResponse
from app.services.fifo import receive_stock, adjust_stock
from app.services.audit import log_action
from app.services.cache import invalidate_tenant_dashboard

router = APIRouter(prefix="/api/inventory", tags=["Inventory"])


@router.post("/receive", status_code=201)
async def receive_inventory(
    req: ReceiveStockRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # Verify product belongs to tenant
    result = await db.execute(
        select(Product).where(
            Product.id == req.product_id, Product.tenant_id == user.tenant_id
        )
    )
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    batch = await receive_stock(
        db=db,
        tenant_id=user.tenant_id,
        product_id=req.product_id,
        quantity=req.quantity,
        unit_cost=req.unit_cost,
        user_id=user.id,
        date_received=req.date_received,
        batch_number=req.batch_number,
        supplier_ref=req.supplier_ref,
        notes=req.notes,
    )

    await log_action(
        db, user.tenant_id, user.id, "CREATE", "InventoryBatch", batch.id,
        new_values={"product_id": req.product_id, "quantity": req.quantity, "unit_cost": req.unit_cost},
    )
    await db.commit()
    await invalidate_tenant_dashboard(user.tenant_id)

    return {
        "success": True,
        "data": {
            "batch_id": batch.id,
            "product_id": req.product_id,
            "quantity": req.quantity,
            "unit_cost": req.unit_cost,
        },
        "message": f"Received {req.quantity} units of {product.name}",
    }


@router.post("/adjust")
async def adjust_inventory(
    req: AdjustStockRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Product).where(
            Product.id == req.product_id, Product.tenant_id == user.tenant_id
        )
    )
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    await adjust_stock(
        db=db,
        tenant_id=user.tenant_id,
        product_id=req.product_id,
        quantity=req.quantity,
        reason=req.reason,
        user_id=user.id,
        notes=req.notes,
    )

    await log_action(
        db, user.tenant_id, user.id, "ADJUST", "Inventory", req.product_id,
        new_values={"quantity": req.quantity, "reason": req.reason},
    )
    await db.commit()
    await invalidate_tenant_dashboard(user.tenant_id)

    return {
        "success": True,
        "message": f"Stock adjusted by {req.quantity} for {product.name}",
    }


@router.get("/movements")
async def list_movements(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    product_id: str | None = None,
    movement_type: str | None = None,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    query = select(StockMovement).where(StockMovement.tenant_id == user.tenant_id)

    if product_id:
        query = query.where(StockMovement.product_id == product_id)
    if movement_type:
        query = query.where(StockMovement.movement_type == movement_type)

    count_q = select(func.count()).select_from(query.subquery())
    total = (await db.execute(count_q)).scalar() or 0

    query = query.order_by(StockMovement.created_at.desc())
    query = query.offset((page - 1) * limit).limit(limit)
    result = await db.execute(query)
    movements = result.scalars().all()

    # Get product names
    product_ids = {m.product_id for m in movements}
    prod_result = await db.execute(
        select(Product.id, Product.name).where(Product.id.in_(product_ids))
    )
    product_names = dict(prod_result.all())

    data = []
    for m in movements:
        data.append(StockMovementResponse(
            id=m.id,
            product_id=m.product_id,
            product_name=product_names.get(m.product_id),
            movement_type=m.movement_type.value,
            quantity=m.quantity,
            unit_value=float(m.unit_value),
            total_value=float(m.total_value),
            reference_type=m.reference_type,
            reference_id=m.reference_id,
            notes=m.notes,
            created_at=m.created_at,
        ))

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


@router.get("/valuation")
async def inventory_valuation(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Product)
        .options(selectinload(Product.batches))
        .where(Product.tenant_id == user.tenant_id, Product.is_active == True)
    )
    products = result.scalars().unique().all()

    items = []
    total_cost_value = 0
    total_retail_value = 0

    for p in products:
        active_batches = [b for b in p.batches if b.remaining_quantity > 0]
        qty = sum(b.remaining_quantity for b in active_batches)
        cost_value = sum(b.remaining_quantity * float(b.unit_cost) for b in active_batches)
        retail_value = qty * float(p.selling_price)
        margin = retail_value - cost_value

        items.append({
            "product_id": p.id,
            "product_name": p.name,
            "sku": p.sku,
            "quantity": qty,
            "average_cost": round(cost_value / qty, 2) if qty > 0 else 0,
            "total_cost_value": round(cost_value, 2),
            "selling_price": float(p.selling_price),
            "total_retail_value": round(retail_value, 2),
            "potential_margin": round(margin, 2),
        })
        total_cost_value += cost_value
        total_retail_value += retail_value

    return {
        "success": True,
        "data": {
            "items": items,
            "total_cost_value": round(total_cost_value, 2),
            "total_retail_value": round(total_retail_value, 2),
            "total_potential_margin": round(total_retail_value - total_cost_value, 2),
        },
    }
