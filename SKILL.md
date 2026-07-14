---
name: poc-swarm
description: "Use when the user asks to design, build, validate and deploy a Proof of Concept (POC) on Azure, in a specified tenant and subscription. An Analyst agent first writes a spec — numbered requirements with testable acceptance criteria (spec-driven development) — then frames the POC (platform resources, implementation options, public vs private networking, IaC choice — Bicep/Terraform/az CLI —, keys vs managed identity, region and other context-driven options) and decides how many agents and which profiles the swarm needs. The skill then materializes declarative agents, running TWO chained swarms inside a single POC folder: a Build swarm (builders + real validation via bicep build/terraform validate+plan, linters/checkov/PSRule, what-if; technical peer review; rubber duck; gate >= A; automatic deploy; smoke test) and a native Documentation swarm (doc writers + doc reviewers + rubber duck; gate >= A) that produces docs/ from the POC artifacts. Outputs go under an explicit target, POCSWARM_ROOT, or the clone's pocs folder. Do not use for pure documents/decks or trivial requests."
---

# POC Swarm Skill

> 🛠️🐝 **Swarm de POCs no Azure** — orquestra um enxame de agentes declarativos
> (analista + builders + revisores técnicos + coordenador + rubber duck) para
> **especificar (SDD), projetar, construir, validar, revisar e provisionar** uma Prova
> de Conceito no Azure em **ciclos de melhoria iterativa** até que **todos os REQs da
> spec e tópicos avaliados atinjam nota mínima A**, e ao final **gerar a documentação**
> com um **swarm de documentação nativo** (dentro da própria skill).

Esta skill **reutiliza o mesmo motor** de swarm para documentação: agentes `.md`
autocontidos, **modelo explícito por agente**, human-in-the-loop no início,
**≥ 5 fontes oficiais verificadas (HTTP 200)**, régua **D- … A+ com portão ≥ A**,
**rubber duck** transversal e tudo rastreável em `reports/`. O que muda é o domínio:
**engenharia de POC em nuvem Azure**, com **validação técnica real** dos artefatos e
**provisionamento** no tenant/subscription informado.

## Trigger

Use esta skill quando o usuário pedir algo como:

- "monte uma POC de `<solução>` no Azure"
- "crie/implemente uma prova de conceito de `<X>` na subscription `<Y>`"
- "quero um POC de `<serviço/arquitetura>` com IaC no meu tenant"
- "prove o conceito de `<X>` no Azure e documente"
- "swarm de POC para `<cenário>`"

**Não dispare** para pedidos que sejam apenas de **documento ou apresentação** (sem
construir nada no Azure), nem para pedidos triviais. A `poc-swarm` é para **construir algo que
roda no Azure** — com IaC/código, validação e (por padrão) deploy real — e então
documentá-lo.

Use também no **modo evolução** (POC já existente em uma pasta de POC), quando o pedido
for "evolua a POC `<id>`", "adicione `<recurso/camada>` à POC", "endureça a
rede/segurança da POC", "troque o IaC de `<A>` para `<B>`", etc. — veja a **Fase E**.

## Princípios

1. **Agentes declarativos** — cada perfil (analista, builder, revisor, coordenador,
   rubber duck) é um arquivo `.md` autocontido, despachado como subagente (`task`,
   tipo `general-purpose`) usando seu próprio frontmatter de modelo.
2. **Modelo explícito por agente** — ao enumerar os agentes, escolha e registre o
   **melhor modelo para cada um** (com esforço/contexto e justificativa), sem padrão
   único cego. Grave em `reports/agent-models.md`.
3. **Spec primeiro (SDD); o Analista decide a composição do enxame** — antes de
   construir, um **Analista** escreve a **spec** (`analysis/spec.md`: requisitos
   numerados com **critérios de aceitação testáveis** — o "o quê"), depois enquadra a
   POC no ADR (recursos, opções, rede, IaC, auth, região — o "como") e define **quantos
   builders/revisores e quais perfis** são necessários, mapeados aos REQs da spec.
4. **Human-in-the-loop no início** — sempre faça as perguntas de enquadramento
   (incluindo **tenant + subscription + região**) ANTES de gerar qualquer agente.
5. **Evidência obrigatória** — **todo** agente (analista, builders, revisores) consulta
   **≥ 5 fontes online funcionais e verificadas** (Microsoft Learn, Well-Architected,
   documentação oficial de Bicep/Terraform, repositórios oficiais no GitHub, normas).
   Toda URL citada é aberta e verificada (`web_fetch`, HTTP 200) na data de uso.
6. **Verifique o estado real, nunca presuma defaults** — decisões e revisões de Azure
   se sustentam no **estado real** dos recursos/serviços (via `az` / Azure MCP /
   `what-if`), não em suposições. Presumir defaults é falha grave.
7. **Validação técnica real** — os artefatos passam por ferramentas reais
   (`bicep build`/`terraform validate`+`plan`, `tflint`/`checkov`/`PSRule`,
   `az deployment ... what-if`) **antes** do deploy; o recurso provisionado passa por
   **smoke test**.
8. **Qualidade com régua** — revisores dão nota **D- … A+** por **REQ da spec** e por
   tópico de importância, com sugestão acionável; o ciclo repete até **todos** os REQs
   e tópicos ficarem **≥ A** (A- não passa). Os critérios de aceitação da spec são a
   **rubrica objetiva** do portão.
9. **Rubber duck transversal** — audita o trabalho de todos os agentes a cada ciclo,
   caçando erros de lógica, contradições, riscos de segurança e notas mal calibradas.
10. **Segurança de deploy** — mesmo em deploy automático, o **preflight read-only** que
    confirma o contexto (tenant/subscription ativos) é inegociável; **RG dedicado**,
    **tags** e **teardown** sempre. Nunca deploye no lugar errado.
11. **Documentação em dois trilhos** — a doc de **intenção** (spec + ADR) nasce antes
    da construção e a dirige; a doc de **produto** é produzida por um **swarm de
    documentação nativo** (doc writers + doc reviewers + rubber duck; portão ≥ A) em
    dois trilhos: o **estático** (arquitetura, segurança & rede, custo) parte de
    spec/ADR/`build/` e roda **em paralelo ao deploy**; o **dinâmico** (deploy,
    manifest, smoke) exige a realidade provisionada.
12. **Tudo rastreável** — cada ciclo/fase produz relatórios versionados em `reports/`.

## Estrutura de saída

### Local de saída (output root)

A skill **não** tem caminho fixo. Antes de criar qualquer pasta, resolva
**`<OUTPUT_ROOT>`** nesta ordem:

1. **Destino explícito do usuário** — se o pedido indicar onde gravar, use-o.
2. **Variável de ambiente `POCSWARM_ROOT`** — se definida, `<OUTPUT_ROOT> = $env:POCSWARM_ROOT`.
3. **Default = `<clone>\pocs`** — onde `<clone>` é a pasta onde este repositório
   `poc-swarm` foi clonado. Descubra `<clone>` resolvendo o **alvo real do symlink**:
   - Windows (PowerShell): `(Get-Item -Force "$env:USERPROFILE\.copilot\skills\poc-swarm").Target`
   - Linux/macOS: `readlink -f "$HOME/.copilot/skills/poc-swarm"`
   - Então `<OUTPUT_ROOT> = <clone>\pocs`.

Confirme o `<OUTPUT_ROOT>` com o usuário se houver ambiguidade. Cada pedido ganha uma
subpasta **única** `<YYYY-MM-DD>-POC-<XX>` (`XX` sequencial por dia) contendo **os dois
swarms lado a lado** (`build/` e `docs/`):

```text
<OUTPUT_ROOT>\<YYYY-MM-DD>-POC-<XX>\
├─ brief.md                     # pedido + respostas Fase 0 + tenant/sub/região + tópicos de importância
├─ state.json                   # checkpoint: fase/etapa/ciclo/status — permite retomada após interrupção
├─ analysis\
│  ├─ analyst.md                # agente Analista (declarativo)
│  ├─ spec.md                   # SDD: REQs numerados + critérios de aceitação testáveis + rastreabilidade
│  ├─ architecture-decision.md  # ADR: recursos, opções de implementação, rede pub/priv,
│  │                            #      IaC (bicep/terraform/az cli), auth (chaves vs MI), região, trade-offs
│  └─ team-plan.md              # quantos agentes + quais perfis (builders + revisores) e por quê
├─ agents\
│  ├─ coordinator.md
│  ├─ rubber-duck.md
│  ├─ builders\
│  │  ├─ builder-01-<slug>.md   # ex.: infra/IaC, rede, identidade&segurança, app/carga
│  │  └─ builder-02-<slug>.md
│  └─ reviewers\
│     ├─ reviewer-01-<slug>.md  # ex.: segurança/identidade, rede, qualidade IaC, custo, deployability, WAF
│     └─ reviewer-02-<slug>.md
│  └─ docs\
│     ├─ doc-writer-01-<slug>.md  # autores da documentação (ex.: visão geral, deploy, segurança/rede)
│     └─ doc-reviewer-01-<slug>.md # revisores de documentação (clareza, correção técnica, completude)
├─ build\
│  ├─ iac\                      # bicep/terraform/az cli
│  ├─ scripts\                  # deploy.* + teardown.*
│  └─ app\                      # código/app da POC (se houver)
├─ reports\
│  ├─ agent-models.md           # matriz: agente, papel, modelo, esforço/contexto, justificativa
│  ├─ preflight.md              # read-only: Fase 0.5 (fail fast) + re-check Fase 4 — contexto/quota/providers
│  ├─ cycle-0N-build.md         # o que cada builder entregou no ciclo
│  ├─ cycle-0N-validation.md    # resultados de bicep build/terraform validate+plan/lint/checkov/what-if
│  ├─ cycle-0N-review.md        # matriz REQ/tópico × revisor + nota mínima + rastreabilidade REQ→artefato→validação
│  ├─ cycle-0N-rubberduck.md    # achados do rubber duck
│  ├─ deploy.md                 # log do deploy + IDs dos recursos + resultado do smoke test
│  ├─ doc-cycle-0N-review.md    # matriz tópico × doc-reviewer da documentação + nota mínima
│  └─ final-report.md           # resumo do swarm: ciclos, notas finais, recursos, custo, fontes
├─ sources\
│  └─ sources-index.md          # consolidado + cache: URL verificada (HTTP 200 na data) vale p/ todos os agentes
├─ docs\                        # documentação nativa da POC (doc writers + doc reviewers)
└─ output\
   └─ resource-manifest.md      # recursos provisionados (nomes, IDs, endpoints, RG, região)
```

Antes de criar, liste `<OUTPUT_ROOT>` e escolha o próximo `XX` livre para a data de hoje.

## Régua de notas

Da pior para a melhor:

```text
D-  D  D+   C-  C  C+   B-  B  B+   A-  A  A+
```

- **Portão de aprovação:** cada **REQ da spec** e cada tópico avaliado precisa de **A**
  ou **A+**.
- **A- NÃO passa** — exige mais um ciclo de melhoria naquele REQ/tópico.
- **Nota ancorada em evidência:** um REQ só recebe A se seu **critério de aceitação**
  for demonstrável (validação limpa e/ou smoke test) — opinião não substitui evidência.
- Cada nota vem **sempre** com: (a) justificativa curta, (b) sugestão de melhoria
  **acionável** (o que mudar, não só "melhore").

## Seleção de modelo por agente

Ao identificar perfis (Fase 2) ou novos agentes (Fase E), defina o modelo ideal de
cada agente. Use somente modelos disponíveis na ferramenta `task` da sessão atual; se
um preferido não estiver disponível, escolha o equivalente mais próximo e registre a
substituição. Para cada agente registre: `model`, `reasoning_effort` (quando suportado),
`context_tier` (`default`|`long_context`) e `model_rationale`.

| Necessidade do agente | Preferência de modelo |
|---|---|
| **Analista** (arquitetura, trade-offs, decidir IaC/rede/auth, compor o enxame) | modelo forte de raciocínio; esforço alto; `long_context` (lê muita doc/estado) |
| **Builder** de IaC/código (Bicep/Terraform/az CLI, app) | modelo forte em **código**; esforço alto |
| **Revisor** de segurança/identidade, rede, custo, qualidade IaC, WAF | modelo crítico e preciso, preferencialmente de **família diferente** dos builders |
| **Coordenador** (orquestração, portão, síntese) | modelo forte de raciocínio; esforço alto |
| **Rubber duck** transversal | modelo mais crítico disponível, idealmente diferente do coordenador; esforço alto |

Evite usar o mesmo modelo para todos sem justificativa — a diversidade entre builders,
revisores e rubber duck reduz cegueira coletiva. Grave a decisão em
`reports/agent-models.md` antes de despachar agentes:

| Agente | Papel | Modelo | Effort | Contexto | Justificativa |
|---|---|---|---|---|---|
| analyst | Analista | ... | ... | ... | ... |
| builder-01-... | ... | ... | ... | ... | ... |

## Segurança & preflight de Azure (guardrails)

Mesmo com **deploy automático** (modo padrão), estas regras são **inegociáveis**:

- **Preflight read-only em dois momentos** (grava/atualiza `reports/preflight.md`): na
  **Fase 0.5** (fail fast, antes de gastar ciclos de agente) e como **re-check na
  Fase 4**, ANTES de qualquer `apply`/`create`:
  - Confirme o **contexto `az` ativo** (`az account show`) — o **tenant e a subscription
    ativos precisam bater** com o `brief.md`. Se **não baterem**, **PARE e alerte** o
    usuário; nunca deploye no lugar errado. (Não é um "gate de confirmação" — é
    verificação de segurança.)
  - Verifique **região**, **quota** (`az vm list-usage`/quota MCP quando aplicável) e
    **resource providers** registrados para os serviços da POC.
- **RG dedicado por POC**: `rg-poc-<slug>-<env>` (ex.: `rg-poc-privateapi-dev`). Nunca
  provisione recursos soltos em RGs existentes do usuário.
- **Tags padronizadas** em todos os recursos: `purpose=poc`, `poc-id=<poc_id>`,
  `created-by=poc-swarm`, `created-on=<data>`, `owner=<solicitante>`,
  `expiration-date=<data prevista de teardown>`.
- **Guardrail de custo real**: o limite de orçamento respondido na Fase 0 vira um
  **budget alert** no RG da POC (`az consumption budget create`) logo após o deploy —
  a resposta do usuário não fica só no papel; a tag `expiration-date` marca recursos
  órfãos para limpeza.
- **Teardown sempre**: gere `build/scripts/teardown.*` capaz de remover o RG/recursos.
  Se o usuário pediu teardown ao final, execute-o e registre; senão, deixe pronto e
  avise o comando exato.
- **Segredos**: prefira **Managed Identity**; se chaves forem inevitáveis, use **Key
  Vault** e **nunca** grave segredos em arquivos versionados nem no chat.
- **Sem dados sensíveis no repositório**: **nunca** escreva IDs reais de
  **tenant/subscription**, nomes de **cliente** ou de **projeto interno** em arquivos que
  possam ser versionados (README, SKILL.md, exemplos, templates). Use **placeholders**
  (ex.: `<tenant sandbox>`, `<sub sandbox>`, `<slug>`, `<env>`). O contexto real vive
  apenas no `brief.md`, dentro de `pocs/` — que está no `.gitignore` e não é distribuído.

## Fluxo de execução

### Checkpoint & retomada (`state.json`)

O coordenador mantém `state.json` na raiz da POC — ex.:
`{ "fase": "3", "ciclo": 2, "etapa": "revisao", "status": "em-andamento", "atualizado": "<ISO-8601>" }`
— atualizado a **cada transição** de fase/etapa/ciclo (etapas: `builders`, `validacao`,
`revisao`, `rubberduck`, `portao`, `deploy`, `docs-estatico`, `docs-dinamico`,
`entrega`). Se a execução for interrompida (sessão caiu, erro de ferramenta), um novo
pedido sobre a mesma pasta **retoma do checkpoint**: leia `state.json` + os `reports/`
do ciclo corrente e continue da etapa registrada — nunca re-despache builders de um
ciclo já concluído nem re-deploye o que o `resource-manifest.md` mostra como
provisionado.

### Fase 0 — Perguntas de enquadramento (obrigatória)

Use `ask_user` para coletar o essencial. Adapte ao cenário, mas cubra no mínimo:

- **Objetivo da POC** e critério de sucesso (o que precisa provar/demonstrar).
- **Ambiguidades que travariam a spec** (estilo `/clarify` do Spec Kit): resolva agora
  o que impediria escrever critérios de aceitação testáveis na Fase 2a.
- **Tenant** e **subscription** de destino, e **região** do Azure.
- **Ambiente** (sandbox/dev/lab — nunca produção) e **limite de custo/orçamento**.
- **Requisitos e restrições** (compliance, rede corporativa, políticas, SKUs permitidos).
- **Preferências** (ou "deixar o analista decidir") de: **IaC** (Bicep/Terraform/az CLI),
  **rede** (pública/privada, Private Endpoint), **auth** (chaves vs Managed Identity).
- **Escopo incluído/excluído** e dados/serviços a integrar.
- **Teardown ao final?** (destruir os recursos após a demonstração).
- **Nº máximo de ciclos** aceitável (padrão 5).

Se o usuário não responder algo, registre um padrão sensato no `brief.md` e siga —
**exceto** tenant/subscription/região, que são obrigatórios para deploy: se faltarem,
insista ou opere em modo "só gera artefatos" (sem deploy) e avise.

### Fase 0.5 — Preflight antecipado (fail fast, read-only)

**Antes de gastar qualquer ciclo de agente**, valide o contexto (somente leitura):

1. `az account show` — o **tenant e a subscription ativos** batem com o pedido? Se não
   baterem (ou faltar `az login`), **PARE e resolva com o usuário agora** — não na
   Fase 4, depois de ciclos caros de builders/revisores.
2. **Região, quota e resource providers** para os serviços prováveis do pedido — na
   granularidade do que já se sabe (o re-check fino acontece na Fase 4).
3. **Toolchain** presente (`az` + `bicep`/`terraform`/linters conforme a preferência
   de IaC) — sem ela não há portão técnico confiável.

Guarde o resultado e grave-o em `reports/preflight.md` (seção "Preflight antecipado")
assim que a pasta existir (Fase 1). Se o usuário optou por "só gerar artefatos", a
checagem de toolchain continua valendo; a de contexto pode ser adiada.

### Fase 1 — Setup da pasta

1. Compute `poc_id = <YYYY-MM-DD>-POC-<XX>` (próximo `XX` livre do dia).
2. Crie a árvore de pastas descrita acima.
3. Escreva `brief.md` com: pedido, respostas da Fase 0, **tenant/subscription/região**,
   objetivo, restrições, e a **lista de "tópicos de importância"** que o portão A exige
   (derive do cenário; base sugerida abaixo, ajuste ao caso):
   - **Arquitetura & adequação** (a solução prova o conceito? aderente ao WAF?)
   - **IaC & reprodutibilidade** (correção, idempotência, parametrização, teardown)
   - **Segurança & identidade** (Managed Identity, least privilege, segredos/Key Vault)
   - **Rede** (pública/privada conforme requisito, Private Endpoint, NSG, exposição mínima)
   - **Custo & sizing** (SKUs adequados, estimativa, sem desperdício)
   - **Observabilidade & operação** (tags, logs/métricas mínimas, diagnóstico)
   - **Deployability & validação** (validate/lint/what-if limpos, deploy reprodutível)
   - **Documentação** (avaliada no swarm de documentação nativo)
4. Inicialize `state.json` (fase/etapa/status — ver *Checkpoint & retomada*) e grave o
   resultado da Fase 0.5 em `reports/preflight.md`.

### Fase 2 — Spec, análise & composição do enxame (Analista)

1. **Gere o Analista** (`analysis/analyst.md`) pelo **Template de Analista**, escolhendo
   seu modelo e registrando em `reports/agent-models.md`.
2. **Fase 2a — Spec (SDD).** Despache o Analista para produzir `analysis/spec.md` pelo
   **Template de Spec**: requisitos funcionais e não-funcionais **numerados**
   (REQ-Fxx/REQ-NFxx), cada um com **critério de aceitação testável**
   ("dado/quando/então"), edge cases e fora de escopo. A spec é o **"o quê"** — o
   contrato que dirige construção, revisão, smoke test e documentação. Se o usuário já
   tiver uma spec pronta (ex.: GitHub Spec Kit), aceite-a como entrada e normalize-a
   para o template (preservando o conteúdo).
3. **Fase 2b — ADR & team-plan.** O Analista então produz, com evidência (≥5 fontes
   verificadas + estado real do Azure):
   - `analysis/architecture-decision.md` — **ADR** que **responde à spec** (o "como";
     cada decisão referencia os REQs que atende) com: recursos da plataforma a usar,
     **opções de implementação** e a escolhida (com trade-offs), **rede pública vs
     privada**, **IaC** escolhido (Bicep/Terraform/az CLI + porquê), **auth** (chaves
     vs Managed Identity), **região**, SKUs/sizing, custo estimado e riscos.
   - `analysis/team-plan.md` — **quantos builders e revisores** e **quais perfis**, com
     justificativa (ex.: builder de infra/IaC, builder de rede, builder de
     identidade&segurança, builder de app; revisores de segurança, rede, custo,
     qualidade IaC, WAF/deployability). Mapeia cada perfil aos **REQs da spec** e aos
     **tópicos de importância**.
4. **Materialize os agentes** definidos pelo `team-plan.md`: builders
   (`agents/builders/`) pelo **Template de Builder**, revisores (`agents/reviewers/`)
   pelo **Template de Revisor Técnico**, além de `agents/coordinator.md` (**Template de
   Coordenador**) e `agents/rubber-duck.md` (**Template de Rubber Duck**). Escolha o
   melhor modelo de cada um e registre tudo em `reports/agent-models.md`.

### Fase 3 — Loop de construção (você atua como Coordenador)

Você, executando a skill, **é o coordenador**. Para cada ciclo `N` (começando em 1):

1. **Despachar builders.** Para cada builder, lance um subagente `task`
   (`general-purpose`) com `model`/`reasoning_effort`/`context_tier` do frontmatter,
   passando o `.md` do builder + `brief.md` + `spec.md` + o `architecture-decision.md`
   + os REQs sob sua responsabilidade e — a partir do ciclo 2 — as **sugestões dos revisores** e os
   **achados do rubber duck** dos tópicos dele. Cada builder escreve/atualiza os
   artefatos em `build/` (IaC/scripts/app) e registra suas fontes. Independentes rodam
   em paralelo (background).
2. **Validação técnica** (o coordenador roda a toolchain — ver *Comandos de referência*):
   - IaC: `az bicep build` **ou** `terraform validate` + `terraform plan`.
   - Lint/segurança: `az bicep lint`/`PSRule`, `tflint`, `checkov`.
   - Dry-run contra a subscription: `az deployment (group|sub) create --what-if` **ou**
     o `terraform plan` já produzido.
   - Consolide os resultados (erros/avisos, o que passou/falhou) em
     `reports/cycle-0N-validation.md`. **Falha de validação bloqueia o portão.**
3. **Despachar revisores técnicos.** Para cada revisor, lance um subagente `task` com o
   `.md` dele + `spec.md` + os artefatos de `build/` + o `cycle-0N-validation.md`. Cada
   revisor devolve, para **cada REQ sob sua dimensão** e **cada tópico de importância**,
   uma **nota D- a A+** + justificativa + sugestão acionável, conferindo cada REQ contra
   o seu **critério de aceitação**. Consolide `reports/cycle-0N-review.md` (matriz
   REQ/tópico × revisor + **nota mínima**) e atualize a **matriz de rastreabilidade** da
   spec (REQ → artefato → validação → nota). REQ sem artefato ou sem validação que o
   demonstre é **órfão** — bloqueia o portão.
4. **Despachar rubber duck.** Lance o rubber duck sobre o trabalho de coordenador +
   builders + revisores (validação realmente limpa? fontes sustentam as escolhas?
   segurança/rede coerentes com o ADR? notas calibradas?). Salve
   `reports/cycle-0N-rubberduck.md`. Achados críticos viram melhorias obrigatórias.
5. **Avaliar o portão.** Se **todos os REQs da spec e todos os tópicos** estão **≥ A**,
   **nenhum REQ está órfão**, a **validação está limpa** e o rubber duck **não** levantou
   achado crítico → **sucesso**: vá para a Fase 4 e **despache em paralelo o trilho
   estático da documentação** (ver Fase 5). Caso contrário, incremente `N` e volte ao
   passo 1 passando aos builders só os REQs/tópicos abaixo de A (+ achados do rubber
   duck + erros de validação).
6. **Trava de segurança.** Se atingir o **nº máximo de ciclos** sem aprovar tudo, pare,
   registre o estado no `final-report.md` e **escale ao usuário** — não deploye algo
   abaixo de A em silêncio.

### Fase 4 — Deploy & smoke test

> Só execute a Fase 4 quando a Fase 3 fechar o portão. Modo padrão: **deploy automático**.
> Se o usuário optou por "só gerar artefatos", pule o deploy e siga para a Fase 5 com os
> artefatos validados. Em paralelo à Fase 4, o **trilho estático** da documentação
> (Fase 5) já pode rodar — nada nele depende do deploy.

1. **Preflight read-only (re-check)** (obrigatório — ver *Segurança & preflight*):
   mesmo com a Fase 0.5 aprovada, reconfirme tenant/subscription/região ativos e
   quota/providers — o contexto pode ter mudado durante os ciclos. Atualize
   `reports/preflight.md`. Se o contexto não bater, **PARE e alerte**.
2. **Deploy** no **RG dedicado** com **tags** padronizadas:
   - Bicep: `az deployment group create` (ou `sub create`) com os parâmetros da POC.
   - Terraform: `terraform apply` sobre o plano aprovado.
3. **Guardrail de custo**: crie o **budget alert** no RG com o limite da Fase 0
   (`az consumption budget create` — ver *Comandos de referência*) e confirme a tag
   `expiration-date` nos recursos. Se o usuário não deu limite, use um padrão sensato
   e registre-o no `brief.md`.
4. **Smoke test derivado da spec**: cada **critério de aceitação** verificável
   pós-deploy ("dado/quando/então") vira uma verificação **real** contra o recurso
   provisionado (endpoint responde? conexão pública negada quando o REQ exige rede
   privada? auth via MI funciona?) — não presuma. Registre o resultado **por REQ** na
   matriz de rastreabilidade.
5. Grave `reports/deploy.md` (comandos, saída, **IDs dos recursos**, resultado do smoke
   test) e `output/resource-manifest.md` (nomes, IDs, endpoints, RG, região, custo
   estimado). Garanta que `build/scripts/teardown.*` está pronto; se o usuário pediu
   teardown ao final, execute-o agora e registre.

### Fase 5 — Documentação (swarm de documentação nativo, em dois trilhos)

A doc de **intenção** (spec + ADR) já existe desde a Fase 2 e dirige a construção. A
Fase 5 produz a doc de **produto** por um **swarm de documentação nativo** — os mesmos
princípios do swarm de construção (agentes declarativos, modelo por agente, ≥ 5
fontes verificadas, régua D-…A+ com **portão ≥ A**, rubber duck), aplicados à redação.
Veja a seção **Swarm de documentação (detalhe)**. Em resumo:

1. **Materialize os agentes de documentação** em `agents/docs/`: **doc writers**
   (Template de Doc Writer) e **doc reviewers** (Template de Doc Reviewer), escolhendo o
   modelo de cada um e registrando em `reports/agent-models.md`. O nº e os perfis saem do
   escopo da POC (ex.: writer de visão geral/arquitetura, writer de deploy/operação,
   writer de segurança & rede).
2. **Trilho estático — despache em paralelo à Fase 4.** Assim que o portão da Fase 3
   fechar, os writers de **visão geral/arquitetura, segurança & rede e custo** já podem
   escrever: partem de `spec.md`, `architecture-decision.md`, `build/` e dos **doc
   stubs** dos builders — nada aqui depende do deploy. Incluem os **diagramas** (Mermaid
   de arquitetura/fluxo).
3. **Trilho dinâmico — após a Fase 4.** Os writers de **deploy/operação/teardown**
   documentam a realidade provisionada: `deploy.md`, `resource-manifest.md` e os
   resultados do smoke test **por REQ**.
4. **Consolidação com portão:** doc reviewers avaliam cada tópico (nota D-…A+)
   conferindo a doc contra **spec × artefatos × realidade provisionada** (sem
   contradição entre trilhos), o rubber duck audita, e o ciclo repete até **todos** os
   tópicos da documentação ficarem **≥ A**. Consolide `reports/doc-cycle-0N-review.md`.
   A doc final vive em `<poc>\docs\`.

### Fase 6 — Entrega

1. Escreva `reports/final-report.md`: nº de ciclos, **matriz final de notas** (todas ≥ A),
   resumo da validação, **recursos provisionados** (do manifest), **custo estimado**,
   status do smoke test/teardown, perfis/modelos usados e o **caminho da documentação**.
2. Responda ao usuário com os caminhos (POC, artefatos, manifest, docs) e um resumo
   curto (ver *Resposta ao usuário*). Não cole artefatos inteiros no chat.

### Fase E — Modo Evolução (POC já existente) ⭐

Use quando o pedido for **evoluir uma POC já entregue** (novo recurso, trocar IaC,
endurecer rede/segurança, adicionar camada). Princípio: **estender sem regredir** e
manter a POC inteira coerente. Princípio de evolução incremental:

1. **Localizar e diagnosticar.** Leia `brief.md`, `spec.md`, `architecture-decision.md`,
   `resource-manifest.md`, o último `cycle-*-review.md`/`final-report.md` e liste os
   agentes existentes.
2. **Diff da spec.** Atualize `spec.md` com os REQs **novos/alterados** (numerando na
   sequência, marcando os alterados e registrando a evolução no frontmatter). O diff
   define o escopo da evolução: **agentes cujos REQs não mudaram não reconstroem** —
   apenas os afetados (o rubber duck confere a coerência global ao final).
3. **Avaliar se faltam agentes.** Se a evolução exige uma especialidade nova (ex.:
   novo builder de "mensageria", novo revisor de "resiliência"), **gere os que faltam**
   (numerando na sequência) e escolha o modelo de cada um; registre em
   `reports/evo-<MM>-plan.md` e atualize `reports/agent-models.md`. Se nenhum novo for
   preciso, diga isso e justifique.
4. **Atualizar o `brief.md`** com uma seção "Evolução `<EVO-XX>`" (data, pedido, novos
   tópicos, novos agentes) — sem apagar o histórico.
5. **Reativar os agentes afetados pelo diff** — builders/revisores cujos REQs mudaram
   (e os novos) revisitam suas partes para incorporar a mudança de forma coerente
   (mesma terminologia, mesmo ADR atualizado), sem regredir o que já estava ≥ A. O
   **rubber duck audita a POC inteira** (não só o diff) para garantir que nada regrediu
   e que spec, ADR e artefatos continuam consistentes.
6. **Revalidar, re-deployar (what-if → apply), re-smoke-test** e **re-documentar**
   (novo ciclo do **swarm de documentação nativo** sobre `docs/`). Portão **≥ A para
   todos os REQs e tópicos, novos e antigos**. Numere os relatórios continuando a
   sequência (`cycle-0N-*`) e/ou prefixe com `evo-<XX>`.

## Regra de fontes (vale para TODO agente)

- Mínimo **5 fontes online distintas e funcionais** por agente (analista, builders,
  revisores). Priorize: **Microsoft Learn / documentação oficial Azure** >
  **Well-Architected Framework / Cloud Adoption Framework** > **docs oficiais de
  Bicep/Terraform (provider azurerm/azapi)** > **repositórios oficiais no GitHub
  (Azure/, azure-samples, hashicorp)** > **normas/padrões** > **blogs de referência**.
- **Verifique cada URL** com `web_fetch` (e/ou `web_search`/`microsoft-learn` MCP para
  localizar): registre o status (ex.: `HTTP 200 em <data>`). **Nunca** cite uma URL sem
  abri-la. Fonte quebrada/inventada é falha grave.
- **Cache de verificação:** o `sources/sources-index.md` é também **cache** — URL já
  verificada (HTTP 200) **na data corrente** por qualquer agente vale para os demais:
  consulte o índice **antes** de re-abrir a URL e referencie a verificação existente.
  Re-verifique apenas se a verificação for de data anterior ou se a fonte sustentar uma
  decisão nova e crítica.
- Cada agente registra suas fontes ao final da sua contribuição e no
  `sources/sources-index.md` (URL, tipo, título, autor/org, data de acesso).
- Revisores **conferem** as fontes: contagem, funcionamento e se sustentam de fato as
  decisões arquiteturais e o código.

## Swarm de documentação (detalhe)

A Fase 5 produz a documentação com um **swarm nativo**, reutilizando o motor da skill.
Padrão de execução:

1. **Composição.** A partir do escopo da POC, decida quantos **doc writers** e **doc
   reviewers** e quais perfis (ex.: writer de visão geral/arquitetura, writer de
   deploy/operação/teardown, writer de segurança & rede; reviewers de clareza/didática,
   de correção técnica e de completude). Materialize-os em `agents/docs/` pelos templates
   abaixo, escolhendo o modelo de cada um e registrando em `reports/agent-models.md`.
2. **Insumos & trilhos.** Os doc writers escrevem em `docs/` a partir de `spec.md`,
   `architecture-decision.md`, `resource-manifest.md`, `deploy.md`, `sources-index.md` e
   dos artefatos de `build/`. **Trilho estático** (visão geral/arquitetura, segurança &
   rede, custo): despachável assim que o portão da Fase 3 fechar, **em paralelo ao
   deploy**. **Trilho dinâmico** (deploy/operação/teardown): após a Fase 4, pois exige a
   realidade provisionada. Estrutura sugerida de `docs/`: `README.md` (visão geral +
   índice), `architecture.md` (com diagramas Mermaid), `deploy.md` (passo-a-passo
   reproduzível), `security-network.md`, `cost.md`, `teardown.md` e `references.md`.
3. **Loop com portão.** Por ciclo: doc writers escrevem/atualizam → doc reviewers dão
   nota **D-…A+** por tópico com sugestão acionável → rubber duck audita → **portão ≥ A**.
   Repita (passando aos writers só os tópicos < A + achados) até todos ficarem ≥ A.
   Consolide `reports/doc-cycle-0N-review.md`.
4. **Resultado.** A doc final vive em `<poc>\docs\...` e passa pelo **portão ≥ A** desta
   skill. Referencie o caminho no `final-report.md`.

> A documentação é parte da mesma entrega: **≥ 5 fontes verificadas por doc writer**,
> correção técnica conferida contra a doc oficial, e nada de afirmar recurso/propriedade/
> API que não exista de verdade.

### Template de Doc Writer (`agents\docs\doc-writer-XX-<slug>.md`)

```markdown
---
name: doc-writer-<XX>-<slug>
kind: doc-writer
role: <Área da doc, ex.: Visão geral & arquitetura / Deploy & operação / Segurança & rede>
model: <modelo forte em redação técnica>
reasoning_effort: <se suportado; ex.: high>
context_tier: <default|long_context>
model_rationale: "<por que este modelo é o melhor para esta parte da documentação>"
poc: <poc_id>
sources_min: 5
---

# Doc Writer: <Área da doc>

## Persona
Você é um(a) **technical writer** sênior em Azure. Escreve documentação **clara, correta e
reproduzível**, fiel aos artefatos e às decisões da POC — não inventa recurso, propriedade
nem passo que não exista.

## Missão
Escrever/atualizar a parte da documentação sob sua responsabilidade (em `docs\`) a partir
dos artefatos reais da POC, no padrão de qualidade dos tópicos de importância do `brief`.

## Como trabalhar
1. Leia `brief.md`, `analysis\spec.md`, `analysis\architecture-decision.md`,
   `output\resource-manifest.md`, `reports\deploy.md`, os artefatos de `build\` e os
   **doc stubs** dos builders. Documente o que **realmente** foi construído/provisionado
   — não o ideal teórico. Se você é do **trilho estático** (arquitetura/segurança/custo),
   não dependa de `deploy.md`/manifest — eles podem ainda não existir.
2. Confira nomes/versões de recurso/propriedade/API contra a doc oficial. Pesquise
   **≥ 5 fontes oficiais verificadas** (Learn, WAF/CAF, docs Bicep/Terraform). **Abra cada
   URL (HTTP 200)** antes de citar.
3. Escreva a sua parte de `docs\` com estrutura clara, exemplos de comando corretos e,
   quando couber, **diagramas Mermaid** (arquitetura/fluxo). Mantenha terminologia
   consistente com o ADR e com os outros writers.
4. Se houver **sugestões de doc reviewers**/achados do **rubber duck** (ciclos ≥ 2), trate
   cada um explicitamente e eleve a qualidade. Liste suas fontes e atualize
   `sources\sources-index.md`.

## Formato das fontes (obrigatório, ≥ 5)
| # | Título | Tipo | URL | Verificado |
|---|--------|------|-----|------------|
| 1 | ...    | oficial/WAF/bicep/terraform/github/norma | https://... | HTTP 200 em <data> |

## Padrão de qualidade
- Fiel aos artefatos reais; passos reproduzíveis de fato; comandos que funcionam.
- Clareza e didática sem perder correção técnica; sustentada por doc oficial.
- Coerente com os outros writers e com o ADR (sem contradição/duplicação).
```

### Template de Doc Reviewer (`agents\docs\doc-reviewer-XX-<slug>.md`)

```markdown
---
name: doc-reviewer-<XX>-<slug>
kind: doc-reviewer
role: <Dimensão, ex.: Clareza & didática / Correção técnica / Completude & reprodutibilidade>
model: <modelo crítico, família diferente dos doc writers>
reasoning_effort: <se suportado; ex.: high>
context_tier: <default|long_context>
model_rationale: "<por que este modelo é o melhor para este doc reviewer>"
poc: <poc_id>
sources_min: 5
scale: "D- D D+ C- C C+ B- B B+ A- A A+"
gate: "A"
---

# Doc Reviewer: <Dimensão>

## Persona
Revisor(a) exigente de documentação técnica focado(a) em **<dimensão>**. Alto sinal, zero
ruído. **Assuma que há problemas** (passo faltando, comando errado, afirmação sem fonte).

## Missão
Avaliar a documentação de `docs\` sob a ótica de **<dimensão>**, conferindo-a contra os
artefatos reais (`spec.md`, `architecture-decision.md`, `resource-manifest.md`,
`deploy.md`, `build\`), dando para **cada tópico de importância** do `brief.md` uma nota
`D- … A+` com justificativa e **sugestão de melhoria acionável**. A doc não pode
contradizer a spec nem a realidade provisionada (nem entre os dois trilhos).

## Como avaliar
1. Leia `brief.md`, os artefatos da POC e a doc em `docs\`.
2. Confira se cada passo/comando **realmente funciona** e bate com o que foi construído;
   se cada afirmação técnica tem fonte oficial verificada (URL HTTP 200).
3. Seja calibrado: **A/A+** = doc pronta para publicar nesta dimensão; **B** = boa com
   lacunas; **C** = retrabalho sério; **D** = inadequada. **A- não aprova** — diga
   exatamente o que falta para virar A.

## Saída (obrigatória)
| Tópico | Nota | Justificativa | Sugestão de melhoria (acionável) |
|--------|------|---------------|----------------------------------|
| <t>    | B+   | ...           | "Adicione o passo de X / corrija o comando Y / cite a fonte de Z ..." |

Encerre com: nota mínima geral, tópicos que **bloqueiam** o portão (< A) e suas próprias
fontes (tabela ≥ 5, verificadas).
```

## Pré-requisitos de ferramenta (toolchain)

O motor de agentes roda sem dependências extras, mas a **validação e o deploy** exigem o
toolchain de Azure/IaC (o instalador checa e lista o que falta):

- **`az` CLI** com login ativo (`az login`) e a **extensão Bicep** (`az bicep install`).
- **Terraform** (se o IaC escolhido for Terraform) + provider `azurerm`/`azapi`.
- **Linters/segurança:** `tflint`, `checkov`, **PSRule for Azure** (`Az.PSRule`/módulo
  `PSRule.Rules.Azure`) — conforme o IaC.
- Acesso à internet para os agentes consultarem documentação oficial.

Checagem rápida (Windows): `Get-Command az,terraform,tflint,checkov`. Instale o que
faltar via `scripts\install.ps1 -WithTools` (ou manualmente — ver README). Se uma
ferramenta de validação faltar e não puder ser instalada, **avise o usuário** — sem
validação não há portão técnico confiável.

## Comandos de referência (validação & deploy)

Rode a partir da pasta da POC. Adapte ao IaC escolhido.

```powershell
# ── Preflight (read-only) ─────────────────────────────────────────────
az account show --output json          # tenant/subscription ATIVOS (devem bater com o brief)
az provider show -n Microsoft.<RP> --query registrationState

# ── Validação — Bicep ─────────────────────────────────────────────────
az bicep build --file build\iac\main.bicep
az deployment group what-if -g rg-poc-<slug>-<env> --template-file build\iac\main.bicep --parameters @build\iac\main.parameters.json
# lint/segurança:
Invoke-PSRule -InputPath build\iac -Module PSRule.Rules.Azure    # PSRule for Azure
checkov -d build\iac

# ── Validação — Terraform ─────────────────────────────────────────────
terraform -chdir=build\iac init
terraform -chdir=build\iac validate
terraform -chdir=build\iac plan -out tfplan
tflint --chdir build\iac
checkov -d build\iac

# ── Deploy (Fase 4, após portão ≥ A) ──────────────────────────────────
az deployment group create -g rg-poc-<slug>-<env> --template-file build\iac\main.bicep --parameters @build\iac\main.parameters.json
# ou:  terraform -chdir=build\iac apply tfplan

# ── Guardrail de custo (após o deploy; limite da Fase 0) ─────────────
az consumption budget create --budget-name budget-poc-<slug> --amount <limite> --category cost --time-grain monthly --start-date <YYYY-MM-01> --end-date <YYYY-MM-DD> --resource-group rg-poc-<slug>-<env>
# (sintaxe varia por versão da CLI — confira `az consumption budget create --help`)

# ── Teardown ──────────────────────────────────────────────────────────
az group delete -n rg-poc-<slug>-<env> --yes --no-wait
# ou:  terraform -chdir=build\iac destroy
```

---

## Template de Spec (`analysis\spec.md`)

> **Documento** (não agente), produzido pelo **Analista** na **Fase 2a** — formato
> inspirado no [GitHub Spec Kit](https://github.com/github/spec-kit), sem dependência
> dele. É o **contrato** que dirige construção, revisão, smoke test e documentação. Se
> o usuário já tiver uma spec (ex.: gerada com Spec Kit), normalize-a para este formato
> preservando o conteúdo.

```markdown
---
poc: <poc_id>
status: draft | approved | evolved
evolutions: []            # ex.: ["EVO-01: <resumo> (<data>)"]
---

# Spec — <título da POC>

## Contexto e objetivo
<o que a POC precisa provar e por quê (do brief.md); critério de sucesso>

## Requisitos funcionais
| ID | Requisito | Prioridade | Critério de aceitação (testável) |
|----|-----------|------------|----------------------------------|
| REQ-F01 | <o que o sistema deve fazer> | must | Dado <estado>, quando <ação>, então <resultado observável> |
| REQ-F02 | ... | should | ... |

## Requisitos não-funcionais
| ID | Requisito | Critério de aceitação (testável) |
|----|-----------|----------------------------------|
| REQ-NF01 | <ex.: rede privada> | Dado o deploy concluído, quando se acessa o endpoint pela internet pública, então a conexão é negada |
| REQ-NF02 | <ex.: auth sem chaves> | Dado o app provisionado, quando ele acessa o recurso X, então usa Managed Identity (nenhuma chave em config) |

## Edge cases e riscos
- <caso limite ou risco> → <comportamento esperado / mitigação>

## Fora de escopo
- <o que a POC deliberadamente NÃO cobre>

## Rastreabilidade (o coordenador atualiza a cada ciclo)
| REQ | Artefato(s) em build\ | Validação/smoke que o demonstra | Última nota |
|-----|-----------------------|---------------------------------|-------------|
| REQ-F01 | ... | ... | ... |
```

Regras: todo REQ tem **ID estável**, **prioridade** e **critério de aceitação
verificável** (nada de "deve ser seguro" sem dizer como demonstrar). REQ sem linha
completa na rastreabilidade ao fechar um ciclo é **órfão** e **bloqueia o portão**.
Prioridades `must` são inegociáveis; `should`/`could` podem ser negociadas com o
usuário se estourarem custo/ciclos.

## Template de Analista (`analysis\analyst.md`)

```markdown
---
name: analyst
kind: analyst
model: <modelo forte de raciocínio/arquitetura>
reasoning_effort: <se suportado; ex.: high>
context_tier: <default|long_context>
model_rationale: "<por que este modelo é o melhor para enquadrar a POC e compor o enxame>"
poc: <poc_id>
sources_min: 5
---

# Analista da POC

## Persona
Você é um(a) **arquiteto(a) de soluções Azure** sênior. Pensa em requisitos, trade-offs,
segurança e custo antes de qualquer código, e verifica tudo contra o **estado real** do
Azure e a **documentação oficial** — nunca presume defaults.

## Missão
Especificar e enquadrar a POC do `brief.md` e **decidir a composição do enxame**:
produzir a spec (`spec.md` — o "o quê"), o ADR (`architecture-decision.md` — o "como")
e o plano de equipe (`team-plan.md`).

## Como trabalhar
1. Leia `brief.md` (objetivo, tenant/subscription/região, restrições, critérios).
2. Pesquise **≥ 5 fontes oficiais verificadas** (Microsoft Learn, WAF/CAF, docs de
   Bicep/Terraform, repositórios Azure no GitHub). **Abra cada URL (HTTP 200).**
3. Verifique o **estado real** relevante do Azure (SKUs/quota/região/providers) via `az`
   ou Azure MCP quando aplicável — não suponha.
4. Escreva `analysis\spec.md` pelo **Template de Spec**: REQs funcionais e
   não-funcionais numerados, cada um com critério de aceitação **testável**
   ("dado/quando/então"), edge cases e fora de escopo. O "o quê" antes do "como".
5. Escreva `analysis\architecture-decision.md` (ADR), **respondendo à spec** (cada
   decisão referencia os REQs que atende):
   - Recursos da plataforma a usar e por quê.
   - **Opções de implementação** consideradas + a escolhida (trade-offs).
   - **Rede**: pública vs privada, Private Endpoint, NSG (conforme requisito).
   - **IaC**: Bicep vs Terraform vs az CLI — escolha + justificativa.
   - **Auth**: chaves vs **Managed Identity** (prefira MI; Key Vault se preciso).
   - Região, SKUs/sizing, **custo estimado**, riscos e mitigação.
6. Escreva `analysis\team-plan.md`:
   - **Quantos builders e quais perfis** (ex.: infra/IaC, rede, identidade&segurança, app).
   - **Quantos revisores e quais dimensões** (ex.: segurança, rede, custo, qualidade IaC,
     WAF/deployability), mapeados aos **REQs da spec** e aos **tópicos de importância**
     do `brief`.
   - O melhor **modelo** sugerido para cada agente (o coordenador confirma/registra).
7. Liste suas fontes (tabela ≥ 5, verificadas) e atualize `sources\sources-index.md`.

## Padrão de qualidade
- Decisões sustentadas por fonte oficial + estado real; trade-offs explícitos.
- Todo REQ da spec tem **critério de aceitação verificável** — nada de "deve ser
  seguro" sem dizer como demonstrar.
- Segurança e custo tratados desde o início; nada de "depois a gente vê".
- O `team-plan` cobre todos os REQs da spec e tópicos de importância sem inchar o enxame.
```

## Template de Builder (`agents\builders\builder-XX-<slug>.md`)

```markdown
---
name: builder-<XX>-<slug>
kind: builder
role: <Perfil, ex.: Engenheiro de IaC / Rede / Identidade & Segurança / App>
model: <modelo forte em código>
reasoning_effort: <se suportado; ex.: high>
context_tier: <default|long_context>
model_rationale: "<por que este modelo é o melhor para este builder>"
poc: <poc_id>
sources_min: 5
---

# Builder: <Perfil>

## Persona
Você é um(a) engenheiro(a) **<perfil>** sênior em Azure. Escreve IaC/código **correto,
seguro e reproduzível**, aderente ao Well-Architected, e testa contra a documentação
oficial — não inventa recurso, propriedade nem API.

## Missão
Construir/atualizar os artefatos sob sua responsabilidade (em `build\`) conforme a
`spec.md` (os REQs sob seu perfil) e o `architecture-decision.md`, no padrão de
qualidade dos tópicos de importância do `brief`.

## Como trabalhar
1. Leia `brief.md`, `spec.md` (seus REQs e **critérios de aceitação**),
   `architecture-decision.md` e o estado atual de `build\`.
2. Pesquise **≥ 5 fontes oficiais verificadas** (Learn, docs Bicep/Terraform, GitHub
   oficial). **Abra cada URL (HTTP 200)** antes de citar. Confira nomes/versões de
   recurso/propriedade/API contra a doc real.
3. Escreva IaC/código específico, parametrizado e **idempotente**:
   - Prefira **Managed Identity**; segredos só via **Key Vault**; **nada** de segredo
     hardcoded ou versionado.
   - Respeite a decisão de **rede** (pública/privada) do ADR.
   - Inclua **tags** padronizadas e, quando você for o builder de infra, o
     **`teardown`** correspondente em `build\scripts\`.
4. Se houver **sugestões de revisores**/erros de **validação**/achados do **rubber duck**
   (ciclos ≥ 2), trate cada um explicitamente e eleve a qualidade.
5. Deixe os artefatos **prontos para validar** (`bicep build`/`terraform validate` devem
   passar) e cada REQ seu **demonstrável** pelo critério de aceitação. Mantenha um **doc
   stub** curto da sua parte (o que construiu, decisões locais, como verificar) — insumo
   do trilho estático da documentação. Liste suas fontes e atualize
   `sources\sources-index.md`.

## Formato das fontes (obrigatório, ≥ 5)
| # | Título | Tipo | URL | Verificado |
|---|--------|------|-----|------------|
| 1 | ...    | oficial/WAF/bicep/terraform/github/norma | https://... | HTTP 200 em <data> |

## Padrão de qualidade
- Correção factual da API/recurso acima de tudo; sustentada por doc oficial.
- Seguro por padrão (MI, least privilege, rede mínima); reproduzível (idempotente + teardown).
- Coerente com os outros builders, com a **spec** e com o ADR (sem contradição/duplicação).
```

## Template de Revisor Técnico (`agents\reviewers\reviewer-XX-<slug>.md`)

```markdown
---
name: reviewer-<XX>-<slug>
kind: reviewer
role: <Dimensão, ex.: Segurança & Identidade / Rede / Custo / Qualidade IaC / WAF & Deployability>
model: <modelo crítico, família diferente dos builders>
reasoning_effort: <se suportado; ex.: high>
context_tier: <default|long_context>
model_rationale: "<por que este modelo é o melhor para este revisor>"
poc: <poc_id>
sources_min: 5
scale: "D- D D+ C- C C+ B- B B+ A- A A+"
gate: "A"
---

# Revisor Técnico: <Dimensão>

## Persona
Revisor(a) exigente focado(a) em **<dimensão>**. Alto sinal, zero ruído: só aponta o que
importa, mas não deixa passar nada relevante na sua área. **Assuma que há problemas.**

## Missão
Avaliar os artefatos de `build\` + o `cycle-0N-validation.md` sob a ótica de
**<dimensão>**, dando para **cada REQ da spec sob sua dimensão** e **cada tópico de
importância** do `brief.md` uma nota `D- … A+` com justificativa e **sugestão de
melhoria acionável**. Um REQ só recebe **A** se seu **critério de aceitação** for
demonstrável pelos artefatos/validação.

## Como avaliar
1. Leia `brief.md` (tópicos e critérios), `spec.md` (REQs e critérios de aceitação),
   `architecture-decision.md` e os artefatos.
2. Consulte **≥ 5 fontes oficiais verificadas** (URLs HTTP 200) e confira se as escolhas
   dos builders existem, funcionam e **estão corretas** (API/recurso/propriedade reais).
3. Leve em conta o resultado real da **validação** (validate/lint/checkov/what-if): erro
   ou aviso relevante **derruba** a nota do tópico correspondente.
4. Seja calibrado: **A/A+** = pronto para deployar nesta dimensão; **B** = bom com
   lacunas; **C** = retrabalho sério; **D** = inadequado. **A- não aprova** — diga
   exatamente o que falta para virar A.

## Saída (obrigatória)
| REQ/Tópico | Nota | Justificativa | Sugestão de melhoria (acionável) |
|------------|------|---------------|----------------------------------|
| REQ-NF01   | B+   | ...           | "Use MI em vez de chave / feche o Private Endpoint / corrija a API ..." |

Encerre com: nota mínima geral, REQs/tópicos que **bloqueiam** o portão (< A ou órfãos)
e suas próprias fontes (tabela ≥ 5, verificadas).
```

## Template de Coordenador (`agents\coordinator.md`)

```markdown
---
name: coordinator
kind: coordinator
model: <modelo forte de raciocínio>
reasoning_effort: <se suportado; ex.: high>
context_tier: <default|long_context>
model_rationale: "<por que este modelo é o melhor para coordenação>"
poc: <poc_id>
gate: "A"
max_cycles: <n, padrão 5>
---

# Coordenador da POC

## Missão
Orquestrar analista, builders, revisores e rubber duck para entregar a POC do `brief.md`
com **todos os REQs da spec e tópicos ≥ A**, **validação limpa** e **deploy + smoke
test** bem-sucedidos, no menor nº de ciclos — e então acionar o **swarm de documentação
nativo**.

## Loop (por ciclo N)
1. **Builders:** despache cada um (subagente `general-purpose`) com os parâmetros de
   modelo do frontmatter + `brief.md` + `spec.md` + `architecture-decision.md` +
   (ciclo ≥ 2) as sugestões dos revisores/rubber duck. Independentes em paralelo. Eles
   escrevem em `build\`.
2. **Validação:** rode `bicep build`/`terraform validate`+`plan`, `tflint`/`checkov`/
   `PSRule`, `what-if`. Consolide `reports\cycle-0N-validation.md`. Falha bloqueia o portão.
3. **Revisores:** despache cada um com `spec.md` + os artefatos + a validação. Colete
   notas D-…A+ por REQ/tópico + sugestões. Consolide `reports\cycle-0N-review.md`
   (matriz + nota mínima) e atualize a **rastreabilidade** da spec (REQ → artefato →
   validação → nota). REQ órfão bloqueia o portão.
4. **Rubber duck:** despache sobre o trabalho de todos. Salve
   `reports\cycle-0N-rubberduck.md`. Achados críticos viram melhorias obrigatórias.
5. **Portão:** se todo REQ e tópico ≥ A **e** sem REQ órfão **e** validação limpa **e**
   sem achado crítico → Fase 4 (deploy) + trilho estático da doc **em paralelo**. Senão,
   N+1 com só os REQs/tópicos < A + achados + erros de validação.
6. **Trava:** ao bater `max_cycles`, pare e **escale ao usuário** (não deploye < A).

## Deploy & docs
- **Fase 4:** preflight read-only (tenant/sub batem?), deploy no RG dedicado + tags,
  **smoke test derivado dos critérios de aceitação da spec** (resultado por REQ),
  `deploy.md` + `resource-manifest.md`, teardown pronto.
- **Fase 5 (dois trilhos):** ao fechar o portão, despache o **trilho estático** da doc
  (arquitetura/segurança/custo — parte de spec/ADR/`build\`) **em paralelo à Fase 4**;
  após o deploy, o **trilho dinâmico** (deploy/operação/teardown). Consolide com doc
  reviewers + rubber duck, portão ≥ A.

## Regras
- Nunca dilua a régua nem pule a validação para "fechar" a POC. A barra é A.
- Preflight de contexto em dois momentos (Fase 0.5 fail fast + re-check na Fase 4) é
  inegociável antes de qualquer `apply`/`create`.
- Atualize `state.json` a **cada transição** de fase/etapa/ciclo — é o checkpoint de
  retomada; ao retomar, nunca repita etapa já concluída.
- Garanta ≥ 5 fontes verificadas por agente (o `sources-index.md` é cache: URL já
  verificada na data vale para todos). Mantenha tudo rastreável em `reports\`/`sources\`.
```

## Template de Rubber Duck (`agents\rubber-duck.md`)

```markdown
---
name: rubber-duck
kind: rubber-duck
model: <modelo mais crítico disponível>
reasoning_effort: <se suportado; ex.: high>
context_tier: <default|long_context>
model_rationale: "<por que este modelo é o melhor para auditoria transversal>"
poc: <poc_id>
---

# Rubber Duck (Revisor Transversal)

## Missão
Revisar o trabalho de **todos** os agentes do ciclo — analista, coordenador, builders e
revisores — caçando o que cada um sozinho não enxerga: erros de lógica, contradições com
o ADR, riscos de segurança/rede, custo escondido, notas mal calibradas e fontes que não
sustentam as decisões.

## O que checar
- **Spec/consistência (estilo `/analyze`):** o ADR e os artefatos respondem à spec?
  Algum REQ **órfão** (sem artefato/validação que o demonstre)? Os critérios de
  aceitação viraram smoke tests? As notas por REQ estão ancoradas em evidência?
- **Analista/ADR:** a arquitetura prova mesmo o conceito? Rede/auth coerentes com o
  requisito? Custo realista? Alguma decisão sem fonte/estado real?
- **Builders:** recurso/propriedade/API existem de verdade (amostre e verifique na doc)?
  Segredo hardcoded? MI onde deveria? Rede exposta além do necessário? IaC idempotente?
  Teardown presente? Contradição entre builders?
- **Validação:** o `cycle-0N-validation.md` está realmente limpo, ou há aviso relevante
  sendo ignorado? O `what-if` bate com o que se espera provisionar?
- **Revisores:** notas coerentes com a evidência e a validação? Alguém deu A para tópico
  ainda fraco? Sugestões acionáveis? Alguma dimensão sem cobertura?
- **Coordenador:** o portão (≥ A + validação limpa) está sendo aplicado de verdade? O
  preflight de contexto foi feito antes de qualquer deploy?

## Saída
- Lista priorizada de achados (Crítico / Importante / Menor), cada um com: agente-alvo,
  evidência e **correção recomendada**.
- Veredito: o ciclo pode ser aprovado, ou há achado **Crítico** que obriga novo ciclo
  mesmo com todos os tópicos em A?
- Suas próprias fontes ao contestar um fato (≥ 5 quando aplicável, com URL verificado).
```

---

## Checklist antes de entregar

- [ ] Pasta `<OUTPUT_ROOT>\<YYYY-MM-DD>-POC-<XX>\` criada com a árvore completa
      (`analysis`, `agents/builders`, `agents/reviewers`, `agents/docs`, `build`,
      `reports`, `sources`, `docs`, `output`).
- [ ] `brief.md` com perguntas respondidas, **tenant/subscription/região** e tópicos de
      importância listados.
- [ ] `analysis\spec.md` (SDD) com REQs numerados, critérios de aceitação **testáveis**
      e matriz de rastreabilidade completa (nenhum REQ órfão).
- [ ] `analysis\architecture-decision.md` (ADR, respondendo à spec) e
      `analysis\team-plan.md` (mapeado aos REQs) produzidos pelo Analista, com ≥ 5
      fontes verificadas e verificação do estado real do Azure.
- [ ] Builders + revisores (conforme o `team-plan`) + coordenador + rubber duck +
      **doc writers/reviewers**, todos como `.md` declarativos, cada um com modelo
      escolhido e justificativa em `reports\agent-models.md`.
- [ ] Cada ciclo com `build`, `validation`, `review` e `rubberduck` registrados em
      `reports\`.
- [ ] **Todos** os REQs da spec e tópicos com nota final **≥ A** e **validação limpa**
      (bicep build/terraform validate+plan, lint/checkov, what-if) — ou escalado ao
      usuário se bater `max_cycles`.
- [ ] **Preflight read-only** nos dois momentos — **Fase 0.5 (fail fast)** e **re-check
      na Fase 4** — gravado em `reports\preflight.md` **antes** do deploy.
- [ ] Deploy no **RG dedicado** com **tags**, **smoke test derivado da spec (por REQ)**
      OK, `reports\deploy.md` e
      `output\resource-manifest.md` escritos; `build\scripts\teardown.*` pronto (e
      executado se o usuário pediu).
- [ ] **Budget alert** criado no RG com o limite da Fase 0 e tag `expiration-date`
      presente nos recursos.
- [ ] `state.json` atualizado a cada transição e marcado `status: concluida` na entrega.
- [ ] Cada agente cumpriu **≥ 5 fontes online verificadas (HTTP 200)** em
      `sources\sources-index.md`.
- [ ] Documentação gerada pelo **swarm de documentação nativo** em `docs\`, nos **dois
      trilhos** (estático em paralelo ao deploy + dinâmico pós-deploy), com doc writers +
      doc reviewers + rubber duck, **portão ≥ A** e ≥ 5 fontes verificadas por writer.
- [ ] `reports\final-report.md` escrito (matriz de notas + recursos + custo + caminho da doc).

## Resposta ao usuário

Depois de concluir, responda com:

```markdown
POC concluída: `<OUTPUT_ROOT>\<poc_id>\`

Artefatos: `build\` (IaC/scripts/app)   |   Manifesto: `output\resource-manifest.md`
Documentação: `docs\` (swarm de documentação nativo)
Modelos dos agentes: `reports\agent-models.md`
Ciclos: <N>   |   REQs da spec: <m> (todos ≥ A)   |   Tópicos avaliados: <k> (todos ≥ A)
Deploy: <RG> em <região> — smoke test <OK/NA>   |   Teardown: <executado/pronto>
Builders: <perfis>   |   Revisores: <dimensões>   |   Fontes verificadas: <total>
Custo estimado: <valor/observação>
```
