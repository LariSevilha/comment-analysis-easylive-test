# Comment Analyzer API (Docker Version)

API de análise de comentários construída com Rails 8, PostgreSQL e Redis, preparada para rodar via Docker Compose.

---

## ✅ Requisitos

* Docker
* Docker Compose

---

## 📦 Como Rodar

### 1️⃣ Clonar o projeto:

```bash
git clone git@github.com:LariSevilha/comment-analysis-easylive-test.git
cd comment-analysis-easylive-test
```

### 2️⃣ Subir os containers:

```bash
docker-compose up --build
```

### 3️⃣ Criar o banco, rodar migrations e seeds:

```bash
docker compose run --rm web rails db:drop db:create db:migrate db:seed

```

---

## 🛠️ Comandos Úteis

### Criar Palavras-chave (Exemplo via cURL)

```bash
curl -X POST http://localhost:3000/api/v1/keywords \
-H "Content-Type: application/json" \
-d '{"keyword": {"word": "excelente", "active": true, "description": "Palavra positiva"}}'
```

### Iniciar Análise

```bash
curl -X POST http://localhost:3000/api/v1/analyses \
-H "Content-Type: application/json" \
-d '{"username": "Bret"}'
```

### Consultar Análise

```bash
curl -X GET http://localhost:3000/api/v1/analyses/1
```

### Reprocessar Comentário

```bash
curl -X POST http://localhost:3000/api/v1/comments/1/reprocess
```
 
### Consultar Métricas do Grupo 

```bash
curl -X GET http://localhost:3000/api/v1/metrics/group
```

### Criar Usuário, Post e Comentário (via Rails Console)
 
```bash 
user = User.find_or_create_by!(username: 'Bret') do |u|
  u.name = 'Leanne Graham'
  u.email = 'Sincere@april.biz'
  u.external_id = 1
end

post = user.posts.find_or_create_by!(external_id: 1) do |p|
  p.title = "Título do Post Exemplo"
  p.body = "Conteúdo do post para teste."
end

comment = post.comments.find_or_create_by!(external_id: 1) do |c|
  c.body = "Comentário de teste"
  c.name = "Comentador Teste"
  c.email = "comentador@teste.com"
  c.user = user
  c.status = "pending"
end
```
---

## ⚙️ Configurações Docker

* PostgreSQL: porta local `5544`
* Redis: porta local `6380`
* Rails: porta local `3000`

### Exemplo de conexão com PostgreSQL local:

```bash
psql -h localhost -p 5544 -U postgres -d comment_analysis_development
```

Senha padrão: `password`

---

## 📑 Observação

* Sidekiq roda automaticamente com o `docker compose up`.
* Logs do Sidekiq e do Rails são exibidos diretamente no terminal do Docker Compose.
