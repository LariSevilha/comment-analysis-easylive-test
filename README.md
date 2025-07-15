psql -U postgres
CREATE ROLE comment_analyzer WITH LOGIN PASSWORD 'password';
CREATE ROLE
postgres=# ALTER ROLE comment_analyzer CREATEDB;
ALTER ROLE
curl -X POST http://localhost:3000/api/v1/keywords -H "Content-Type: application/json" -d '{"keyword": {"word": "ok"}}' 
{"id":2,"word":"ok","created_at":"2025-07-15T17:27:01.756Z","updated_at":"2025-07-15T17:27:01.756Z"}