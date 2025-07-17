# Comment Analysis Pipeline
# Comment Analysis Pipeline

Um sistema completo de análise de comentários que importa dados de usuários da JSONPlaceholder API, processa comentários através de uma máquina de estados, traduz conteúdo para português brasileiro, classifica comentários baseado em palavras-chave configuráveis, e calcula métricas estatísticas tanto por usuário quanto por grupo.

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

## 🚀 Setup e Instalação

### Pré-requisitos

- Ruby >= 3.0
- Rails >= 7.0
- PostgreSQL >= 12
- Docker e Docker Compose (opcional)

### Instalação Local

```bash
# 1. Clone o repositório
git clone <repository-url>
cd comment-analysis-pipeline

# 2. Instale as dependências
bundle install

# 3. Configure o banco de dados
cp config/database.yml.example config/database.yml
# Edite config/database.yml com suas credenciais PostgreSQL

# 4. Configure variáveis de ambiente
cp .env.example .env
# Edite .env com suas configurações

# 5. Setup do banco de dados
rails db:create
rails db:migrate
rails db:seed

# 6. Inicie o servidor
rails server

# 7. Em outro terminal, inicie os background jobs
bundle exec solid_queue:start
```

### Instalação com Docker

```bash
# 1. Clone o repositório
git clone <repository-url>
cd comment-analysis-pipeline

# 2. Configure variáveis de ambiente
cp .env.example .env

# 3. Executa o script
bin/docker_setup
```

## 🔧 Configuração

### Variáveis de Ambiente

### APIs Externas

#### JSONPlaceholder API

- **URL**: https://jsonplaceholder.typicode.com
- **Uso**: Importação de usuários, posts e comentários
- **Rate Limit**: Sem limitação conhecida
- **Retry**: 3 tentativas com backoff exponencial

#### LibreTranslate API

- **URL**: https://libretranslate.de (ou instância própria)
- **Uso**: Tradução de comentários para PT-BR
- **Rate Limit**: Configurável por instância
- **Fallback**: Texto original se tradução falhar

## 📊 Fórmulas Estatísticas

### Métricas Calculadas

O sistema calcula as seguintes métricas estatísticas para cada usuário e para o grupo:

#### 1. Média Aritmética

```
μ = (Σ xi) / n
```

Onde:

- μ = média
- xi = contagem de palavras-chave do comentário i
- n = número total de comentários

#### 2. Mediana

```
Mediana = valor central quando dados ordenados
```

- Para n ímpar: elemento na posição (n+1)/2
- Para n par: média dos elementos nas posições n/2 e (n/2)+1

#### 3. Desvio Padrão

```
σ = √[(Σ(xi - μ)²) / n]
```

Onde:

- σ = desvio padrão
- xi = contagem de palavras-chave do comentário i
- μ = média aritmética
- n = número total de comentários

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

## 🔌 API Endpoints

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

### Gerenciamento de Palavras-chave

```http
# Listar palavras-chave
GET /api/keywords

# Criar palavra-chave
POST /api/keywords
{
  "word": "fantástico"
}

# Atualizar palavra-chave
PUT /api/keywords/1
{
  "word": "excelente"
}

# Deletar palavra-chave
DELETE /api/keywords/1
```

## 🧪 Testes

### Executar Testes

```bash
# Todos os testes
rails test

# Testes específicos
rails test test/models/
rails test test/controllers/
rails test test/services/
rails test test/jobs/

# Testes de integração
rails test test/integration/

# Com coverage
COVERAGE=true rails test
```

### Estrutura de Testes

```
test/
├── controllers/     # Testes de API endpoints
├── models/         # Testes de validações e associações
├── services/       # Testes de lógica de negócio
├── jobs/          # Testes de background jobs
├── integration/   # Testes end-to-end
├── fixtures/      # Dados de teste
├── factories/     # FactoryBot factories
└── vcr_cassettes/ # Gravações de APIs externas
```

## 🚀 Comandos Úteis

### Desenvolvimento

```bash
# Iniciar servidor de desenvolvimento
rails server

# Iniciar background jobs
bundle exec solid_queue:start

# Console Rails
rails console

# Executar seeds
rails db:seed

# Reset completo do banco
rails db:drop db:create db:migrate db:seed

# Verificar status das migrations
rails db:migrate:status
```

### Background Jobs

```bash
# Monitorar jobs
rails solid_queue:status

# Limpar jobs antigos
rails solid_queue:clear_finished_jobs

# Reprocessar jobs falhados
rails solid_queue:retry_failed_jobs
```

### Cache

```bash
# Limpar cache
rails cache:clear

# Estatísticas do cache
rails solid_cache:stats

# Limpar entradas expiradas
rails solid_cache:clear_expired
```

### Análise Manual

```bash
# Analisar usuário específico
rails runner "CommentAnalysisService.new.analyze_user('Bret')"

# Recalcular métricas
rails runner "MetricsRecalculationJob.perform_now"

# Verificar palavras-chave
rails runner "puts Keyword.pluck(:word).join(', ')"
```

## 🏗️ Arquitetura Técnica

### Stack Tecnológico

- **Framework**: Ruby on Rails 7.0+
- **Ruby**: 3.0+
- **Database**: PostgreSQL 12+
- **Cache**: Solid Cache (database-backed)
- **Background Jobs**: Solid Queue (database-backed)
- **State Machine**: AASM
- **HTTP Client**: HTTParty
- **Statistics**: Descriptive Statistics gem

### Decisões Arquiteturais

#### Por que Solid Queue/Cache?

1. **Simplicidade**: Sem dependências externas (Redis, Sidekiq)
2. **Consistência**: Dados de jobs e cache no mesmo banco
3. **Transações**: Operações atômicas entre dados e jobs
4. **Monitoramento**: Interface web integrada
5. **Escalabilidade**: Suporte a múltiplos workers

#### Por que PostgreSQL?

1. **JSON Support**: Campos JSON nativos para metadados
2. **Performance**: Índices avançados e otimizações
3. **Solid Queue/Cache**: Requerimento das gems
4. **Transações**: ACID compliance para operações críticas

#### Por que Service Objects?

1. **Separação de Responsabilidades**: Lógica fora dos models
2. **Testabilidade**: Testes isolados de cada serviço
3. **Reutilização**: Serviços usados por controllers e jobs
4. **Manutenibilidade**: Código organizado e legível

## 🔍 Monitoramento e Logs

### Logs Estruturados

```ruby
# Exemplo de log estruturado
Rails.logger.info({
  event: 'comment_processed',
  user_id: user.id,
  comment_id: comment.id,
  status: 'approved',
  keyword_count: 3,
  processing_time: 1.2
}.to_json)
```

### Métricas de Performance

- **Response Time**: Tempo de resposta dos endpoints
- **Job Processing Time**: Tempo de processamento dos jobs
- **Cache Hit Ratio**: Taxa de acerto do cache
- **API Success Rate**: Taxa de sucesso das APIs externas

## 🚨 Troubleshooting

### Problemas Comuns

#### Jobs não processam

```bash
# Verificar se Solid Queue está rodando
ps aux | grep solid_queue

# Verificar logs de jobs
rails logs:jobs

# Reiniciar workers
bundle exec solid_queue:restart
```

#### Cache não funciona

```bash
# Verificar configuração
rails solid_cache:info

# Limpar cache corrompido
rails cache:clear

# Verificar espaço em disco
df -h
```

#### APIs externas falham

```bash
# Testar conectividade
curl -I https://jsonplaceholder.typicode.com/users
curl -I https://libretranslate.de

# Verificar logs de API
rails logs:api_calls
```

## 📝 Contribuição

1. Fork o projeto
2. Crie uma branch para sua feature (`git checkout -b feature/nova-feature`)
3. Commit suas mudanças (`git commit -am 'Add nova feature'`)
4. Push para a branch (`git push origin feature/nova-feature`)
5. Abra um Pull Request

