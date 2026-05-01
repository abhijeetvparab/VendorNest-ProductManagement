from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from database import get_db
from models import User, UserRole
from auth import get_current_user
from product_management.models import Product
from product_management.schemas import ProductCreate, ProductUpdate, ProductResponse

router = APIRouter(prefix="/api/products", tags=["Products"])


@router.post("", response_model=ProductResponse, status_code=201)
def create_product(
    data: ProductCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if current_user.role != UserRole.VENDOR:
        raise HTTPException(status_code=403, detail="Only vendors can add products")
    product = Product(vendor_id=current_user.id, **data.model_dump())
    db.add(product)
    db.commit()
    db.refresh(product)
    return product


@router.get("", response_model=List[ProductResponse])
def list_products(
    vendor_id:       Optional[str] = None,
    include_deleted: bool          = False,
    current_user: User    = Depends(get_current_user),
    db: Session           = Depends(get_db),
):
    if current_user.role == UserRole.VENDOR:
        q = db.query(Product).filter(Product.vendor_id == current_user.id)
    elif current_user.role == UserRole.ADMIN:
        q = db.query(Product)
        if vendor_id:
            q = q.filter(Product.vendor_id == vendor_id)
    else:
        raise HTTPException(status_code=403, detail="Access denied")

    if not include_deleted:
        q = q.filter(Product.is_deleted == False)  # noqa: E712

    return q.order_by(Product.created_at.desc()).all()


@router.get("/{product_id}", response_model=ProductResponse)
def get_product(
    product_id: str,
    current_user: User = Depends(get_current_user),
    db: Session        = Depends(get_db),
):
    product = db.query(Product).filter(Product.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    if current_user.role != UserRole.ADMIN and product.vendor_id != current_user.id:
        raise HTTPException(status_code=403, detail="Access denied")
    return product


@router.patch("/{product_id}", response_model=ProductResponse)
def update_product(
    product_id: str,
    data: ProductUpdate,
    current_user: User = Depends(get_current_user),
    db: Session        = Depends(get_db),
):
    product = db.query(Product).filter(Product.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    if current_user.role != UserRole.ADMIN and product.vendor_id != current_user.id:
        raise HTTPException(status_code=403, detail="Access denied")
    for k, v in data.model_dump(exclude_none=True).items():
        setattr(product, k, v)
    db.commit()
    db.refresh(product)
    return product


@router.delete("/{product_id}", status_code=204)
def delete_product(
    product_id: str,
    current_user: User = Depends(get_current_user),
    db: Session        = Depends(get_db),
):
    product = db.query(Product).filter(Product.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    if current_user.role != UserRole.ADMIN and product.vendor_id != current_user.id:
        raise HTTPException(status_code=403, detail="Access denied")
    product.is_deleted = True
    db.commit()
