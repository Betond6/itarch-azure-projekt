import os
import socket

import psycopg
from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI(title="IT-architektúra projekt API")
DB = os.environ["DATABASE_URL"]


class Item(BaseModel):
    name: str


@app.get("/api/health")
def health():
    return {"status": "ok", "container": socket.gethostname()}


@app.get("/api/items")
def list_items():
    with psycopg.connect(DB) as conn:
        rows = conn.execute("SELECT id, name, created_at FROM items ORDER BY id").fetchall()
    return [{"id": r[0], "name": r[1], "created_at": r[2].isoformat()} for r in rows]


@app.post("/api/items", status_code=201)
def add_item(item: Item):
    with psycopg.connect(DB) as conn:
        new_id = conn.execute(
            "INSERT INTO items(name) VALUES (%s) RETURNING id", (item.name,)
        ).fetchone()[0]
    return {"id": new_id, "name": item.name}
