# Python Patterns and Examples

Detailed patterns and examples for Python projects.

## Modular API Design (FastAPI)
```python
# src/main.py
from fastapi import FastAPI
from .routes import items

app = FastAPI()
app.include_router(items.router, prefix="/items")

# src/routes/items.py
from fastapi import APIRouter

router = APIRouter()

@router.get("/{item_id}")
async def read_item(item_id: int):
    return {"item_id": item_id}
```
- **Pattern**: Organize routes in separate modules with `APIRouter` for scalability.
- **Benefit**: Keeps the main app clean and supports large codebases.

## Comprehensive Testing
```python
# tests/test_items.py
from fastapi.testclient import TestClient
from src.main import app

client = TestClient(app)

def test_read_item():
    response = client.get("/items/1")
    assert response.status_code == 200
    assert response.json() == {"item_id": 1}
```
- **Pattern**: Use `TestClient` for integration tests; isolate unit tests in `tests/unit/`.
- **Pitfall to Avoid**: Don’t mock excessively; test real behavior where possible.

## Best Practices
- Use type hints and enforce with `mypy`.
- Format code with `ruff format .` and lint with `ruff check .`.
- Sort imports with `isort`.
- Document APIs in `@.claude/docs/api-reference.md`.