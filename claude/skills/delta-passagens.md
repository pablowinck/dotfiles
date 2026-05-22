---
name: delta-passagens
description: Executar sincronização delta de passagens CNL → PE. Gera SQL com registros faltantes + fix de origem_liquidacao NULL.
user_invocable: true
---

# Delta Passagens CNL → PE

## Quando usar
Quando precisar sincronizar passagens faltantes entre CNL e PE PRD.

## Passos

1. Ir para o diretório do projeto:
   ```bash
   cd /Users/pablowinter/projects/movvia/cnl-pe-migration
   ```

2. Ativar virtualenv:
   ```bash
   source venv/bin/activate
   ```

3. Verificar .env tem PE_DB_* configurado

4. Gerar os SQLs delta:
   ```bash
   python -m src.delta_passagens -v --output-dir ./output_delta
   ```

5. Revisar os arquivos gerados:
   ```bash
   head -20 output_delta/delta_passagens_insert.sql
   head -20 output_delta/fix_origem_liquidacao.sql
   ```

6. Executar no PE PRD (pedir confirmação ao usuário antes):
   ```bash
   PGPASSWORD='<senha>' psql -h <host> -U <user> -d pedagio_eletronico -f output_delta/delta_passagens_insert.sql
   PGPASSWORD='<senha>' psql -h <host> -U <user> -d pedagio_eletronico -f output_delta/fix_origem_liquidacao.sql
   ```

7. Validar:
   ```bash
   PGPASSWORD='<senha>' psql -h <host> -U <user> -d pedagio_eletronico -c "
   SET search_path TO pedagio_eletronico;
   SELECT status, COUNT(*) FROM passagens WHERE concessionaria_id = 1032 GROUP BY status ORDER BY total DESC;
   "
   ```
