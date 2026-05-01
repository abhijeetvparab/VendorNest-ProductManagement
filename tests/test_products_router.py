import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest
from conftest import auth_header
from models import UserRole, UserStatus, Product

# ── Shared payload ────────────────────────────────────────────────────────────

PRODUCT_PAYLOAD = {
    "name":            "Fresh Tomatoes",
    "description":     "Locally sourced red tomatoes",
    "unit":            "kg",
    "is_available":    True,
    "is_subscribable": False,
}


def make_product(db, vendor_user, **overrides):
    """Create a Product directly in the DB, bypassing the API."""
    defaults = {
        "name":            "Test Product",
        "description":     "A test product description",
        "unit":            "kg",
        "is_available":    True,
        "is_subscribable": False,
        "is_deleted":      False,
    }
    defaults.update(overrides)
    product = Product(vendor_id=vendor_user.id, **defaults)
    db.add(product)
    db.commit()
    db.refresh(product)
    return product


# ── Create Product ────────────────────────────────────────────────────────────

class TestCreateProduct:
    def test_vendor_can_create_product(self, client, db, make_user):
        vendor = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        r = client.post("/api/products", json=PRODUCT_PAYLOAD, headers=auth_header(vendor))
        assert r.status_code == 201
        data = r.json()
        assert data["name"] == "Fresh Tomatoes"
        assert data["unit"] == "kg"
        assert data["vendor_id"] == vendor.id

    def test_product_defaults_available_true(self, client, db, make_user):
        vendor = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        payload = {k: v for k, v in PRODUCT_PAYLOAD.items() if k != "is_available"}
        r = client.post("/api/products", json=payload, headers=auth_header(vendor))
        assert r.status_code == 201
        assert r.json()["is_available"] is True

    def test_product_defaults_subscribable_false(self, client, db, make_user):
        vendor = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        payload = {k: v for k, v in PRODUCT_PAYLOAD.items() if k != "is_subscribable"}
        r = client.post("/api/products", json=payload, headers=auth_header(vendor))
        assert r.status_code == 201
        assert r.json()["is_subscribable"] is False

    def test_product_is_not_deleted_on_create(self, client, db, make_user):
        vendor = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        r = client.post("/api/products", json=PRODUCT_PAYLOAD, headers=auth_header(vendor))
        assert r.json()["is_deleted"] is False

    def test_response_includes_id_and_timestamps(self, client, db, make_user):
        vendor = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        r = client.post("/api/products", json=PRODUCT_PAYLOAD, headers=auth_header(vendor))
        data = r.json()
        assert "id" in data
        assert "created_at" in data
        assert "updated_at" in data

    def test_null_description_is_accepted(self, client, db, make_user):
        vendor = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        r = client.post("/api/products",
                        json={**PRODUCT_PAYLOAD, "description": None},
                        headers=auth_header(vendor))
        assert r.status_code == 201
        assert r.json()["description"] is None

    def test_customer_cannot_create_product(self, client, db, make_user):
        customer = make_user(db, role=UserRole.CUSTOMER)
        r = client.post("/api/products", json=PRODUCT_PAYLOAD, headers=auth_header(customer))
        assert r.status_code == 403
        assert "vendors" in r.json()["detail"].lower()

    def test_admin_cannot_create_product(self, client, db, make_user):
        admin = make_user(db, role=UserRole.ADMIN)
        r = client.post("/api/products", json=PRODUCT_PAYLOAD, headers=auth_header(admin))
        assert r.status_code == 403

    def test_unauthenticated_is_rejected(self, client):
        r = client.post("/api/products", json=PRODUCT_PAYLOAD)
        assert r.status_code in (401, 403)

    def test_empty_name_returns_422(self, client, db, make_user):
        vendor = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        r = client.post("/api/products",
                        json={**PRODUCT_PAYLOAD, "name": "   "},
                        headers=auth_header(vendor))
        assert r.status_code == 422

    def test_empty_unit_returns_422(self, client, db, make_user):
        vendor = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        r = client.post("/api/products",
                        json={**PRODUCT_PAYLOAD, "unit": ""},
                        headers=auth_header(vendor))
        assert r.status_code == 422

    def test_description_over_500_chars_returns_422(self, client, db, make_user):
        vendor = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        r = client.post("/api/products",
                        json={**PRODUCT_PAYLOAD, "description": "x" * 501},
                        headers=auth_header(vendor))
        assert r.status_code == 422

    def test_description_exactly_500_chars_is_accepted(self, client, db, make_user):
        vendor = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        r = client.post("/api/products",
                        json={**PRODUCT_PAYLOAD, "description": "x" * 500},
                        headers=auth_header(vendor))
        assert r.status_code == 201


# ── List Products ─────────────────────────────────────────────────────────────

class TestListProducts:
    def test_vendor_sees_own_products_only(self, client, db, make_user):
        v1 = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        v2 = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        make_product(db, v1, name="V1 Product")
        make_product(db, v2, name="V2 Product")
        r = client.get("/api/products", headers=auth_header(v1))
        assert r.status_code == 200
        names = [p["name"] for p in r.json()]
        assert "V1 Product" in names
        assert "V2 Product" not in names

    def test_vendor_id_param_ignored_for_vendor_role(self, client, db, make_user):
        v1 = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        v2 = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        make_product(db, v1, name="V1 Product")
        make_product(db, v2, name="V2 Product")
        r = client.get(f"/api/products?vendor_id={v2.id}", headers=auth_header(v1))
        assert r.status_code == 200
        names = [p["name"] for p in r.json()]
        assert "V2 Product" not in names

    def test_admin_sees_all_products(self, client, db, make_user):
        admin = make_user(db, role=UserRole.ADMIN)
        v1 = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        v2 = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        make_product(db, v1, name="V1 Product")
        make_product(db, v2, name="V2 Product")
        r = client.get("/api/products", headers=auth_header(admin))
        assert r.status_code == 200
        names = [p["name"] for p in r.json()]
        assert "V1 Product" in names
        assert "V2 Product" in names

    def test_admin_can_filter_by_vendor_id(self, client, db, make_user):
        admin = make_user(db, role=UserRole.ADMIN)
        v1 = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        v2 = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        make_product(db, v1, name="V1 Product")
        make_product(db, v2, name="V2 Product")
        r = client.get(f"/api/products?vendor_id={v1.id}", headers=auth_header(admin))
        assert r.status_code == 200
        data = r.json()
        assert len(data) == 1
        assert data[0]["name"] == "V1 Product"

    def test_deleted_products_excluded_by_default(self, client, db, make_user):
        vendor = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        make_product(db, vendor, name="Active Product",  is_deleted=False)
        make_product(db, vendor, name="Deleted Product", is_deleted=True)
        r = client.get("/api/products", headers=auth_header(vendor))
        names = [p["name"] for p in r.json()]
        assert "Active Product"  in names
        assert "Deleted Product" not in names

    def test_include_deleted_shows_all_products(self, client, db, make_user):
        vendor = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        make_product(db, vendor, name="Active Product",  is_deleted=False)
        make_product(db, vendor, name="Deleted Product", is_deleted=True)
        r = client.get("/api/products?include_deleted=true", headers=auth_header(vendor))
        names = [p["name"] for p in r.json()]
        assert "Active Product"  in names
        assert "Deleted Product" in names

    def test_customer_cannot_list_products(self, client, db, make_user):
        customer = make_user(db, role=UserRole.CUSTOMER)
        r = client.get("/api/products", headers=auth_header(customer))
        assert r.status_code == 403

    def test_unauthenticated_is_rejected(self, client):
        r = client.get("/api/products")
        assert r.status_code in (401, 403)

    def test_returns_empty_list_when_vendor_has_no_products(self, client, db, make_user):
        vendor = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        r = client.get("/api/products", headers=auth_header(vendor))
        assert r.json() == []

    def test_products_ordered_most_recent_first(self, client, db, make_user):
        vendor = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        make_product(db, vendor, name="First")
        make_product(db, vendor, name="Second")
        make_product(db, vendor, name="Third")
        r = client.get("/api/products", headers=auth_header(vendor))
        names = [p["name"] for p in r.json()]
        assert names[0] == "Third"
        assert names[-1] == "First"


# ── Get Product ───────────────────────────────────────────────────────────────

class TestGetProduct:
    def test_vendor_can_get_own_product(self, client, db, make_user):
        vendor = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        product = make_product(db, vendor, name="My Product")
        r = client.get(f"/api/products/{product.id}", headers=auth_header(vendor))
        assert r.status_code == 200
        assert r.json()["name"] == "My Product"

    def test_vendor_cannot_get_other_vendors_product(self, client, db, make_user):
        v1 = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        v2 = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        product = make_product(db, v2)
        r = client.get(f"/api/products/{product.id}", headers=auth_header(v1))
        assert r.status_code == 403

    def test_admin_can_get_any_product(self, client, db, make_user):
        admin  = make_user(db, role=UserRole.ADMIN)
        vendor = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        product = make_product(db, vendor)
        r = client.get(f"/api/products/{product.id}", headers=auth_header(admin))
        assert r.status_code == 200
        assert r.json()["id"] == product.id

    def test_nonexistent_product_returns_404(self, client, db, make_user):
        vendor = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        r = client.get("/api/products/no-such-id", headers=auth_header(vendor))
        assert r.status_code == 404
        assert "not found" in r.json()["detail"].lower()

    def test_response_contains_all_expected_fields(self, client, db, make_user):
        vendor = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        product = make_product(db, vendor)
        r = client.get(f"/api/products/{product.id}", headers=auth_header(vendor))
        data = r.json()
        for field in ["id", "vendor_id", "name", "unit", "is_available",
                      "is_subscribable", "is_deleted", "created_at", "updated_at"]:
            assert field in data

    def test_unauthenticated_is_rejected(self, client, db, make_user):
        vendor = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        product = make_product(db, vendor)
        r = client.get(f"/api/products/{product.id}")
        assert r.status_code in (401, 403)


# ── Update Product ────────────────────────────────────────────────────────────

class TestUpdateProduct:
    def test_vendor_can_update_own_product_name(self, client, db, make_user):
        vendor = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        product = make_product(db, vendor, name="Old Name")
        r = client.patch(f"/api/products/{product.id}",
                         json={"name": "New Name"},
                         headers=auth_header(vendor))
        assert r.status_code == 200
        assert r.json()["name"] == "New Name"

    def test_vendor_cannot_update_other_vendors_product(self, client, db, make_user):
        v1 = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        v2 = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        product = make_product(db, v2)
        r = client.patch(f"/api/products/{product.id}",
                         json={"name": "Hacked"},
                         headers=auth_header(v1))
        assert r.status_code == 403

    def test_admin_can_update_any_product(self, client, db, make_user):
        admin  = make_user(db, role=UserRole.ADMIN)
        vendor = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        product = make_product(db, vendor, name="Original")
        r = client.patch(f"/api/products/{product.id}",
                         json={"name": "Admin Updated"},
                         headers=auth_header(admin))
        assert r.status_code == 200
        assert r.json()["name"] == "Admin Updated"

    def test_partial_update_leaves_other_fields_unchanged(self, client, db, make_user):
        vendor = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        product = make_product(db, vendor, name="Original", unit="kg", is_available=True)
        r = client.patch(f"/api/products/{product.id}",
                         json={"name": "Changed"},
                         headers=auth_header(vendor))
        data = r.json()
        assert data["name"] == "Changed"
        assert data["unit"] == "kg"
        assert data["is_available"] is True

    def test_can_toggle_availability_off(self, client, db, make_user):
        vendor = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        product = make_product(db, vendor, is_available=True)
        r = client.patch(f"/api/products/{product.id}",
                         json={"is_available": False},
                         headers=auth_header(vendor))
        assert r.json()["is_available"] is False

    def test_can_enable_subscribable(self, client, db, make_user):
        vendor = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        product = make_product(db, vendor, is_subscribable=False)
        r = client.patch(f"/api/products/{product.id}",
                         json={"is_subscribable": True},
                         headers=auth_header(vendor))
        assert r.json()["is_subscribable"] is True

    def test_can_update_description(self, client, db, make_user):
        vendor = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        product = make_product(db, vendor, description="Old desc")
        r = client.patch(f"/api/products/{product.id}",
                         json={"description": "New desc"},
                         headers=auth_header(vendor))
        assert r.json()["description"] == "New desc"

    def test_nonexistent_product_returns_404(self, client, db, make_user):
        vendor = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        r = client.patch("/api/products/no-such-id",
                         json={"name": "X"},
                         headers=auth_header(vendor))
        assert r.status_code == 404

    def test_unauthenticated_is_rejected(self, client, db, make_user):
        vendor = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        product = make_product(db, vendor)
        r = client.patch(f"/api/products/{product.id}", json={"name": "X"})
        assert r.status_code in (401, 403)


# ── Delete Product ────────────────────────────────────────────────────────────

class TestDeleteProduct:
    def test_vendor_can_soft_delete_own_product(self, client, db, make_user):
        vendor = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        product = make_product(db, vendor)
        r = client.delete(f"/api/products/{product.id}", headers=auth_header(vendor))
        assert r.status_code == 204

    def test_soft_delete_sets_is_deleted_flag_in_db(self, client, db, make_user):
        vendor = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        product = make_product(db, vendor)
        client.delete(f"/api/products/{product.id}", headers=auth_header(vendor))
        db.refresh(product)
        assert product.is_deleted is True

    def test_soft_delete_does_not_remove_record_from_db(self, client, db, make_user):
        vendor = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        product = make_product(db, vendor)
        client.delete(f"/api/products/{product.id}", headers=auth_header(vendor))
        still_exists = db.query(Product).filter(Product.id == product.id).first()
        assert still_exists is not None

    def test_vendor_cannot_delete_other_vendors_product(self, client, db, make_user):
        v1 = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        v2 = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        product = make_product(db, v2)
        r = client.delete(f"/api/products/{product.id}", headers=auth_header(v1))
        assert r.status_code == 403

    def test_admin_can_soft_delete_any_product(self, client, db, make_user):
        admin  = make_user(db, role=UserRole.ADMIN)
        vendor = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        product = make_product(db, vendor)
        r = client.delete(f"/api/products/{product.id}", headers=auth_header(admin))
        assert r.status_code == 204

    def test_deleted_product_excluded_from_default_list(self, client, db, make_user):
        vendor = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        product = make_product(db, vendor, name="Soon Deleted")
        client.delete(f"/api/products/{product.id}", headers=auth_header(vendor))
        r = client.get("/api/products", headers=auth_header(vendor))
        names = [p["name"] for p in r.json()]
        assert "Soon Deleted" not in names

    def test_deleted_product_visible_with_include_deleted(self, client, db, make_user):
        vendor = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        product = make_product(db, vendor, name="Soft Deleted")
        client.delete(f"/api/products/{product.id}", headers=auth_header(vendor))
        r = client.get("/api/products?include_deleted=true", headers=auth_header(vendor))
        names = [p["name"] for p in r.json()]
        assert "Soft Deleted" in names

    def test_customer_cannot_delete_product(self, client, db, make_user):
        customer = make_user(db, role=UserRole.CUSTOMER)
        vendor   = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        product  = make_product(db, vendor)
        r = client.delete(f"/api/products/{product.id}", headers=auth_header(customer))
        assert r.status_code == 403

    def test_nonexistent_product_returns_404(self, client, db, make_user):
        vendor = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        r = client.delete("/api/products/no-such-id", headers=auth_header(vendor))
        assert r.status_code == 404

    def test_unauthenticated_is_rejected(self, client, db, make_user):
        vendor = make_user(db, role=UserRole.VENDOR, status=UserStatus.ACTIVE)
        product = make_product(db, vendor)
        r = client.delete(f"/api/products/{product.id}")
        assert r.status_code in (401, 403)
