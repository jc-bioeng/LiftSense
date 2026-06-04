from sqlalchemy import Column, String, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from app.infrastructure.database import Base
import uuid
from datetime import datetime

class AnalysisJob(Base):
    __tablename__ = "analysis_jobs"

    id = Column(String, primary_key=True, index=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, ForeignKey("users.id"))
    video_path = Column(String, nullable=True)
    status = Column(String, default="pending")
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    user = relationship("User")
    raw_data = relationship("RawData", back_populates="job")
    processed_results = relationship("ProcessedResult", back_populates="job")
