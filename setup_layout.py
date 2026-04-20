import os

dirs = [
    "backend/app/api",
    "backend/app/services",
    "backend/app/models",
    "backend/app/core",
    "research/experiments",
    "research/notebooks",
    "research/validation",
    "docs/decisions",
    "docs/architecture",
    "docs/diagrams",
    ".github/workflows",
]

for d in dirs:
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, ".gitkeep"), "w") as f:
        pass

files = {
    "backend/app/main.py": "from fastapi import FastAPI\n\napp = FastAPI(title='LifeSense Biomechanics API')\n\n@app.get('/')\ndef read_root():\n    return {'message': 'LifeSense API is running'}\n",
    "backend/requirements.txt": "fastapi\nuvicorn\nmediapipe\nopencv-python\nnumpy\n",
    "backend/Dockerfile": "FROM python:3.9-slim\n\nWORKDIR /app\nCOPY requirements.txt .\nRUN pip install --no-cache-dir -r requirements.txt\nCOPY app/ ./app/\n\nCMD [\"uvicorn\", \"app.main:app\", \"--host\", \"0.0.0.0\", \"--port\", \"8000\"]\n",
    "VERSION": "0.1.0\n",
}

for path, content in files.items():
    with open(path, "w") as f:
        f.write(content)

# Append to .gitignore if it exists, or create it
gitignore_content = "\n# Python Backend\nvenv/\n__pycache__/\n*.pyc\n.env\n"
mode = "a" if os.path.exists(".gitignore") else "w"
with open(".gitignore", mode) as f:
    f.write(gitignore_content)
