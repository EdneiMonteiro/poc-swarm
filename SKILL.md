---
name: poc-swarm
description: "Use when the user asks to design, build, validate and deploy a Proof of Concept (POC) on Azure, in a specified tenant and subscription. An Analyst agent frames the POC (platform resources, implementation options, public vs private networking, IaC choice — Bicep/Terraform/az CLI —, keys vs managed identity, region and other context-driven options) and decides how many agents and which profiles the swarm needs. The skill then materializes declarative agents (like document-swarm), running TWO chained swarms inside a single POC folder: a Build swarm (builders + real validation via bicep build/terraform validate+plan, linters/checkov/PSRule, what-if; technical peer review; rubber duck; gate >= A; automatic deploy; smoke test) and a Documentation swarm that invokes the installed document-swarm skill with a pre-filled brief. Outputs go under an explicit target, POCSWARM_ROOT, or the clone's pocs folder. Do not use for pure documents/decks (use document-swarm) or trivial requests."
---

# POC Swarm Skill

> 🛠️🐝 **Swarm de POCs no Azure** — orquestra um enxame de agentes declarativos
> (analista + builders + revisores técnicos + coordenador + rubber duck) para
> **projetar, construir, validar, revisar e provisionar** uma Prova de Conceito no
> Azure em **ciclos de melhoria iterativa** até que **todos os tópicos avaliados
> atinjam nota mínima A**, e ao final **gerar a documentação** invocando a skill
> `document-swarm`.

Esta skill é irmã da `document-swarm` e **reutiliza o mesmo motor**: agentes `.md`
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

**Não dispare** para pedidos que sejam apenas de **documento ou apresentação** (use a
`document-swarm`), nem para pedidos triviais. A `poc-swarm` é para **construir algo que
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
3. **Analista decide a composição do enxame** — antes de construir, um **Analista**
   enquadra a POC (recursos, opções, rede, IaC, auth, região) e define **quantos
   builders/revisores e quais perfis** são necessários para aquele cenário.
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
8. **Qualidade com régua** — revisores dão nota **D- … A+** por tópico com sugestão
   acionável; o ciclo repete até **todos** os tópicos ficarem **≥ A** (A- não passa).
9. **Rubber duck transversal** — audita o trabalho de todos os agentes a cada ciclo,
   caçando erros de lógica, contradições, riscos de segurança e notas mal calibradas.
10. **Segurança de deploy** — mesmo em deploy automático, o **preflight read-only** que
    confirma o contexto (tenant/subscription ativos) é inegociável; **RG dedicado**,
    **tags** e **teardown** sempre. Nunca deploye no lugar errado.
11. **Documentação ao final** — a entrega termina com documentação de qualidade,
    produzida **invocando a skill `document-swarm`** com um brief pré-preenchido.
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
├─ analysis\
│  ├─ analyst.md                # agente Analista (declarativo)
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
├─ build\
│  ├─ iac\                      # bicep/terraform/az cli
│  ├─ scripts\                  # deploy.* + teardown.*
│  └─ app\                      # código/app da POC (se houver)
├─ reports\
│  ├─ agent-models.md           # matriz: agente, papel, modelo, esforço/contexto, justificativa
│  ├─ preflight.md              # verificação read-only de contexto/sub/tenant/região/quota/providers
│  ├─ cycle-0N-build.md         # o que cada builder entregou no ciclo
│  ├─ cycle-0N-validation.md    # resultados de bicep build/terraform validate+plan/lint/checkov/what-if
│  ├─ cycle-0N-review.md        # matriz tópico × revisor + nota mínima por tópico
│  ├─ cycle-0N-rubberduck.md    # achados do rubber duck
│  ├─ deploy.md                 # log do deploy + IDs dos recursos + resultado do smoke test
│  └─ final-report.md           # resumo do swarm: ciclos, notas finais, recursos, custo, fontes
├─ sources\
│  └─ sources-index.md          # consolidado de todas as fontes verificadas
├─ docs\                        # saída do document-swarm (documentação final da POC)
└─ output\
   └─ resource-manifest.md      # recursos provisionados (nomes, IDs, endpoints, RG, região)
```

Antes de criar, liste `<OUTPUT_ROOT>` e escolha o próximo `XX` livre para a data de hoje.

## Régua de notas

Da pior para a melhor:

```text
D-  D  D+   C-  C  C+   B-  B  B+   A-  A  A+
```

- **Portão de aprovação:** cada tópico avaliado precisa de **A** ou **A+**.
- **A- NÃO passa** — exige mais um ciclo de melhoria naquele tópico.
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

- **Preflight read-only ANTES de qualquer `apply`/`create`** (grava `reports/preflight.md`):
  - Confirme o **contexto `az` ativo** (`az account show`) — o **tenant e a subscription
    ativos precisam bater** com o `brief.md`. Se **não baterem**, **PARE e alerte** o
    usuário; nunca deploye no lugar errado. (Não é um "gate de confirmação" — é
    verificação de segurança.)
  - Verifique **região**, **quota** (`az vm list-usage`/quota MCP quando aplicável) e
    **resource providers** registrados para os serviços da POC.
- **RG dedicado por POC**: `rg-poc-<slug>-<env>` (ex.: `rg-poc-privateapi-dev`). Nunca
  provisione recursos soltos em RGs existentes do usuário.
- **Tags padronizadas** em todos os recursos: `purpose=poc`, `poc-id=<poc_id>`,
  `created-by=poc-swarm`, `created-on=<data>`, `owner=<solicitante>`.
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

### Fase 0 — Perguntas de enquadramento (obrigatória)

Use `ask_user` para coletar o essencial. Adapte ao cenário, mas cubra no mínimo:

- **Objetivo da POC** e critério de sucesso (o que precisa provar/demonstrar).
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
   - **Documentação** (avaliada no swarm de docs, via `document-swarm`)

### Fase 2 — Análise & composição do enxame (Analista)

1. **Gere o Analista** (`analysis/analyst.md`) pelo **Template de Analista**, escolhendo
   seu modelo e registrando em `reports/agent-models.md`.
2. **Despache o Analista** para produzir, com evidência (≥5 fontes verificadas + estado
   real do Azure):
   - `analysis/architecture-decision.md` — **ADR** com: recursos da plataforma a usar,
     **opções de implementação** e a escolhida (com trade-offs), **rede pública vs
     privada**, **IaC** escolhido (Bicep/Terraform/az CLI + porquê), **auth** (chaves
     vs Managed Identity), **região**, SKUs/sizing, custo estimado e riscos.
   - `analysis/team-plan.md` — **quantos builders e revisores** e **quais perfis**, com
     justificativa (ex.: builder de infra/IaC, builder de rede, builder de
     identidade&segurança, builder de app; revisores de segurança, rede, custo,
     qualidade IaC, WAF/deployability). Mapeia cada perfil aos **tópicos de importância**.
3. **Materialize os agentes** definidos pelo `team-plan.md`: builders
   (`agents/builders/`) pelo **Template de Builder**, revisores (`agents/reviewers/`)
   pelo **Template de Revisor Técnico**, além de `agents/coordinator.md` (**Template de
   Coordenador**) e `agents/rubber-duck.md` (**Template de Rubber Duck**). Escolha o
   melhor modelo de cada um e registre tudo em `reports/agent-models.md`.

### Fase 3 — Loop de construção (você atua como Coordenador)

Você, executando a skill, **é o coordenador**. Para cada ciclo `N` (começando em 1):

1. **Despachar builders.** Para cada builder, lance um subagente `task`
   (`general-purpose`) com `model`/`reasoning_effort`/`context_tier` do frontmatter,
   passando o `.md` do builder + `brief.md` + o `architecture-decision.md` + a parte sob
   sua responsabilidade e — a partir do ciclo 2 — as **sugestões dos revisores** e os
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
   `.md` dele + os artefatos de `build/` + o `cycle-0N-validation.md`. Cada revisor
   devolve, para **cada tópico de importância**, uma **nota D- a A+** + justificativa +
   sugestão acionável. Consolide `reports/cycle-0N-review.md` (matriz tópico × revisor +
   **nota mínima por tópico**).
4. **Despachar rubber duck.** Lance o rubber duck sobre o trabalho de coordenador +
   builders + revisores (validação realmente limpa? fontes sustentam as escolhas?
   segurança/rede coerentes com o ADR? notas calibradas?). Salve
   `reports/cycle-0N-rubberduck.md`. Achados críticos viram melhorias obrigatórias.
5. **Avaliar o portão.** Se **todos** os tópicos estão **≥ A**, a **validação está limpa**
   e o rubber duck **não** levantou achado crítico → **sucesso**, vá para a Fase 4. Caso
   contrário, incremente `N` e volte ao passo 1 passando aos builders só os tópicos
   abaixo de A (+ achados do rubber duck + erros de validação).
6. **Trava de segurança.** Se atingir o **nº máximo de ciclos** sem aprovar tudo, pare,
   registre o estado no `final-report.md` e **escale ao usuário** — não deploye algo
   abaixo de A em silêncio.

### Fase 4 — Deploy & smoke test

> Só execute a Fase 4 quando a Fase 3 fechar o portão. Modo padrão: **deploy automático**.
> Se o usuário optou por "só gerar artefatos", pule o deploy e siga para a Fase 5 com os
> artefatos validados.

1. **Preflight read-only** (obrigatório — ver *Segurança & preflight*): confirme
   tenant/subscription/região ativos; verifique quota/providers. Grave
   `reports/preflight.md`. Se o contexto não bater, **PARE e alerte**.
2. **Deploy** no **RG dedicado** com **tags** padronizadas:
   - Bicep: `az deployment group create` (ou `sub create`) com os parâmetros da POC.
   - Terraform: `terraform apply` sobre o plano aprovado.
3. **Smoke test** do que foi provisionado (endpoint responde? recurso saudável? auth via
   MI funciona? — teste **real**, não presuma). Registre o resultado.
4. Grave `reports/deploy.md` (comandos, saída, **IDs dos recursos**, resultado do smoke
   test) e `output/resource-manifest.md` (nomes, IDs, endpoints, RG, região, custo
   estimado). Garanta que `build/scripts/teardown.*` está pronto; se o usuário pediu
   teardown ao final, execute-o agora e registre.

### Fase 5 — Documentação (invoca `document-swarm`)

A documentação final da POC é produzida **pela skill `document-swarm`**, não à mão. Veja a
seção **Ponte com `document-swarm`**. Em resumo:

1. Verifique que a skill `document-swarm` está **instalada** (`~/.copilot/skills/document-swarm`).
2. Monte um **brief pré-preenchido** a partir de `architecture-decision.md`,
   `resource-manifest.md`, `deploy.md` e das fontes — com objetivo, público, tópicos e
   os diagramas de arquitetura desejados.
3. **Invoque a `document-swarm`** passando **destino explícito = `<poc>\docs\`** (ela
   honra destino explícito como prioridade #1), para que a doc fique dentro da pasta da
   POC. A documentação passa pelo **portão ≥ A** do próprio document-swarm.

### Fase 6 — Entrega

1. Escreva `reports/final-report.md`: nº de ciclos, **matriz final de notas** (todas ≥ A),
   resumo da validação, **recursos provisionados** (do manifest), **custo estimado**,
   status do smoke test/teardown, perfis/modelos usados e o **caminho da documentação**.
2. Responda ao usuário com os caminhos (POC, artefatos, manifest, docs) e um resumo
   curto (ver *Resposta ao usuário*). Não cole artefatos inteiros no chat.

### Fase E — Modo Evolução (POC já existente) ⭐

Use quando o pedido for **evoluir uma POC já entregue** (novo recurso, trocar IaC,
endurecer rede/segurança, adicionar camada). Princípio: **estender sem regredir** e
manter a POC inteira coerente. Segue a lógica da Fase E do `document-swarm`:

1. **Localizar e diagnosticar.** Leia `brief.md`, `architecture-decision.md`,
   `resource-manifest.md`, o último `cycle-*-review.md`/`final-report.md` e liste os
   agentes existentes.
2. **Avaliar se faltam agentes.** Se a evolução exige uma especialidade nova (ex.:
   novo builder de "mensageria", novo revisor de "resiliência"), **gere os que faltam**
   (numerando na sequência) e escolha o modelo de cada um; registre em
   `reports/evo-<MM>-plan.md` e atualize `reports/agent-models.md`. Se nenhum novo for
   preciso, diga isso e justifique.
3. **Atualizar o `brief.md`** com uma seção "Evolução `<EVO-XX>`" (data, pedido, novos
   tópicos, novos agentes) — sem apagar o histórico.
4. **Reativar o enxame inteiro** — builders existentes **E** novos revisitam suas partes
   para incorporar a mudança de forma coerente (mesma terminologia, mesmo ADR
   atualizado), sem regredir o que já estava ≥ A.
5. **Revalidar, re-deployar (what-if → apply), re-smoke-test** e **re-documentar**
   (nova invocação do `document-swarm` sobre `docs/`). Portão **≥ A para todos os
   tópicos, novos e antigos**. Numere os relatórios continuando a sequência
   (`cycle-0N-*`) e/ou prefixe com `evo-<XX>`.

## Regra de fontes (vale para TODO agente)

- Mínimo **5 fontes online distintas e funcionais** por agente (analista, builders,
  revisores). Priorize: **Microsoft Learn / documentação oficial Azure** >
  **Well-Architected Framework / Cloud Adoption Framework** > **docs oficiais de
  Bicep/Terraform (provider azurerm/azapi)** > **repositórios oficiais no GitHub
  (Azure/, azure-samples, hashicorp)** > **normas/padrões** > **blogs de referência**.
- **Verifique cada URL** com `web_fetch` (e/ou `web_search`/`microsoft-learn` MCP para
  localizar): registre o status (ex.: `HTTP 200 em <data>`). **Nunca** cite uma URL sem
  abri-la. Fonte quebrada/inventada é falha grave.
- Cada agente registra suas fontes ao final da sua contribuição e no
  `sources/sources-index.md` (URL, tipo, título, autor/org, data de acesso).
- Revisores **conferem** as fontes: contagem, funcionamento e se sustentam de fato as
  decisões arquiteturais e o código.

## Ponte com `document-swarm` (invocação da doc final)

A Fase 5 delega a documentação à skill **`document-swarm`**. Padrão de invocação:

1. **Checagem de disponibilidade.** Confirme o alvo real do symlink:
   `(Get-Item -Force "$env:USERPROFILE\.copilot\skills\document-swarm").Target`
   (Linux/macOS: `readlink -f "$HOME/.copilot/skills/document-swarm"`). Se a skill **não**
   estiver instalada, avise o usuário e ofereça: (a) instalar o document-swarm, ou (b)
   gerar um `docs/brief.md` para ele rodar manualmente.
2. **Brief pré-preenchido.** Escreva `docs/brief-seed.md` com o que o document-swarm
   pediria na Fase 0, já respondido a partir dos artefatos da POC: objetivo do documento
   (ex.: "guia técnico reproduzível da POC"), público, formato, tópicos de importância
   (visão geral, arquitetura, decisões/ADR, passo-a-passo de deploy, segurança, rede,
   custo, teardown, referências), idioma (PT-BR), e os **diagramas** desejados
   (Mermaid de arquitetura/fluxo).
3. **Destino explícito.** Invoque o document-swarm instruindo o **`<OUTPUT_ROOT>` =
   `<poc>\docs`** (destino explícito tem prioridade #1 na resolução dele), para que a
   documentação fique **dentro da pasta da POC**. Passe também os caminhos dos insumos
   (`architecture-decision.md`, `resource-manifest.md`, `deploy.md`, `sources-index.md`)
   como material de referência para os autores do document-swarm.
4. **Resultado.** A doc final vive em `<poc>\docs\...` e passa pelo portão ≥ A do
   document-swarm. Referencie o caminho no `final-report.md`.

> A `poc-swarm` **não reimplementa** o motor de documentação — ela reutiliza o
> document-swarm. Se um dia o document-swarm não estiver disponível e o usuário aceitar,
> gere ao menos um `docs/README.md` mínimo a partir do ADR + manifest, deixando claro que
> não passou pelo portão de qualidade do document-swarm.

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

# ── Teardown ──────────────────────────────────────────────────────────
az group delete -n rg-poc-<slug>-<env> --yes --no-wait
# ou:  terraform -chdir=build\iac destroy
```

---

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
Enquadrar a POC do `brief.md` e **decidir a composição do enxame**: produzir o ADR
(`architecture-decision.md`) e o plano de equipe (`team-plan.md`).

## Como trabalhar
1. Leia `brief.md` (objetivo, tenant/subscription/região, restrições, critérios).
2. Pesquise **≥ 5 fontes oficiais verificadas** (Microsoft Learn, WAF/CAF, docs de
   Bicep/Terraform, repositórios Azure no GitHub). **Abra cada URL (HTTP 200).**
3. Verifique o **estado real** relevante do Azure (SKUs/quota/região/providers) via `az`
   ou Azure MCP quando aplicável — não suponha.
4. Escreva `analysis\architecture-decision.md` (ADR):
   - Recursos da plataforma a usar e por quê.
   - **Opções de implementação** consideradas + a escolhida (trade-offs).
   - **Rede**: pública vs privada, Private Endpoint, NSG (conforme requisito).
   - **IaC**: Bicep vs Terraform vs az CLI — escolha + justificativa.
   - **Auth**: chaves vs **Managed Identity** (prefira MI; Key Vault se preciso).
   - Região, SKUs/sizing, **custo estimado**, riscos e mitigação.
5. Escreva `analysis\team-plan.md`:
   - **Quantos builders e quais perfis** (ex.: infra/IaC, rede, identidade&segurança, app).
   - **Quantos revisores e quais dimensões** (ex.: segurança, rede, custo, qualidade IaC,
     WAF/deployability), mapeados aos **tópicos de importância** do `brief`.
   - O melhor **modelo** sugerido para cada agente (o coordenador confirma/registra).
6. Liste suas fontes (tabela ≥ 5, verificadas) e atualize `sources\sources-index.md`.

## Padrão de qualidade
- Decisões sustentadas por fonte oficial + estado real; trade-offs explícitos.
- Segurança e custo tratados desde o início; nada de "depois a gente vê".
- O `team-plan` cobre todos os tópicos de importância sem inchar o enxame.
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
Construir/atualizar os artefatos sob sua responsabilidade (em `build\`) conforme o
`architecture-decision.md`, no padrão de qualidade dos tópicos de importância do `brief`.

## Como trabalhar
1. Leia `brief.md`, `architecture-decision.md` e o estado atual de `build\`.
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
   passar). Liste suas fontes e atualize `sources\sources-index.md`.

## Formato das fontes (obrigatório, ≥ 5)
| # | Título | Tipo | URL | Verificado |
|---|--------|------|-----|------------|
| 1 | ...    | oficial/WAF/bicep/terraform/github/norma | https://... | HTTP 200 em <data> |

## Padrão de qualidade
- Correção factual da API/recurso acima de tudo; sustentada por doc oficial.
- Seguro por padrão (MI, least privilege, rede mínima); reproduzível (idempotente + teardown).
- Coerente com os outros builders e com o ADR (sem contradição/duplicação).
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
**<dimensão>**, dando para **cada tópico de importância** do `brief.md` uma nota
`D- … A+` com justificativa e **sugestão de melhoria acionável**.

## Como avaliar
1. Leia `brief.md` (tópicos e critérios), `architecture-decision.md` e os artefatos.
2. Consulte **≥ 5 fontes oficiais verificadas** (URLs HTTP 200) e confira se as escolhas
   dos builders existem, funcionam e **estão corretas** (API/recurso/propriedade reais).
3. Leve em conta o resultado real da **validação** (validate/lint/checkov/what-if): erro
   ou aviso relevante **derruba** a nota do tópico correspondente.
4. Seja calibrado: **A/A+** = pronto para deployar nesta dimensão; **B** = bom com
   lacunas; **C** = retrabalho sério; **D** = inadequado. **A- não aprova** — diga
   exatamente o que falta para virar A.

## Saída (obrigatória)
| Tópico | Nota | Justificativa | Sugestão de melhoria (acionável) |
|--------|------|---------------|----------------------------------|
| <t>    | B+   | ...           | "Use MI em vez de chave / feche o Private Endpoint / corrija a API ..." |

Encerre com: nota mínima geral, tópicos que **bloqueiam** o portão (< A) e suas próprias
fontes (tabela ≥ 5, verificadas).
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
com **todos os tópicos ≥ A**, **validação limpa** e **deploy + smoke test** bem-sucedidos,
no menor nº de ciclos — e então acionar a documentação via `document-swarm`.

## Loop (por ciclo N)
1. **Builders:** despache cada um (subagente `general-purpose`) com os parâmetros de
   modelo do frontmatter + `brief.md` + `architecture-decision.md` + (ciclo ≥ 2) as
   sugestões dos revisores/rubber duck. Independentes em paralelo. Eles escrevem em `build\`.
2. **Validação:** rode `bicep build`/`terraform validate`+`plan`, `tflint`/`checkov`/
   `PSRule`, `what-if`. Consolide `reports\cycle-0N-validation.md`. Falha bloqueia o portão.
3. **Revisores:** despache cada um com os artefatos + a validação. Colete notas D-…A+ por
   tópico + sugestões. Consolide `reports\cycle-0N-review.md` (matriz + nota mínima).
4. **Rubber duck:** despache sobre o trabalho de todos. Salve
   `reports\cycle-0N-rubberduck.md`. Achados críticos viram melhorias obrigatórias.
5. **Portão:** se todo tópico ≥ A **e** validação limpa **e** sem achado crítico →
   Fase 4 (deploy). Senão, N+1 com só os tópicos < A + achados + erros de validação.
6. **Trava:** ao bater `max_cycles`, pare e **escale ao usuário** (não deploye < A).

## Deploy & docs
- **Fase 4:** preflight read-only (tenant/sub batem?), deploy no RG dedicado + tags,
  smoke test, `deploy.md` + `resource-manifest.md`, teardown pronto.
- **Fase 5:** invoque a skill `document-swarm` com destino explícito `<poc>\docs` e o
  brief pré-preenchido.

## Regras
- Nunca dilua a régua nem pule a validação para "fechar" a POC. A barra é A.
- Preflight de contexto é inegociável antes de qualquer `apply`/`create`.
- Garanta ≥ 5 fontes verificadas por agente. Mantenha tudo rastreável em `reports\`/`sources\`.
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
      (`analysis`, `agents/builders`, `agents/reviewers`, `build`, `reports`, `sources`,
      `docs`, `output`).
- [ ] `brief.md` com perguntas respondidas, **tenant/subscription/região** e tópicos de
      importância listados.
- [ ] `analysis\architecture-decision.md` (ADR) e `analysis\team-plan.md` produzidos pelo
      Analista, com ≥ 5 fontes verificadas e verificação do estado real do Azure.
- [ ] Builders + revisores (conforme o `team-plan`) + coordenador + rubber duck, todos
      como `.md` declarativos, cada um com modelo escolhido e justificativa em
      `reports\agent-models.md`.
- [ ] Cada ciclo com `build`, `validation`, `review` e `rubberduck` registrados em
      `reports\`.
- [ ] **Todos** os tópicos com nota final **≥ A** e **validação limpa**
      (bicep build/terraform validate+plan, lint/checkov, what-if) — ou escalado ao
      usuário se bater `max_cycles`.
- [ ] **Preflight read-only** confirmando tenant/subscription ativos gravado em
      `reports\preflight.md` **antes** do deploy.
- [ ] Deploy no **RG dedicado** com **tags**, **smoke test** OK, `reports\deploy.md` e
      `output\resource-manifest.md` escritos; `build\scripts\teardown.*` pronto (e
      executado se o usuário pediu).
- [ ] Cada agente cumpriu **≥ 5 fontes online verificadas (HTTP 200)** em
      `sources\sources-index.md`.
- [ ] Documentação gerada pelo **`document-swarm`** em `docs\` (portão ≥ A dele) — ou
      fallback avisado se o document-swarm não estava instalado.
- [ ] `reports\final-report.md` escrito (matriz de notas + recursos + custo + caminho da doc).

## Resposta ao usuário

Depois de concluir, responda com:

```markdown
POC concluída: `<OUTPUT_ROOT>\<poc_id>\`

Artefatos: `build\` (IaC/scripts/app)   |   Manifesto: `output\resource-manifest.md`
Documentação: `docs\` (via document-swarm)
Modelos dos agentes: `reports\agent-models.md`
Ciclos: <N>   |   Tópicos avaliados: <k> (todos ≥ A)
Deploy: <RG> em <região> — smoke test <OK/NA>   |   Teardown: <executado/pronto>
Builders: <perfis>   |   Revisores: <dimensões>   |   Fontes verificadas: <total>
Custo estimado: <valor/observação>
```
