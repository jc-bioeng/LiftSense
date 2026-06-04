from sqlalchemy import Column, String, Integer, Float, Boolean, ForeignKey
from sqlalchemy.orm import relationship
from app.infrastructure.database import Base
import uuid

class ProcessedResult(Base):
    __tablename__ = "processed_results"

    id = Column(String, primary_key=True, index=True, default=lambda: str(uuid.uuid4()))
    job_id = Column(String, ForeignKey("analysis_jobs.id"), index=True)
    frame = Column(Integer, index=True)
    time_ms = Column(Float)
    
    # Biomechanical features
    com_x = Column(Float, nullable=True)
    com_y = Column(Float, nullable=True)
    c7_x = Column(Float, nullable=True)
    c7_y = Column(Float, nullable=True)
    mid_foot_x = Column(Float, nullable=True)
    view_type = Column(String, nullable=True)
    has_barbell = Column(Boolean, default=False)
    
    job = relationship("AnalysisJob", back_populates="processed_results")
