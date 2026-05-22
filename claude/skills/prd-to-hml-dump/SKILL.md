---
name: prd-to-hml-dump
description: "Executa dump completo de dados do banco PRD para HML no ambiente PE (Pedágio Eletrônico) da Movvia. Use quando o usuário pedir: 'copiar dados prd pra hml', 'dump prod hml', 'replicar banco pra hml', 'rodar o script prd_to_hml', 'sincronizar dados de produção para homologação', 'resetar hml com dados de prd', ou qualquer variação envolvendo cópia de dados entre ambientes PE. Também use quando o usuário mencionar 'prd_to_hml', 'run-parallel.sh', ou problemas de replica HML, storage RDS HML, ou pods degradados após reset de HML."
---

# Dump PRD → HML (Pedágio Eletrônico)

Skill operacional para executar e manter o processo de cópia de dados de PRD para HML no ambiente PE. O script vive em `~/projects/movvia/docs/scripts/prd_to_hml/` (repo git separado).

## Quando Usar

- Dev pediu pra replicar bugs de produção em HML
- Reset de HML precisa ser feito com dados atualizados
- Troubleshooting de pods PE degradados após reset (replica deletada, Proxy sem target, WAL preso)

## Pré-requisitos

1. **AWS profile `HML_PE`** configurado (`~/.aws/credentials` ou `~/.aws/config`)
2. **kubectl** apontado pro cluster HML:
   ```bash
   AWS_PROFILE=HML_PE aws eks update-kubeconfig --name pedagio-eletronico-hml --region us-east-1
   ```
3. **Python 3.10+** com `psycopg2-binary`:
   ```bash
   pip install psycopg2-binary
   ```
4. **VPN ou IP whitelistado** no Security Group do RDS HML (`sg-0ae5bea74f3b4356d`)

## Credenciais Conhecidas (HML)

Ficam em AWS Secrets Manager `movvia-hml-rds-*`. Em caso de emergência:

- **`postgres`** (master): usado pelo script para escrever sem restrições
- **`pe_core_api`**: usado pelos pods via RDS Proxy (precisa de grant em fresh DB)
- **`migrations`**: Flyway
- **`dev_leitura`**: leitura em PRD (replica)

Sempre puxar senhas frescas com:
```bash
cd ~/projects/movvia/docs/scripts && ./get-database-credentials-pe.sh --env hml
```

## Como Rodar (Happy Path)

```bash
cd ~/projects/movvia/docs/scripts/prd_to_hml

# Limpa estado anterior
rm -f checkpoint-*.json /tmp/prd_to_hml-*.log

# Dispara 4 frentes em paralelo com nohup (sobrevive ao terminal/SSH)
nohup env \
  PRD_PASSWORD='<senha_dev_leitura_prd>' \
  HML_USER=postgres \
  HML_PASSWORD='<senha_postgres_hml>' \
  ./run-parallel.sh > /tmp/prd_to_hml-runner.log 2>&1 &

# Acompanha
tail -f /tmp/prd_to_hml-{credencial,passagens,financeiro,outros}.log
```

O script:
- TRUNCATE CASCADE em todas as tabelas (único statement)
- Copia por frente (CREDENCIAL, PASSAGENS, FINANCEIRO, OUTROS) em 4 processos paralelos
- Keyset pagination via PK (ou UNIQUE INDEX single-column)
- Filtro de data: exclui registros do dia corrente (PRD em escrita ativa)
- Exclui partições filhas (copia via pai)
- ON CONFLICT DO NOTHING nos INSERTs (idempotente em retries)
- `SET session_replication_role = replica` no HML (FKs circulares OK durante insert)

Tabelas excluídas por padrão: `flyway_schema_history`, `auditoria_interna`, `auditoria_tentativa_pagamento`, `idempotency_records`, `passagens_versoes_nfsvia`, `passagens_resultados_nfsvia_old`, `queue_outbox_{success,active,error}`.

## Troubleshooting

### 1. `permission denied for schema pedagio_eletronico`
Fresh HML ou restore from snapshot não tem grants. Como `postgres`:
```sql
GRANT USAGE ON SCHEMA pedagio_eletronico TO pe_core_api;
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA pedagio_eletronico TO pe_core_api;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA pedagio_eletronico TO pe_core_api;
```

### 2. `No space left on device` no primary
**Causa comum**: replica HML com storage cheio, que trava WAL no primary.

Diagnóstico:
```bash
# Ver WAL retido e replication slots
PGPASSWORD='...' psql -h <primary> -U postgres -d pedagio_eletronico -c "
  SELECT slot_name, active, pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS wal_retido
  FROM pg_replication_slots;
  SELECT pg_size_pretty(sum(size)) FROM pg_ls_waldir();"

# Status da replica
AWS_PROFILE=HML_PE aws rds describe-db-instances \
  --db-instance-identifier pedagio-eletronico-hml-replica-1 \
  --query 'DBInstances[0].{Status:DBInstanceStatus,Storage:AllocatedStorage}'
```

Fix: aumentar storage da replica ou deletar replica (recriada depois via Terraform):
```bash
AWS_PROFILE=HML_PE aws rds delete-db-instance \
  --db-instance-identifier pedagio-eletronico-hml-replica-1 \
  --skip-final-snapshot --region us-east-1
```

### 3. Primary `storage-full` + cooling-off de 6h
Depois de aumentar storage, AWS bloqueia novas modificações por 6h. Único caminho rápido: **restore from snapshot** com storage maior.

```bash
# Deletar (vai pra deleting mesmo em storage-full)
AWS_PROFILE=HML_PE aws rds delete-db-instance \
  --db-instance-identifier pedagio-eletronico-hml --skip-final-snapshot --region us-east-1

# Aguardar delete e restaurar do snapshot automático mais recente com storage maior
SNAPSHOT=$(AWS_PROFILE=HML_PE aws rds describe-db-snapshots \
  --db-instance-identifier pedagio-eletronico-hml \
  --query 'reverse(sort_by(DBSnapshots,&SnapshotCreateTime))[0].DBSnapshotIdentifier' --output text)

AWS_PROFILE=HML_PE aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier pedagio-eletronico-hml \
  --db-snapshot-identifier "$SNAPSHOT" \
  --db-instance-class db.t3.medium \
  --allocated-storage 300 \
  --storage-type gp3 \
  --no-multi-az \
  --region us-east-1
```

**Depois do restore, DEVE corrigir:**
- Subnet group (vem pro `default` da VPC errada): `--db-subnet-group-name pedagio-eletronico-hml-db-subnet-group`
- Security Group: `--vpc-security-group-ids sg-0ae5bea74f3b4356d`
- Publicly accessible: `--publicly-accessible`
- Registrar no RDS Proxy: `aws rds register-db-proxy-targets --db-proxy-name pedagio-eletronico-hml-rds-proxy --target-group-name default --db-instance-identifiers pedagio-eletronico-hml`
- Reaplicar GRANTs no `pe_core_api`

### 4. `RDS Proxy sem targets` após restore
```bash
AWS_PROFILE=HML_PE aws rds register-db-proxy-targets \
  --db-proxy-name pedagio-eletronico-hml-rds-proxy \
  --target-group-name default \
  --db-instance-identifiers pedagio-eletronico-hml \
  --region us-east-1
```

### 5. `canceling statement due to conflict with recovery`
Query longa na PRD-replica conflita com WAL replay. Nossa implementação já trata: usa `autocommit=True` no PRD e keyset pagination (queries <100ms). Se acontecer, reduzir `BATCH_SIZE` via env var.

### 6. Pods PE degradados após reset
Serviços comuns que quebram e por quê:

| Serviço | Problema | Fix |
|---|---|---|
| pe-api-core | Aponta pra `hml-replica-1` (deletada) | Editar `pe-configuracoes/hml/pe-api-core.yml`, trocar `hml-replica-1` por `hml-rds-proxy.proxy-` |
| pe-processador-nfsvia | `Could not resolve placeholder 'application.internal-service-key'` | Adicionar no `pe-configuracoes/hml/pe-processador-nfsvia.yml` |
| pe-api-notification | `Nest can't resolve REDIS_CLIENT` ou `NotificationOutboxService` | Fix no código: importar `ConfigModule`/`PrismaModule` no módulo |
| ArgoCD apps Degraded | CronJob com `lastSuccess` antigo | Rodar job manualmente: `kubectl create job -n pedagio-eletronico --from=cronjob/<cj> <nome>-manual-$(date +%s)` |

Após fix em `pe-configuracoes`:
```bash
cd ~/projects/movvia/pedagio-eletronico/pe-configuracoes
git reset --hard origin/main  # pe-configuracoes usa main como default
# edit, commit, push
kubectl rollout restart deployment/<svc> -n pedagio-eletronico
```

### 7. Tabela travando com "sem progresso após 3 tentativas"
Pode ser:
- Tabela sem PK e sem UNIQUE INDEX single-column (caiu em OFFSET lento)
- Tabela com UUID-keyed grande (OK mas lento — aguardar)
- Tabela com dados problemáticos (timestamp column não existe, JSONB com HTML embedded, coluna GENERATED)

Para marcar tabela como done manualmente:
```python
import json
d = json.load(open('checkpoint-<frente>.json'))
d['tables']['<tabela>'] = {'status':'done','rows_copied':<n>,'last_offset':<n>,'last_key':None}
json.dump(d, open('checkpoint-<frente>.json','w'), indent=2)
```

## Arquitetura do Script

```
docs/scripts/prd_to_hml/
├── prd_to_hml.py      # Orquestrador principal (CLI)
├── run-parallel.sh    # Dispara 4 frentes em paralelo
├── config.py          # DSNs, excluded tables, timestamp columns, batch size
├── lib/
│   ├── checkpoint.py  # Persiste progresso (JSON por frente)
│   ├── graph.py       # Topological sort (Kahn's) pra ordem FK
│   ├── db.py          # connect, tables, columns, FK deps, PK, JSONB cols
│   └── copier.py      # TRUNCATE, copy_table (keyset/offset), reset_sequences
└── tests/             # 14 testes unitários (checkpoint + graph)
```

### Frentes (grupos de tabelas)
Definidas em `run-parallel.sh`. Frentes rodam em paralelo porque `session_replication_role=replica` desativa FK checks durante INSERT.

### Env vars relevantes
- `PRD_PASSWORD` — obrigatório
- `HML_PASSWORD` — obrigatório
- `HML_USER` — default `pe_core_api`, use `postgres` se `pe_core_api` sem grants
- `INCLUDE_TABLES=t1,t2,...` — rodar só subset (usado pelo run-parallel)
- `CHECKPOINT_FILE` — arquivo de progresso (default `checkpoint.json`)
- `TRUNCATE_MODE=all|skip|only` — controla truncate (skip retoma, only só trunca e sai)
- `BATCH_SIZE` — default 10000, reduz se SSL drop recorrente

## Verificação Pós-Dump

```bash
# Rows por frente
cd ~/projects/movvia/docs/scripts/prd_to_hml
for f in checkpoint-*.json; do python3 -c "
import json
d=json.load(open('$f'))
done=sum(1 for v in d['tables'].values() if v['status']=='done')
print(f'$f: {done}/{len(d[\"tables\"])}')"
done

# Smoke test — query real no HML
PGPASSWORD='<postgres_hml>' psql -h pedagio-eletronico-hml.cwr8oqac8jbb.us-east-1.rds.amazonaws.com -U postgres -d pedagio_eletronico \
  -c "SELECT 'clientes='||(SELECT count(*) FROM pedagio_eletronico.clientes)||
            ' contas='||(SELECT count(*) FROM pedagio_eletronico.contas)||
            ' passagens='||(SELECT count(*) FROM pedagio_eletronico.passagens)"

# ArgoCD apps Healthy
kubectl get application -n argocd | awk 'NR==1 || $3!="Healthy"'
```

## Riscos e Regras

- **LGPD**: dados reais (CPF, email, telefone). HML precisa ser acesso restrito do time de dev.
- **Cooling-off de 6h** do RDS Storage: decidir storage com folga no primeiro apply — sobressalente barato vs downtime.
- **Nunca commitar senhas** em repos — sempre env vars.
- **Replica deletada?** Recriar via Terraform em `pe-infra/environments/hml` (já tem config `read_replica_count=1`).
- **Spec original**: `~/projects/movvia/docs/superpowers/specs/2026-04-16-prd-to-hml-dump-design.md`

## Comportamento esperado em caso de problema

1. Identificar a causa raiz (não mascarar o sintoma)
2. Preferir fix em config/código a workaround manual
3. Abrir PR no repo correto (pe-configuracoes na `main`, demais na `develop`)
4. Se usar AWS CLI pra destravar, documentar no `pe-infra` em seguida pra Terraform refletir o estado real
