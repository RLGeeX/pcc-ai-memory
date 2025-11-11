# Python Examples

Sample code and best practices for Python projects.

## Async API Endpoint (FastAPI)
```python
from fastapi import FastAPI

app = FastAPI()

@app.get("/items/{item_id}")
async def read_item(item_id: int):
    return {"item_id": item_id}
```
- **Best Practice**: Use async/await for non-blocking I/O in API endpoints.

## Unit Test with Pytest
```python
# tests/test_example.py
def test_add():
    assert 1 + 1 == 2
```
- **Best Practice**: Write concise, isolated tests; run with `pytest tests/unit/`.

## Reference
See `@docs/python-patterns.md` for detailed patterns.