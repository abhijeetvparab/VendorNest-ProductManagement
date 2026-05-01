import uuid
from datetime import datetime
from sqlalchemy import Column, String, Text, Boolean, DateTime, ForeignKey
from sqlalchemy.dialects.mysql import CHAR
from sqlalchemy.orm import relationship
from database import Base


def _gen_uuid() -> str:
    return str(uuid.uuid4())


class Product(Base):
    __tablename__ = "products"

    id              = Column(CHAR(36), primary_key=True, default=_gen_uuid)
    vendor_id       = Column(CHAR(36), ForeignKey("users.id", ondelete="CASCADE"),
                             nullable=False, index=True)
    name            = Column(String(150), nullable=False)
    description     = Column(Text, nullable=True)
    unit            = Column(String(50), nullable=False)
    is_available    = Column(Boolean, nullable=False, default=True)
    is_subscribable = Column(Boolean, nullable=False, default=False)
    is_deleted      = Column(Boolean, nullable=False, default=False)
    created_at      = Column(DateTime, default=datetime.utcnow)
    updated_at      = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    vendor = relationship("User", foreign_keys=[vendor_id])
