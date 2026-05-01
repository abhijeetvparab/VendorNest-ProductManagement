from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import inspect as sa_inspect, text
from router import router as products_router
from database import engine
import models

models.Base.metadata.create_all(bind=engine)

# Migrate products table: normalise to single unit VARCHAR(50)
with engine.begin() as _conn:
    try:
        _inspector = sa_inspect(engine)
        if "products" in _inspector.get_table_names():
            _cols = {c["name"] for c in _inspector.get_columns("products")}
            if "type" in _cols:
                _conn.execute(text("ALTER TABLE products DROP COLUMN type"))
            if "units" in _cols and "unit" not in _cols:
                _conn.execute(text("ALTER TABLE products ADD COLUMN unit VARCHAR(50) NOT NULL DEFAULT ''"))
                _conn.execute(text(
                    "UPDATE products SET unit = COALESCE(JSON_UNQUOTE(JSON_EXTRACT(units, '$[0]')), '')"
                ))
                _conn.execute(text("ALTER TABLE products DROP COLUMN units"))
    except Exception as _e:
        print(f"[migration] products: {_e}")

app = FastAPI(
    title       = "VendorNest Product Management API",
    version     = "1.0.0",
    description = "Product Management Service",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins  = ["*"],
    allow_methods  = ["*"],
    allow_headers  = ["*"],
)

app.include_router(products_router)


@app.get("/", tags=["Health"])
def root():
    return {"status": "ok", "app": "VendorNest Product Management API", "version": "1.0.0", "docs": "/docs"}


@app.get("/health", tags=["Health"])
def health():
    return {"status": "healthy"}
