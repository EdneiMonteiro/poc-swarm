# Exemplo — POC de API privada no Azure (ponta a ponta) 🛠️🐝

Exemplo **ilustrativo** ponta a ponta da skill `poc-swarm`: um pedido de **prova de
conceito** dispara o enxame que, **dirigido por uma spec (SDD)**, **projeta, constrói,
valida, revisa e provisiona** a POC no Azure, e depois **documenta** com um **swarm de
documentação nativo** — tudo com **portão ≥ A**.

> ⚠️ **Ilustrativo.** Os números (notas, nº de fontes, ciclos, recursos) servem para
> mostrar o fluxo — não são a transcrição de uma execução específica.

> POC de referência: `2026-07-06-POC-01`. A saída fica em
> `<clone>\pocs\<YYYY-MM-DD>-POC-<XX>\` e **não vai para o Git** (está no `.gitignore`).

---

## Pedido — Criar a POC

**Prompt do usuário:**

> _"monte uma POC de uma API privada em Azure Container Apps, com segredos em Key Vault
> acessados por Managed Identity, exposta só na rede virtual (sem IP público), IaC em
> Bicep, na minha subscription de sandbox."_

### O que a skill fez

1. **Fase 0 — Perguntas de enquadramento** (via `ask_user`). Respostas no `brief.md`:
   - **Objetivo:** provar que a API roda em Container Apps **sem exposição pública**,
     puxando um segredo do Key Vault **via Managed Identity**.
   - **Tenant / subscription / região:** `<tenant sandbox>` / `<sub sandbox>` / `brazilsouth`.
   - **Ambiente / custo:** sandbox; **teto de custo** baixo; SKUs mínimos.
   - **Preferências:** IaC **Bicep**; rede **privada** (Private Endpoint); auth **Managed
     Identity** (sem chaves).
   - **Teardown ao final:** sim. **Máx. de ciclos:** 5.

2. **Fase 0.5 — Preflight antecipado (fail fast).** Antes de gastar qualquer ciclo de
   agente, `az account show` confirmou que **tenant/subscription ativos batiam** com o
   `brief`; região, `resource providers` e quota OK; toolchain (`az`/Bicep/`checkov`)
   presente. Gravado em `reports\preflight.md`. (Se não batesse, a skill **pararia aqui**.)

3. **Fase 1 — Setup.** Criada a pasta `2026-07-06-POC-01\` com a árvore completa, o
   `brief.md` (com **7 tópicos de importância**: T1 Arquitetura & adequação · T2 IaC &
   reprodutibilidade · T3 Segurança & identidade · T4 Rede · T5 Custo & sizing ·
   T6 Observabilidade & operação · T7 Deployability & validação) e o `state.json` inicial
   (checkpoint de retomada).

4. **Fase 2 — Spec, análise & composição (Analista).**
   - **Fase 2a — `analysis\spec.md` (SDD):** REQs numerados com **critérios de aceitação
     testáveis**, por exemplo:
     - `REQ-F01` (must): a API responde no ingress interno. *Dado o deploy, quando se faz
       `curl` no ingress interno pela VNet, então retorna HTTP 200.*
     - `REQ-F02` (must): a API lê o segredo do Key Vault. *Quando a API busca o segredo,
       então o obtém via Managed Identity.*
     - `REQ-NF01` (rede privada): *quando se acessa o endpoint pela internet pública,
       então a conexão é negada (sem IP público).*
     - `REQ-NF02` (auth sem chaves): *quando a app acessa o Key Vault, então usa Managed
       Identity — nenhuma chave em config.*
     - `REQ-NF03` (custo): SKUs mínimos dentro do teto informado.
   - **Fase 2b — ADR & team-plan (respondendo à spec):**
     `analysis\architecture-decision.md`: **Azure Container Apps** (Environment com
     integração de VNet, ingress interno) + **Key Vault** (com **Private Endpoint**) +
     **User-Assigned Managed Identity** com `Key Vault Secrets User` + **Log Analytics** +
     **Container Registry**. Rede **privada** (Private Endpoints, sem IP público); IaC
     **Bicep**; **auth por MI** (zero chaves) — cada decisão referenciando os REQs que atende.
     `analysis\team-plan.md`: **3 builders** (infra/IaC · rede · identidade & segurança) e
     **4 revisores** (segurança & identidade · rede · custo · qualidade IaC/WAF &
     deployability), **mapeados aos REQs e aos 7 tópicos**.
   - Cada agente recebeu o **modelo** mais adequado (registrado em
     `reports\agent-models.md`): builders em modelo forte de **código**; revisores em
     modelo crítico de **família diferente**; rubber duck no mais crítico disponível.

5. **Fase 3 — Loop de construção.** Cada ciclo seguiu: builders (artefatos + **doc stubs**)
   → **validação** (`az bicep build` + `az bicep lint`/PSRule + `checkov` + `what-if`) →
   revisores (nota **por REQ** e **por tópico**, com rastreabilidade REQ → artefato →
   validação) → **rubber duck** → portão. O `state.json` foi atualizado a cada transição.

   **Nota mínima por tópico (por ciclo):**

   | Tópico | C1 | C2 | | Tópico | C1 | C2 |
   |--------|:--:|:--:|---|--------|:--:|:--:|
   | T1 Arquitetura | A- | **A** | | T5 Custo | B  | **A** |
   | T2 IaC         | B+ | **A** | | T6 Observabilidade | B- | **A** |
   | T3 Segurança   | B  | **A** | | T7 Deployability | C+ | **A** |
   | T4 Rede        | C+ | **A** | |   |    |    |

   No **C2** todos os **REQs** também ficaram **≥ A** (nenhum órfão) e a **validação** ficou
   limpa: `az bicep build` sem erro; `checkov` sem falha de severidade alta;
   `az deployment group what-if` mostrou exatamente os recursos esperados (0 surpresas).

6. **Rubber duck.**
   - *C1:* pegou uma `listKeys`/chave de storage **hardcoded** no Bicep que contradizia o
     `REQ-NF02` ("só MI") do ADR → devolvido ao builder de segurança (virou referência ao
     Key Vault via MI).
   - *C1:* flagrou o Key Vault **sem Private Endpoint** (ainda com `publicNetworkAccess`
     habilitado), violando `REQ-NF01` → correção obrigatória no builder de rede.
   - *C2:* confirmou que o `what-if` batia com o ADR e que nenhum REQ/tópico tinha **A inflado**.

7. **Fase 4 — Deploy & smoke test.** No **C2** fechou o portão (7/7 tópicos e todos os REQs
   ≥ A, validação limpa, 0 críticos). Então:
   - **Re-check do preflight** (`reports\preflight.md`): `az account show` reconfirmou
     tenant/subscription **batendo** com o `brief`; região e providers OK.
   - **Deploy** em `rg-poc-privateapi-dev` com tags padronizadas (incl. `expiration-date`)
     via `az deployment group create`.
   - **Budget alert:** criado no RG com o **teto de custo** informado na Fase 0.
   - **Smoke test derivado da spec (por REQ):** `REQ-F01` — `curl` no ingress interno de
     uma VM na VNet respondeu **200**; `REQ-F02` — a API **leu o segredo via MI** (sem
     chave); `REQ-NF01` — acesso pela **internet pública foi negado**; `REQ-NF02` — nenhuma
     chave em config. Registrado em `reports\deploy.md` e `output\resource-manifest.md`.

8. **Fase 5 — Documentação (swarm de documentação nativo, em dois trilhos).** A skill
   materializou os **doc writers/reviewers** em `agents\docs\`. O **trilho estático**
   (visão geral/arquitetura, segurança & rede, custo) rodou **em paralelo ao deploy** a
   partir de `spec.md`, `architecture-decision.md`, `build\` e dos doc stubs, com diagramas
   **Mermaid**. O **trilho dinâmico** (deploy/operação/teardown) documentou a realidade
   provisionada (`deploy.md`, `resource-manifest.md`, smoke **por REQ**) após a Fase 4. Doc
   reviewers + rubber duck conferiram **spec × artefatos × realidade** e a doc passou pelo
   **portão ≥ A** (`reports\doc-cycle-01-review.md`).

9. **Fase 6 — Entrega + teardown.** Como o usuário pediu teardown, a skill rodou
   `az group delete -n rg-poc-privateapi-dev` e registrou. `final-report.md` escrito com a
   matriz final (REQs + tópicos), recursos, custo estimado e o caminho da doc; `state.json`
   marcado `status: concluida`.

**Resultado:** POC construída, validada, provisionada, comprovada por smoke test e
documentada em **2 ciclos**, com **teardown** executado.

---

## Estrutura final da POC

```text
2026-07-06-POC-01\
├─ brief.md
├─ state.json          ← checkpoint (fase/etapa/ciclo/status) p/ retomada
├─ analysis\
│  ├─ analyst.md · spec.md (REQs + critérios) · architecture-decision.md · team-plan.md
├─ agents\
│  ├─ coordinator.md · rubber-duck.md
│  ├─ builders\builder-01-infra.md · builder-02-rede.md · builder-03-identidade.md
│  ├─ reviewers\reviewer-01-seguranca.md … reviewer-04-iac-waf.md
│  └─ docs\doc-writer-01-visao.md · doc-writer-02-deploy.md · doc-reviewer-01-tecnica.md
├─ build\
│  ├─ iac\main.bicep · modules\ · main.parameters.json
│  └─ scripts\deploy.ps1 · teardown.ps1
├─ reports\
│  ├─ agent-models.md · preflight.md
│  ├─ cycle-01..02-{build,validation,review,rubberduck}.md
│  ├─ deploy.md · doc-cycle-01-review.md · final-report.md
├─ sources\sources-index.md
├─ docs\               ← documentação gerada pelo swarm de documentação nativo (portão ≥ A)
└─ output\resource-manifest.md
```

---

## Lições que o exemplo ilustra

- **A spec (SDD) é o contrato:** REQs com critérios de aceitação testáveis dirigem
  construção, revisão, **smoke test (por REQ)** e documentação — nada de "deve ser seguro"
  sem dizer como demonstrar; REQ órfão (sem artefato/validação) bloqueia o portão.
- **Um Analista decide a forma da POC** (recursos, rede, IaC, auth) e **quantos agentes**
  o enxame precisa — o time não é fixo, é derivado do cenário e mapeado aos REQs.
- **Validação é um portão técnico real:** `bicep build`/`what-if`/`checkov` rodam de
  verdade; erro/aviso relevante derruba a nota do REQ/tópico e bloqueia o deploy.
- **O rubber duck protege a segurança:** pegou chave hardcoded e Key Vault exposto que
  violavam `REQ-NF01`/`REQ-NF02` — antes de qualquer deploy.
- **Preflight em dois momentos:** fail fast na Fase 0.5 e re-check antes do `apply`; deploy
  só depois do portão ≥ A, em **RG dedicado + tags**, com **budget alert** no teto informado.
- **Retomável:** o `state.json` guarda o checkpoint — uma execução interrompida retoma de
  onde parou, sem repetir etapas.
- **Documentação com o mesmo rigor:** a POC Swarm roda um **swarm de documentação nativo**
  em **dois trilhos** (estático em paralelo ao deploy + dinâmico após) para entregar a doc
  final com portão ≥ A.
