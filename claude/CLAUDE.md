## Subagentes
- Sempre use subagents especificos para cada contexto. No meio da atuação migre entre subagentes quando assuntos mudarem.

## Analise
- Entenda que temos 1M de contexto para usar. Sempre ao começar uma conversa, separe fluxos de análise e lance 1 agente por fluxo, para analisa-los e ter o panorama geral

## Estilo de código
- Funções: 4-20 linhas. Divida se for maior.
- Arquivos: menos de 500 linhas. Divida por responsabilidade.
- Uma coisa por função, uma responsabilidade por módulo (SRP).
- Nomes: específicos e únicos. Evite `data`, `handler`, `Manager`. Prefira nomes que retornem menos de 5 hits no grep do codebase.
- Tipos: explícitos. Nada de `any`, `Dict` ou funções sem tipagem.
- Sem duplicação de código. Extraia lógica compartilhada para função/módulo.
- Early returns no lugar de ifs aninhados. Máximo 2 níveis de indentação.
- Mensagens de exceção devem incluir o valor problemático e o formato esperado.

## Comentários
- Mantenha seus próprios comentários. Não os remova em refactor — eles carregam intenção e contexto histórico.
- Escreva o PORQUÊ, não o O QUÊ. Pule `// incrementa contador` em cima de `i++`.
- Docstrings em funções públicas: intenção + um exemplo de uso.
- Referencie números de issue / SHAs de commit quando uma linha existe por causa de um bug específico ou restrição upstream.

## Testes
- Testes rodam com um único comando: `<específico-do-projeto>`.
- Toda função nova ganha um teste. Bug fixes ganham teste de regressão.
- Mock de I/O externo (API, DB, filesystem) com classes fake nomeadas, não stubs inline.
- Testes devem ser F.I.R.S.T: fast, independent, repeatable, self-validating, timely (rápidos, independentes, repetíveis, auto-validáveis, oportunos).

## Dependências
- Injete dependências via construtor/parâmetro, não via global/import.
- Encapsule libs de terceiros atrás de uma interface fina de propriedade deste projeto.

## Estrutura
- Siga a convenção do framework (Rails, Django, Next.js, etc.).
- Prefira módulos pequenos e focados a god files.
- Caminhos previsíveis: controller/model/view, src/lib/test, etc.

## Formatação
- Use o formatador padrão da linguagem (`cargo fmt`, `gofmt`, `prettier`, `black`, `rubocop -A`). Não discuta estilo além disso.

## Logging
- JSON estruturado quando logar para debugging / observabilidade.
- Texto plano só para output de CLI voltado ao usuário.
- Mantenha um fluxo de logs. Caso loggar uma variável no início, loggue-a até o final. Afim de facilitar debugging.
