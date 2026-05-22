Validação E2E local do Pedágio Eletrônico via Docker. Sobe a stack completa e testa fluxos de ponta a ponta.

## Contexto

A stack E2E vive em `pedagio-eletronico/pe-api-banking/docker-compose.e2e.yml` e sobe:
- postgres (shared, porta 5432) + flyway migrations
- redis (porta 6379)
- rabbitmq (porta 5672)
- pe-api-core (porta 3000)
- pe-api-banking (porta 3001)
- pe-processador-concessionaria (porta 8080)
- pe-simulador-fiscaltech (porta 3010) + postgres-fiscaltech (porta 5434)

## Steps

### 1. Garantir branches corretas

Cada serviço é um repo independente. Antes de buildar, confirme que cada repo está na branch desejada:

```bash
cd pedagio-eletronico/pe-api-core && git branch --show-current
cd pedagio-eletronico/pe-api-banking && git branch --show-current
cd pedagio-eletronico/pe-processador-concessionaria && git branch --show-current
cd pedagio-eletronico/pe-simulador-fiscaltech && git branch --show-current
```

### 2. Build e subir stack

```bash
cd pedagio-eletronico/pe-api-banking
docker-compose -f docker-compose.e2e.yml build --parallel
docker-compose -f docker-compose.e2e.yml up -d
```

Build demora 5-10min na primeira vez (Java do processador é pesado).

### 3. Aguardar serviços healthy

```bash
until curl -s -o /dev/null http://localhost:3000/health && \
      curl -s -o /dev/null http://localhost:3001/health && \
      curl -s -o /dev/null http://localhost:8080/actuator/health && \
      curl -s -o /dev/null http://localhost:3010/health; do sleep 3; done
echo "ALL SERVICES READY"
```

### 4. Simulador Fiscaltech — troubleshooting

O simulador frequentemente falha no boot por:
- **Prisma types desatualizados**: `docker exec pe-e2e-fiscaltech npx prisma generate` + restart
- **Schema não existe**: `docker exec pe-e2e-fiscaltech npx prisma migrate deploy` + restart
- **Erro P2021 (table not found)**: migrations não rodaram, verificar postgres-fiscaltech healthy primeiro

### 5. Seed de dados de teste

```bash
docker exec -i pe-e2e-postgres psql -U pe_user -d pedagio_eletronico <<'SQL'
-- Cliente + Veículo + Conta com saldo
INSERT INTO pedagio_eletronico.clientes (id, documento, tipo_pessoa, nome, email, ativo, created_at, updated_at)
VALUES (99901, '99988877766', 'FISICA', 'E2E Test', 'e2e@test.com', true, now(), now())
ON CONFLICT (id) DO UPDATE SET ativo = true;

INSERT INTO pedagio_eletronico.veiculos (id, placa, cliente_id, status, created_at, updated_at)
VALUES (99901, 'TST1E23', 99901, 'ATIVO', now(), now())
ON CONFLICT (id) DO UPDATE SET placa = 'TST1E23', status = 'ATIVO';

INSERT INTO pedagio_eletronico.contas (id, cliente_id, tipo_conta, numero_conta, saldo_atual, saldo_bloqueado, status, versao, created_at, updated_at)
VALUES (99901, 99901, 'PREPAGO', 'E2E-001', 100.00, 0.00, 'ATIVA', 1, now(), now())
ON CONFLICT (id) DO UPDATE SET saldo_atual = 100.00, saldo_bloqueado = 0.00, versao = 1;
SQL
```

IMPORTANTE: placa deve ser formato Mercosul válido (AAA0A00). Exemplos: `TST1E23`, `ABC1D23`.

### 6. Injetar débitos no simulador Fiscaltech

```bash
curl -s -X POST http://localhost:3010/admin/placas/{PLACA}/debitos \
  -H "Content-Type: application/json" \
  -H "X-Admin-Key: dev-admin-key-change-me" \
  -d '{"valor": 1550, "transacaoId": "E2E-001", "praca": "Praça E2E", "pracaId": "PRC001"}'
```

Valor em CENTAVOS (1550 = R$15.50). O simulador gera transações disponíveis para polling.

### 7. Disparar polling do processador

```bash
curl -s -X POST http://localhost:8080/internal/polling/concessionarias/trigger \
  -H "X-Internal-Service-Key: dev-internal-key" | jq .
```

Isso faz o processador consultar o simulador, criar passagens e processar o outbox.

### 8. Testar endpoint diretamente (sem polling)

```bash
curl -s -X POST http://localhost:3000/internal/passagens/avaliar-debito-automatico \
  -H "Content-Type: application/json" \
  -H "X-Internal-Service-Key: dev-internal-key" \
  -d '{
    "passagemIdExterno": "E2E-001",
    "placa": "TST1E23",
    "concessionariaId": 1032,
    "valor": 15.50,
    "nomePraca": "Praça E2E",
    "numeroReenvio": 1
  }' | jq .
```

### 9. Validar estado no banco

```bash
docker exec -i pe-e2e-postgres psql -U pe_user -d pedagio_eletronico <<'SQL'
SELECT 'PASSAGEM' as _, passagem_id_externo, status FROM pedagio_eletronico.passagens WHERE placa='TST1E23';
SELECT 'PEDIDO' as _, id, status, metodo_pagamento FROM pedagio_eletronico.pedidos WHERE cliente_id=99901;
SELECT 'PAGAMENTO' as _, id, status, valor::text FROM pedagio_eletronico.pagamentos WHERE pedido_id IN (SELECT id FROM pedagio_eletronico.pedidos WHERE cliente_id=99901);
SELECT 'TRANSACAO' as _, tipo, valor::text, saldo_anterior::text, saldo_posterior::text FROM pedagio_eletronico.transacoes_financeiras WHERE conta_id=99901;
SELECT 'CONTA' as _, saldo_atual::text, versao FROM pedagio_eletronico.contas WHERE id=99901;
SELECT 'SAGA' as _, pedido_id, status, tentativas FROM pedagio_eletronico.saga_pagamento;
SQL
```

### 10. Reset para novo teste

```bash
docker exec pe-e2e-redis redis-cli FLUSHDB
docker exec -i pe-e2e-postgres psql -U pe_user -d pedagio_eletronico <<'SQL'
DELETE FROM pedagio_eletronico.saga_pagamento;
DELETE FROM pedagio_eletronico.integracao_reservas;
DELETE FROM pedagio_eletronico.pedidos_passagens WHERE pedido_id IN (SELECT id FROM pedagio_eletronico.pedidos WHERE cliente_id = 99901);
DELETE FROM pedagio_eletronico.pagamentos WHERE pedido_id IN (SELECT id FROM pedagio_eletronico.pedidos WHERE cliente_id = 99901);
DELETE FROM pedagio_eletronico.transacoes_financeiras WHERE conta_id = 99901;
DELETE FROM pedagio_eletronico.pedidos WHERE cliente_id = 99901;
DELETE FROM pedagio_eletronico.passagens WHERE placa = 'TST1E23';
UPDATE pedagio_eletronico.contas SET saldo_atual = 100.00, saldo_bloqueado = 0.00, versao = 1 WHERE id = 99901;
SQL
curl -s -X POST http://localhost:3010/admin/reset -H "X-Admin-Key: dev-admin-key-change-me"
```

### 11. Parar stack

```bash
cd pedagio-eletronico/pe-api-banking
docker-compose -f docker-compose.e2e.yml down
# Para limpar volumes (reset completo): docker-compose -f docker-compose.e2e.yml down -v
```

## Lições aprendidas

### Env vars críticas que faltavam no docker-compose

| Serviço | Var | Valor | Motivo |
|---------|-----|-------|--------|
| pe-api-core | `PROCESSADOR_API_URL` | `http://pe-processador-concessionaria:8080` | Core chama processador para reservas |
| pe-api-core | `GESTAO_WEBHOOKS_URL` | `http://localhost:9999` | Webhook dispatch (pode ser dummy) |
| pe-processador | `POLLING_ENABLED` | `true` | Habilita polling scheduler + trigger endpoint |
| pe-processador | `APP_INTERNAL_SERVICE-KEY` | `dev-internal-key` | InternalServiceKeyFilter para /internal/* |
| pe-processador | `APP_INTEGRACAO_FISCALTECH_CREDENCIAIS_PE_PORTALID` | `PORTAL_PE` | Credencial Fiscaltech |
| pe-processador | `APP_INTEGRACAO_FISCALTECH_CREDENCIAIS_PE_APIKEY` | `dev-pe-api-key-abcdef` | Deve bater com simulador |
| pe-processador | `APP_INTEGRACAO_FISCALTECH_CREDENCIAIS_PE_SECRET` | (64 chars) | HMAC secret |

### Problemas frequentes

| Problema | Causa | Solução |
|----------|-------|---------|
| `sagaPagamento.findUnique()` invalid invocation | Dockerfile.dev Alpine sem openssl/libc6-compat | Bumpar para node:22-alpine + `apk add openssl libc6-compat` |
| Processador 500 em `/api/v1/reservas` | `ConfigurationNotFoundException: fiscaltechV1` | Adicionar `resilience4j.circuitbreaker.configs.fiscaltechV1` no application.yml |
| Core retorna envelope `{success, data, meta}` | TransformInterceptor global | Feign client deve usar EnvelopeResponse wrapper |
| Saga falha com UUID error | `pagamentoId` passava string não-UUID | Usar `processarSaldo()` (cria Pagamento real) em vez de `debitarSaldo()` |
| Postgres `No space left on device` | Docker volumes acumulados | `docker system prune -f --volumes` |
| `passagemId deve ser inteiro` no banking | Banking espera ID interno, não externo | Resolver passagem.id via Prisma antes de chamar banking |
| Placa rejeitada pelo simulador | Formato inválido (precisa Mercosul: AAA0A00) | Usar placas como TST1E23, ABC1D23 |

### Headers inter-serviço

| De → Para | Header | Valor E2E |
|-----------|--------|-----------|
| Core → Banking | `X-Internal-Service-Key` | `dev-internal-key` |
| Core → Processador | `X-Internal-Service: pe-api-core` | fixo no client |
| Processador → Core | `X-Internal-Service-Key` | `dev-internal-key` |
| Processador → Simulador | `X-Portal-Id`, `X-Api-Key`, `X-Signature`, `X-Timestamp`, `X-Request-Id` | HMAC auth |
| Admin → Simulador | `X-Admin-Key` | `dev-admin-key-change-me` |

### Ordem de rebuild quando muda código

Se mudou só 1 serviço:
```bash
docker-compose -f docker-compose.e2e.yml build pe-api-core  # ou pe-processador-concessionaria
docker-compose -f docker-compose.e2e.yml up -d pe-api-core
```

Se mudou schema Prisma no core:
```bash
docker-compose -f docker-compose.e2e.yml build --no-cache pe-api-core
```

### Validação de fluxo Fiscaltech completo

Resultado esperado após polling com cliente cadastrado e saldo:

```
PASSAGEM: status = PAGA
PEDIDO: status = FINALIZADO, metodo_pagamento = SALDO
PAGAMENTO: status = CONFIRMADO, valor = X.XX
TRANSACAO: tipo = DEBITO_PAGAMENTO, saldo_anterior > saldo_posterior
CONTA: saldo_atual = (original - valor), versao incrementado
SAGA: status = CONFIRMADO, tentativas = 0
```

Se saga não aparece ou fica CONFIRMANDO: verificar logs do core (`docker logs pe-e2e-core | grep saga`).
