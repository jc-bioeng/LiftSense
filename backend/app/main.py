from fastapi import FastAPI

app = FastAPI(title='LifeSense Biomechanics API')

@app.get('/')
def read_root():
    return {'message': 'LifeSense API is running'}
