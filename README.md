psql -U postgres
CREATE ROLE comment_analyzer WITH LOGIN PASSWORD 'password';
CREATE ROLE
postgres=# ALTER ROLE comment_analyzer CREATEDB;
ALTER ROLE
curl -X POST http://localhost:3000/api/v1/keywords -H "Content-Type: application/json" -d '{"keyword": {"word": "teste"}}'
curl http://localhost:3000/api/v1/keywords
curl -X POST http://localhost:3000/api/v1/users/Bret/analyze -H "Content-Type: application/json" -d '{"username": "Bret"}'
curl http://localhost:3000/api/v1/progress/Bret
curl http://localhost:3000/api/v1/users/Bret
curl http://localhost:3000/api/v1/users/Bret/comments
curl http://localhost:3000/api/v1/metrics/group
curl -X POST http://localhost:3000/api/v1/metrics/recalculate
curl http://localhost:3000/api/v1/progress

# Listar keywords atuais
curl -X GET http://localhost:3000/api/v1/keywords

# Adicionar nova keyword
curl -X POST http://localhost:3000/api/v1/keywords \
  -H "Content-Type: application/json" \
  -d '{"keyword": {"word": "incrível"}}'

# Atualizar keyword (substitua ID)
curl -X PUT http://localhost:3000/api/v1/keywords/1 \
  -H "Content-Type: application/json" \
  -d '{"keyword": {"word": "fantástico"}}'

# Deletar keyword (substitua ID)
curl -X DELETE http://localhost:3000/api/v1/keywords/1

curl -X GET http://localhost:3000/api/v1/users/Bret


curl -X POST http://localhost:3000/api/v1/users/analyze \
  -H "Content-Type: application/json" \
  -d '{"username": "Bret"}'