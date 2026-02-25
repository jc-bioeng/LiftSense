from fastapi import FastAPI
from backend.biomech_engine import get_pipeline_registry

app = FastAPI(title='LifeSense Biomechanics API')

@app.get('/')
def read_root():
    return {
        'message': 'LifeSense API is running',
        'engine': 'Decoupled Biomech Engine Initialized',
        'available_pipelines': list(get_pipeline_registry().keys())
    }

@app.post('/analyze')
def analyze_movement(movement_data: dict, pipeline_name: str = "squat_v1"):
    # This will coordinate between services/domain and biomech_engine
    return {"status": "Analysis received", "pipeline": pipeline_name}
