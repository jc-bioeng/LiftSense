from sqlalchemy import Column, String, DateTime
from app.infrastructure.database import Base
import uuid
from datetime import datetime

class User(Base):
    __tablename__ = "users"

    id = Column(String, primary_key=True, index=True, default=lambda: str(uuid.uuid4()))
    name = Column(String, index=True)
    created_at = Column(DateTime, default=datetime.utcnow)
