```markdown 

---

## 🚀 Visão Geral

O **Comment Analysis Pipeline** é uma solução moderna para importar, traduzir, classificar e analisar comentários de usuários. Ele integra-se a APIs externas, como JSONPlaceholder para importação de dados e LibreTranslate para tradução, utilizando filas assíncronas para processamento eficiente e cache para otimização de performance.

### Principais Funcionalidades
- **Importação de Dados**: Busca comentários de usuários via API externa (JSONPlaceholder).
- **Tradução Automática**: Traduz comentários para português brasileiro (PT-BR) usando LibreTranslate ou mock translations para desenvolvimento.
- **Classificação Inteligente**: Classifica comentários como "aprovado" ou "rejeitado" com base na contagem de palavras-chave (≥2 para aprovação).
- **Métricas Estatísticas**: Calcula métricas como média, mediana e desvio padrão de palavras-chave por usuário e grupo.
- **Gerenciamento Assíncrono**: Processa tarefas em segundo plano com Solid Queue.
- **Cache Otimizado**: Usa Solid Cache para melhorar a performance de traduções e classificações.

---

## 🏗️ Arquitetura do Sistema

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   API Client    │───▶│  Rails API       │───▶│  Background     │
│  (cURL/Postman) │    │  Controllers     │    │  Jobs           │
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
                       │  - Users, Posts, Comments, Keywords     │
                       │  - Solid Queue (Background Jobs)       │
                       │  - Solid Cache (Caching Layer)         │
                       └─────────────────────────────────────────┘
```

### Fluxo de Processamento
1. **Importação**: Busca usuários, posts e comentários da JSONPlaceholder API.
2. **Estado Inicial**: Comentários entram no estado "new" (máquina de estados AASM).
3. **Tradução**: Jobs assíncronos traduzem comentários para PT-BR.
4. **Classificação**: Analisa palavras-chave para aprovar (≥2) ou rejeitar (<2).
5. **Métricas**: Calcula estatísticas detalhadas usando a gem `descriptive_statistics`.
6. **Cache**: Armazena traduções e palavras-chave para otimizar performance.

---

## ✅ Requisitos

- **Ruby**: ≥ 3.0
- **Rails**: ≥ 7.0
- **PostgreSQL**: ≥ 12
- **Docker**: Opcional, para rodar o LibreTranslate ou a aplicação completa
- **Gems**: `httparty`, `descriptive_statistics`, `solid_queue`, `solid_cache`, `aasm`

---

## 📥 Instalação

### Instalação Local
1. Clone o repositório:
   ```bash
   git clone git@github.com:LariSevilha/comment-analysis-easylive-test.git
   cd comment-analysis-easylive-test
   ```

2. Instale as dependências:
   ```bash
   bundle install
   ```

3. Configure o banco de dados:
   ```bash
   cp config/database.yml.example config/database.yml
   # Edite config/database.yml com suas credenciais PostgreSQL
   rails db:create
   rails db:migrate
   rails db:seed
   ```

4. Configure variáveis de ambiente:
   ```bash
   cp .env.example .env
   # Edite .env (ex.: LIBRETRANSLATE_URL=http://localhost:5000)
   ```

5. Inicie o servidor e o sistema de filas:
   ```bash
   rails server
   # Em outro terminal:
   bundle exec solid_queue:start
   ```

### Instalação com Docker
1. Clone o repositório:
   ```bash
   git clone git@github.com:LariSevilha/comment-analysis-easylive-test.git
   cd comment-analysis-easylive-test
   ```

2. Configure variáveis de ambiente:
   ```bash
   cp .env.example .env
   # Edite .env, se necessário
   ```

3. Execute o setup do Docker:
   ```bash
   bin/docker_setup
   ```

4. Inicie os serviços:
   ```bash
   docker-compose up
   ```

---

## 🔌 Endpoints da API

### Usuários

#### 1. Criar um Novo Usuário
**Descrição**: Cria um usuário com username, nome, email e ID externo.  
**Método**: `POST /api/users`  
**Exemplo**:
```bash
curl -X POST http://localhost:3000/api/users \
-H "Content-Type: application/json" \
-d '{"user": {"username": "Bret", "name": "Bret User", "email": "bret@example.com", "external_id": "1000"}}'
```

**Resposta**:
```json
{
  "user": {
    "id": 2,
    "username": "Bret",
    "name": "Bret User",
    "email": "bret@example.com",
    "external_id": "1000"
  }
}
```

#### 2. Obter Perfil do Usuário Atual
**Descrição**: Retorna detalhes do usuário autenticado.  
**Método**: `GET /api/current_user`  
**Exemplo**:
```bash
curl -X GET http://localhost:3000/api/current_user \
-H "Authorization: Bearer your-auth-token"
```

**Resposta**:
```json
{
  "user": {
    "id": 1,
    "username": "testuser",
    "name": "Test User",
    "email": "test@example.com",
    "external_id": "999",
    "role": "user"
  }
}
```

#### 3. Atualizar Perfil do Usuário
**Descrição**: Atualiza nome ou email do usuário atual.  
**Método**: `PUT /api/current_user`  
**Exemplo**:
```bash
curl -X PUT http://localhost:3000/api/current_user \
-H "Content-Type: application/json" \
-H "Authorization: Bearer your-auth-token" \
-d '{"user": {"name": "Updated Test User", "email": "updated.test@example.com"}}'
```

**Resposta**:
```json
{
  "user": {
    "id": 1,
    "username": "testuser",
    "name": "Updated Test User",
    "email": "updated.test@example.com",
    "external_id": "999",
    "role": "user"
  }
}
```

### Comentários

#### 4. Listar Comentários
**Descrição**: Retorna todos os comentários com seus detalhes.  
**Método**: `GET /api/comments`  
**Exemplo**:
```bash
curl -X GET http://localhost:3000/api/comments
```

**Resposta**:
```json
{
  "comments": [
    {
      "id": 1,
      "name": "Positive Commenter",
      "email": "positive@test.com",
      "body": "This product is excellent and fantastic! I love it and think it's perfect.",
      "translated_body": "este produto é excelente e fantástico! eu amo isso and acho que é perfeito.",
      "status": "approved",
      "keyword_count": 3,
      "post_id": 1
    },
    {
      "id": 2,
      "name": "Latin Commenter",
      "email": "latin@test.com",
      "body": "Lorem ipsum dolor sit amet consectetur adipiscing elit laudantium enim quasi",
      "translated_body": null,
      "status": "rejected",
      "keyword_count": 0,
      "post_id": 1
    }
  ]
}
```

#### 5. Traduzir um Comentário
**Descrição**: Inicia a tradução de um comentário para PT-BR.  
**Método**: `POST /api/comments/translate`  
**Exemplos**:
```bash
# Comentário ID 1 (inglês)
curl -X POST http://localhost:3000/api/comments/translate \
-H "Content-Type: application/json" \
-d '{"comment_id": 1, "source_language": "en"}'

# Comentário ID 2 (latim)
curl -X POST http://localhost:3000/api/comments/translate \
-H "Content-Type: application/json" \
-d '{"comment_id": 2, "source_language": "la"}'

# Comentário ID 3 (inglês)
curl -X POST http://localhost:3000/api/comments/translate \
-H "Content-Type: application/json" \
-d '{"comment_id": 3, "source_language": "en"}'

# Comentário ID 4 (inglês)
curl -X POST http://localhost:3000/api/comments/translate \
-H "Content-Type: application/json" \
-d '{"comment_id": 4, "source_language": "en"}'
```

**Resposta** (para ID 1):
```json
{
  "status": "success",
  "data": {
    "job_id": "22efc3b1-6e80-42d1-85ff-6cbb16036bdc",
    "status": "pending",
    "comment_id": 1,
    "source_language": "en"
  },
  "message": "Translation started"
}
```

#### 6. Verificar Progresso de um Job
**Descrição**: Acompanha o progresso de um job de tradução ou reprocessamento.  
**Método**: `GET /api/comments/progress/:job_id`  
**Exemplos**:
```bash
curl -X GET http://localhost:3000/api/comments/progress/22efc3b1-6e80-42d1-85ff-6cbb16036bdc
curl -X GET http://localhost:3000/api/comments/progress/12e5d55f-bf1b-4aa5-80bc-1fe9aa08f0a2
curl -X GET http://localhost:3000/api/comments/progress/be5feea2-7549-4ab0-bd51-091825d13e5c
curl -X GET http://localhost:3000/api/comments/progress/7003d10d-6e33-4ab5-86ad-99db38ca4a27
```

**Resposta**:
```json
{
  "job_id": "22efc3b1-6e80-42d1-85ff-6cbb16036bdc",
  "status": "processing",
  "progress": 75,
  "total": 100,
  "error_message": null,
  "job_type": "translation",
  "metadata": {}
}
```

#### 7. Verificar Status de Tradução
**Descrição**: Retorna o status de tradução e classificação de um comentário.  
**Método**: `GET /api/comments/:id/translation_status`  
**Exemplos**:
```bash
curl -X GET http://localhost:3000/api/comments/1/translation_status
curl -X GET http://localhost:3000/api/comments/2/translation_status
curl -X GET http://localhost:3000/api/comments/3/translation_status
curl -X GET http://localhost:3000/api/comments/4/translation_status
```

**Resposta** (para ID 1):
```json
{
  "comment_id": 1,
  "status": "approved",
  "keyword_count": 3,
  "has_translation": true,
  "original_text": "This product is excellent and fantastic! I love it and think it's perfect.",
  "translated_text": "este produto é excelente e fantástico! eu amo isso and acho que é perfeito.",
  "classification_details": {
    "approved": true,
    "meets_keyword_threshold": true
  }
}
```

#### 8. Reprocessar Comentários
**Descrição**: Reprocessa todos os comentários, redefinindo estados e reclassificando.  
**Método**: `POST /api/comments/reprocess`  
**Exemplo**:
```bash
curl -X POST http://localhost:3000/api/comments/reprocess
```

**Resposta**:
```json
{
  "status": "success",
  "data": {
    "job_id": "be5feea2-7549-4ab0-bd51-091825d13e5c",
    "status": "pending",
    "message": "Comment reprocessing started"
  },
  "message": "Reprocessing started successfully"
}
```

#### 9. Obter Métricas do Usuário
**Descrição**: Retorna métricas estatísticas de comentários de um usuário.  
**Método**: `GET /api/comments/metrics/:username`  
**Exemplo**:
```bash
curl -X GET http://localhost:3000/api/comments/metrics/testuser
```

**Resposta**:
```json
{
  "user_metrics": {
    "total_comments": 4,
    "approved_comments": 1,
    "rejected_comments": 1,
    "avg_keyword_count": 0.75,
    "median_keyword_count": 0.5,
    "std_dev_keyword_count": 0.43,
    "calculated_at": "2025-07-31T18:45:00Z"
  },
  "group_metrics": {
    "total_users": 1,
    "total_comments": 4,
    "approved_comments": 1,
    "rejected_comments": 1,
    "avg_keyword_count": 0.75,
    "median_keyword_count": 0.5,
    "std_dev_keyword_count": 0.43,
    "calculated_at": "2025-07-31T18:45:00Z"
  },
  "calculated_at": "2025-07-31T18:45:00Z"
}
```

#### 10. Gerenciar Palavras-Chave
**Descrição**: Gerencia palavras-chave usadas na classificação.  
**Métodos**:
- Listar: `GET /api/keywords`
- Criar: `POST /api/keywords`
- Atualizar: `PUT /api/keywords/:id`
- Deletar: `DELETE /api/keywords/:id`

**Exemplos**:
```bash
# Listar
curl -X GET http://localhost:3000/api/keywords

# Criar
curl -X POST http://localhost:3000/api/keywords \
-H "Content-Type: application/json" \
-d '{"keyword": {"word": "easylive"}}'

# Atualizar
curl -X PUT http://localhost:3000/api/keywords/1 \
-H "Content-Type: application/json" \
-d '{"keyword": {"word": "atualizado"}}'

# Deletar
curl -X DELETE http://localhost:3000/api/keywords/1
```

**Resposta** (criação):
```json
{
  "keyword": {
    "id": 1,
    "word": "easylive"
  }
}
```

#### 11. Analisar Comentários de um Usuário
**Descrição**: Importa e analisa comentários de um usuário via JSONPlaceholder.  
**Método**: `POST /api/comments/analyze`  
**Exemplo**:
```bash
curl -X POST http://localhost:3000/api/comments/analyze \
-H "Content-Type: application/json" \
-d '{"username": "Bret"}'
```

**Resposta**:
```json
{
  "job_id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "started",
  "message": "Analysis started for user Bret"
}
```

#### 12. Testar Erros
**Descrição**: Testa respostas de erro para validação.  
**Exemplos**:
```bash
# Comentário inexistente
curl -X POST http://localhost:3000/api/comments/translate \
-H "Content-Type: application/json" \
-d '{"comment_id": 999, "source_language": "en"}'

# Idioma inválido
curl -X POST http://localhost:3000/api/comments/translate \
-H "Content-Type: application/json" \
-d '{"comment_id": 1, "source_language": "es"}'
```

**Resposta** (idioma inválido):
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid source language",
    "details": "Supported languages: en, la, pt",
    "timestamp": "2025-07-31T18:45:00Z"
  }
}
```

---

## ⚙️ Comandos de Desenvolvimento

### Servidor e Filas
```bash
rails server
bundle exec solid_queue:start
```

### Banco de Dados
```bash
rails db:seed
rails db:drop db:create db:migrate db:seed
rails db:migrate:status
```

### Background Jobs
```bash
rails solid_queue:status
rails solid_queue:clear_finished_jobs
rails solid_queue:retry_failed_jobs
```

### Cache
```bash
rails cache:clear
rails solid_cache:stats
rails solid_cache:clear_expired
```

### Análise Manual
```bash
rails runner "CommentAnalysisService.new.analyze_user('Bret')"
rails runner "MetricsRecalculationJob.perform_now"
rails runner "puts Keyword.pluck(:word).join(', ')"
```

---

## 🛠️ Configurações Avançadas

### Configurar LibreTranslate
Para traduções reais:
```bash
docker run -d -p 5000:5000 libretranslate/libretranslate
export LIBRETRANSLATE_URL=http://localhost:5000
```

### Configurar Fila Inline (Testes)
```ruby
# config/environments/development.rb
config.active_job.queue_adapter = :inline
```

### Verificar Banco
```bash
rails c
User.pluck(:id, :username)
Comment.pluck(:id, :body)
```

---

## 📊 Métricas Implementadas

As métricas são calculadas usando a gem `descriptive_statistics`:
```ruby
# app/services/metrics_service.rb
keyword_counts = comments.map(&:keyword_count)
{
  total_comments: comments.count,
  approved_comments: comments.count { |c| c.status == 'approved' },
  rejected_comments: comments.count { |c| c.status == 'rejected' },
  avg_keyword_count: keyword_counts.mean || 0,
  median_keyword_count: keyword_counts.median || 0,
  std_dev_keyword_count: keyword_counts.standard_deviation || 0
}
```

---

## 🔍 Solução de Problemas

- **Jobs não processados**: Verifique se `solid_queue:start` está rodando ou use `queue_adapter: :inline`.
- **Erro 404 em endpoints**: Confirme as rotas em `config/routes.rb`.
- **Tradução falhando**: Certifique-se de que `LIBRETRANSLATE_URL` está configurado ou use mock translation.
- **Logs**: Verifique `log/development.log` para erros detalhados.

---

## 🌟 Contribuições

Contribuições são bem-vindas! Abra issues ou pull requests no [repositório GitHub](https://github.com/LariSevilha/comment-analysis-easylive-test).
 
```