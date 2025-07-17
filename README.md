# Comment Analysis Pipeline

Sistema de análise de comentários com importação de dados, tradução, classificação por palavras-chave e cálculo de métricas estatísticas por usuário e grupo.

---

## 🏗️ Arquitetura

### Visão Geral do Sistema

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   API Client    │───▶│  Rails API       │───▶│  Background     │
│                 │    │  Controllers     │    │  Jobs           │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │                        │
                                ▼                        ▼
                       ┌──────────────────┐    ┌─────────────────┐
                       │  Service Layer   │    │  External APIs  │
                       │  - Import        │    │  - JSONPlace    │
                       │  - Translation   │    │  - LibreTranslate│
                       │  - Classification│    └─────────────────┘
                       │  - Metrics       │              │
                       └──────────────────┘              │
                                │                        │
                                ▼                        ▼
                       ┌──────────────────┐    ┌─────────────────┐
                       │  State Machine   │    │  Solid Cache    │
                       │  (AASM)          │    │  (Database)     │
                       └──────────────────┘    └─────────────────┘
                                │                        │
                                ▼                        ▼
                       ┌─────────────────────────────────────────┐
                       │           PostgreSQL Database           │
                       │  - Application Data                     │
                       │  - Solid Queue (Background Jobs)       │
                       │  - Solid Cache (Caching Layer)         │
                       └─────────────────────────────────────────┘
```

### Fluxo de Processamento

1. **Importação**: Busca usuário por username na JSONPlaceholder API
2. **Recursão**: Importa posts do usuário e comentários de cada post
3. **Estado**: Comentários iniciam no estado "new"
4. **Tradução**: Background job traduz comentários para PT-BR
5. **Classificação**: Analisa palavras-chave (≥2 = aprovado, <2 = rejeitado)
6. **Métricas**: Calcula estatísticas por usuário e grupo
7. **Cache**: Otimiza performance com Solid Cache


## ✅ Configuração do Projeto

### Requisitos

- Ruby >= 3.0  
- Rails >= 7.0  
- PostgreSQL >= 12  
- Docker e Docker Compose (opcional)

---

## 📥 Instalação Local

```bash
git clone git@github.com:LariSevilha/comment-analysis-easylive-test.git

cd comment-analysis-easylive-test

bundle install

cp config/database.yml.example config/database.yml
# Edite config/database.yml

cp .env.example .env
# Edite .env

rails db:create
rails db:migrate
rails db:seed

rails server

# Em outro terminal:
bundle exec solid_queue:start


 🐳 Instalação com Docker 
git clone git@github.com:LariSevilha/comment-analysis-easylive-test.git

cd comment-analysis-easylive-test

cp .env.example .env

bin/docker_setup
```
 
```bash

🔌 API Endpoints Principais 
# Analisar comentários por username
curl -X POST http://localhost:3000/api/comments/analyze \
-H "Content-Type: application/json" \
-d '{"username":"Bret"}'

# Verificar progresso do job
curl http://localhost:3000/api/comments/progress/<job_id>

# Consultar métricas do usuário
curl http://localhost:3000/api/comments/metrics/Bret

### Implementação

As fórmulas são implementadas usando a gem `descriptive_statistics`:

```ruby
# app/services/metrics_service.rb
keyword_counts = comments.map(&:keyword_count)

{
  mean: keyword_counts.mean,
  median: keyword_counts.median,
  standard_deviation: keyword_counts.standard_deviation
}
```
---

```bash

  🔌 API Endpoints

### Análise de Comentários

```http
POST /api/comments/analyze
Content-Type: application/json

{
  "username": "Bret"
}
```

**Resposta:**

```json
{
  "job_id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "started",
  "message": "Analysis started for user Bret"
}
```
---

```bash

### Progresso do Job

```http
GET /api/comments/progress/550e8400-e29b-41d4-a716-446655440000
```

**Resposta:**

```json
{
  "job_id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "processing",
  "progress": 75,
  "total": 100,
  "current_step": "translating_comments"
}
```
---

```bash
### Métricas do Usuário

```http
GET /api/comments/metrics/Bret
```

**Resposta:**

```json
{
  "user_metrics": {
    "username": "Bret",
    "total_comments": 50,
    "approved_comments": 32,
    "rejected_comments": 18,
    "approval_rate": 64.0,
    "statistics": {
      "mean": 2.4,
      "median": 2.0,
      "standard_deviation": 1.2
    }
  },
  "group_metrics": {
    "total_users": 5,
    "total_comments": 250,
    "approved_comments": 160,
    "rejected_comments": 90,
    "approval_rate": 64.0,
    "statistics": {
      "mean": 2.1,
      "median": 2.0,
      "standard_deviation": 1.4
    }
  }
}
```
---

```bash
# Listar palavras-chave
curl http://localhost:3000/api/keywords

# Criar palavra-chave
curl -X POST http://localhost:3000/api/keywords \
-H "Content-Type: application/json" \
-d '{"word":"exemplo"}'

# Atualizar palavra-chave
curl -X PUT http://localhost:3000/api/keywords/1 \
-H "Content-Type: application/json" \
-d '{"word":"atualizado"}'

# Deletar palavra-chave
curl -X DELETE http://localhost:3000/api/keywords/1

```
---

```bash

🔄 Comandos de Desenvolvimento 
rails server
bundle exec solid_queue:start
rails console
rails db:seed
rails db:drop db:create db:migrate db:seed
rails db:migrate:status
```
---

```bash

⚙️ Background Jobs 
rails solid_queue:status
rails solid_queue:clear_finished_jobs
rails solid_queue:retry_failed_jobs
```
---

```bash

🗂️ Cache
rails cache:clear
rails solid_cache:stats
rails solid_cache:clear_expired
```
---

```bash

📊 Análise Manual via Console 

rails runner "CommentAnalysisService.new.analyze_user('Bret')"
rails runner "MetricsRecalculationJob.perform_now"
rails runner "puts Keyword.pluck(:word).join(', ')"
```
