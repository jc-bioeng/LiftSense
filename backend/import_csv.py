import os
import sys
import csv
import json

# Add backend to path
sys.path.insert(0, os.path.realpath(os.path.join(os.path.dirname(__file__))))

from app.infrastructure.database import SessionLocal
from app.models.user import User
from app.models.analysis_job import AnalysisJob
from app.models.raw_data import RawData
from app.models.processed_result import ProcessedResult

def import_data():
    db = SessionLocal()
    
    # 1. Create a dummy user
    user = User(name="Test User")
    db.add(user)
    db.commit()
    db.refresh(user)
    
    # 2. Create an analysis job
    job = AnalysisJob(user_id=user.id, video_path="frontal_video.mp4", status="completed")
    db.add(job)
    db.commit()
    db.refresh(job)
    
    # 3. Import raw data from 1_landmarks.csv
    raw_csv_path = "../python_research/test/1_landmarks.csv"
    if os.path.exists(raw_csv_path):
        print(f"Importing raw data from {raw_csv_path}...")
        with open(raw_csv_path, 'r') as f:
            reader = csv.DictReader(f)
            raw_entries = []
            for row in reader:
                frame = int(row['frame'])
                time_ms = float(row['timestamp_ms'])
                landmarks = []
                # 33 landmarks
                for i in range(33):
                    lx = float(row.get(f'landmark_{i}_x', 0))
                    ly = float(row.get(f'landmark_{i}_y', 0))
                    lz = float(row.get(f'landmark_{i}_z', 0))
                    lv = float(row.get(f'landmark_{i}_v', 0))
                    landmarks.append({'x': lx, 'y': ly, 'z': lz, 'v': lv})
                
                raw_entries.append(RawData(
                    job_id=job.id,
                    frame=frame,
                    time_ms=time_ms,
                    landmarks_json=landmarks
                ))
            db.bulk_save_objects(raw_entries)
            db.commit()
            print(f"Inserted {len(raw_entries)} raw data frames.")
    
    # 4. Import processed results from frontal_lstrack.csv
    processed_csv_path = "../python_research/frontal_lstrack.csv"
    if os.path.exists(processed_csv_path):
        print(f"Importing processed data from {processed_csv_path}...")
        with open(processed_csv_path, 'r') as f:
            reader = csv.DictReader(f)
            processed_entries = []
            for row in reader:
                frame = int(row['frame'])
                time_ms = float(row['time_ms'])
                com_x = float(row['com_x']) if row.get('com_x') else None
                com_y = float(row['com_y']) if row.get('com_y') else None
                c7_x = float(row['c7_x']) if row.get('c7_x') else None
                c7_y = float(row['c7_y']) if row.get('c7_y') else None
                mid_foot_x = float(row['mid_foot_x']) if row.get('mid_foot_x') else None
                view_type = row.get('view_type')
                has_barbell = row.get('has_barbell', 'False').lower() == 'true'
                
                processed_entries.append(ProcessedResult(
                    job_id=job.id,
                    frame=frame,
                    time_ms=time_ms,
                    com_x=com_x,
                    com_y=com_y,
                    c7_x=c7_x,
                    c7_y=c7_y,
                    mid_foot_x=mid_foot_x,
                    view_type=view_type,
                    has_barbell=has_barbell
                ))
            db.bulk_save_objects(processed_entries)
            db.commit()
            print(f"Inserted {len(processed_entries)} processed data frames.")

    print("Data imported successfully.")
    
    # Verification query
    raw_count = db.query(RawData).count()
    processed_count = db.query(ProcessedResult).count()
    print(f"Verification: {raw_count} raw frames, {processed_count} processed frames in DB.")
    
    db.close()

if __name__ == "__main__":
    import_data()
