# Exemplo — POC de API privada no Azure (ponta a ponta) 🛠️🐝

Exemplo **ilustrativo** ponta a ponta da skill `poc-swarm`: um pedido de **prova de
conceito** dispara o enxame que **projeta, constrói, valida, revisa e provisiona** a POC
no Azure, e depois **documenta** via `document-swarm` — tudo com **portão ≥ A**.

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
   - **Ambiente / custo:** sandbox; teto de custo baixo; SKUs mínimos.
   - **Preferências:** IaC **Bicep**; rede **privada** (Private Endpoint); auth **Managed
     Identity** (sem chaves).
   - **Teardown ao final:** sim. **Máx. de ciclos:** 5.

2. **Fase 1 — Setup.** Criada a pasta `2026-07-06-POC-01\` com a árvore completa e o
   `brief.md` com **7 tópicos de importância**: T1 Arquitetura & adequação · T2 IaC &
   reprodutibilidade · T3 Segurança & identidade · T4 Rede · T5 Custo & sizing ·
   T6 Observabilidade & operação · T7 Deployability & validação.

3. **Fase 2 — Análise & composição (Analista).** O Analista escreveu:
   - `analysis\architecture-decision.md` (ADR): **Azure Container Apps** (Environment com
     integração de VNet, ingress interno) + **Key Vault** (com **Private Endpoint**) +
     **User-Assigned Managed Identity** com `Key Vault Secrets User` + **Log Analytics** +
     **Container Registry**. Rede **privada** (Private Endpoints, sem IP público); IaC
     **Bicep** (nativo Azure, sem estado externo p/ uma POC); **auth por MI** (zero chaves).
   - `analysis\team-plan.md`: **3 builders** (infra/IaC · rede · identidade & segurança) e
     **4 revisores** (segurança & identidade · rede · custo · qualidade IaC/WAF &
     deployability), mapeados aos 7 tópicos.
   - Cada agente recebeu o **modelo** mais adequado (registrado em
     `reports\agent-models.md`): builders em modelo forte de **código**; revisores em
     modelo crítico de **família diferente**; rubber duck no mais crítico disponível.

4. **Fase 3 — Loop de construção.** Cada ciclo seguiu:
   builders → **validação** (`az bicep build` + `az bicep lint`/PSRule + `checkov` +
   `what-if`) → revisores → **rubber duck** → portão.

   **Nota mínima por tópico (por ciclo):**

   | Tópico | C1 | C2 | | Tópico | C1 | C2 |
   |--------|:--:|:--:|---|--------|:--:|:--:|
   | T1 Arquitetura | A- | **A** | | T5 Custo | B  | **A** |
   | T2 IaC         | B+ | **A** | | T6 Observabilidade | B- | **A** |
   | T3 Segurança   | B  | **A** | | T7 Deployability | C+ | **A** |
   | T4 Rede        | C+ | **A** | |   |    |    |

   **Validação (C2):** `az bicep build` sem erro; `checkov` sem falha de severidade alta;
   `az deployment group what-if` mostrou exatamente os recursos esperados (0 surpresas).

5. **Rubber duck.**
   - *C1:* pegou uma `listKeys`/chave de storage **hardcoded** no Bicep que contradizia a
     decisão "só MI" do ADR → devolvido ao builder de segurança (virou referência ao Key
     Vault via MI).
   - *C1:* flagrou o Key Vault **sem Private Endpoint** (ainda com `publicNetworkAccess`
     habilitado) → correção obrigatória no builder de rede.
   - *C2:* confirmou que o `what-if` batia com o ADR e que nenhum tópico tinha **A inflado**.

6. **Fase 4 — Deploy & smoke test.** No **C2** fechou o portão (7/7 tópicos ≥ A, validação
   limpa, 0 críticos). Então:
   - **Preflight** (`reports\preflight.md`): `az account show` confirmou tenant/subscription
     **batendo** com o `brief`; região e providers OK.
   - **Deploy** em `rg-poc-privateapi-dev` com tags padronizadas
     (`az deployment group create`).
   - **Smoke test:** de uma VM na VNet, `curl` no ingress interno da Container App
     respondeu 200 e a API **leu o segredo do Key Vault via MI** (sem chave). Registrado em
     `reports\deploy.md` e `output\resource-manifest.md`.

7. **Fase 5 — Documentação (via `document-swarm`).** A skill montou `docs\brief-seed.md`
   (guia técnico reproduzível: visão geral, arquitetura, ADR, passo-a-passo de deploy,
   segurança, rede, custo, teardown, referências + diagramas Mermaid) e **invocou a
   `document-swarm`** com **destino explícito `2026-07-06-POC-01\docs`**. A doc final passou
   pelo **portão ≥ A** do document-swarm.

8. **Fase 6 — Entrega + teardown.** Como o usuário pediu teardown, a skill rodou
   `az group delete -n rg-poc-privateapi-dev` e registrou. `final-report.md` escrito com a
   matriz final, recursos, custo estimado e o caminho da doc.

**Resultado:** POC construída, validada, provisionada, comprovada por smoke test e
documentada em **2 ciclos**, com **teardown** executado.

---

## Estrutura final da POC

```text
2026-07-06-POC-01\
├─ brief.md
├─ analysis\
│  ├─ analyst.md · architecture-decision.md · team-plan.md
├─ agents\
│  ├─ coordinator.md · rubber-duck.md
│  ├─ builders\builder-01-infra.md · builder-02-rede.md · builder-03-identidade.md
│  └─ reviewers\reviewer-01-seguranca.md … reviewer-04-iac-waf.md
├─ build\
│  ├─ iac\main.bicep · modules\ · main.parameters.json
│  └─ scripts\deploy.ps1 · teardown.ps1
├─ reports\
│  ├─ agent-models.md · preflight.md
│  ├─ cycle-01..02-{build,validation,review,rubberduck}.md
│  ├─ deploy.md · final-report.md
├─ sources\sources-index.md
├─ docs\               ← documentação gerada pelo document-swarm (portão ≥ A dele)
└─ output\resource-manifest.md
```

---

## Lições que o exemplo ilustra

- **Um Analista decide a forma da POC** (recursos, rede, IaC, auth) e **quantos agentes**
  o enxame precisa — o time não é fixo, é derivado do cenário.
- **Validação é um portão técnico real:** `bicep build`/`what-if`/`checkov` rodam de
  verdade; erro/aviso relevante derruba a nota do tópico e bloqueia o deploy.
- **O rubber duck protege a segurança:** pegou chave hardcoded e Key Vault exposto que
  contradiziam o ADR — antes de qualquer deploy.
- **Deploy só depois do portão ≥ A**, com **preflight** confirmando o contexto certo, **RG
  dedicado + tags** e **smoke test** provando que a coisa realmente funciona.
- **Documentação não é à mão:** a POC Swarm **reutiliza o document-swarm** para entregar a
  doc final com o mesmo rigor de qualidade.
