from sqlalchemy import Column, String, Integer, Float, ForeignKey, JSON
from sqlalchemy.orm import relationship
from app.infrastructure.database import Base
import uuid

class RawData(Base):
    __tablename__ = "raw_data"

    id = Column(String, primary_key=True, index=True, default=lambda: str(uuid.uuid4()))
    job_id = Column(String, ForeignKey("analysis_jobs.id"), index=True)
    frame = Column(Integer, index=True)
    time_ms = Column(Float)
    
    # Store all landmarks (33) as JSON to keep flexibility and save column space
    landmarks_json = Column(JSON)

    job = relationship("AnalysisJob", back_populates="raw_data")
