# Ubiquitous Language

## Experiencia e navegacao

| Term | Definition | Aliases to avoid |
| --- | --- | --- |
| **Hoje** | Area inicial que mostra dados observados do dia antes da interpretacao do TCC. | Dashboard inicial, resumo geral, home analitica |
| **Analises** | Area longitudinal para comparar janelas e encontrar episodios relevantes ao longo de varios dias. | Hoje, detalhe de app, lista tecnica, privacidade |
| **Apps** | Area de inventario e detalhe por aplicativo observado no historico local. | Catalogo, ranking de apps, analise da janela |
| **Configuracoes** | Area de permissoes, privacidade, notificacoes, heuristica e rastreabilidade tecnica. | Ajustes tecnicos soltos, analises |
| **Janela de analise** | Recorte temporal selecionado para leitura longitudinal, com 7 dias como padrao principal. | Periodo de retencao, semana, filtro global |
| **Detalhe diario** | Leitura de um unico dia com resumo, episodios do dia e rastreabilidade daquele recorte. | Analise longitudinal, detalhe da janela |
| **Episodios relevantes** | Lista objetiva de episodios da janela que merecem revisao por duracao, sinais, mecanismo ou classificacao. | Explorar episodios, filtro avancado, busca tecnica |
| **Detalhe do aplicativo** | Leitura concentrada de um app observado, seu contexto TCC/OWL e suas metricas. | Card expandido, resumo da janela |
| **Sinais e mecanismos observados** | Sintese curta dos sinais, tipos de aplicativo e mecanismos do TCC que apareceram na janela. | Classes TCC observadas, dump ontologico |
| **Mudancas no periodo** | Bloco longitudinal que mostra a principal variacao da janela e deixa detalhes em expansao progressiva. | Tendencia da janela, relatorio completo |

## Dados observados

| Term | Definition | Aliases to avoid |
| --- | --- | --- |
| **Uso observado** | Dado local obtido do Android ou de derivados persistidos, sem preencher lacunas com exemplos. | Fixture, estimativa, dado inferido |
| **Tempo de tela** | Duracao ativa observada para um dia, janela ou aplicativo. | Tempo ativo, duracao ativa, screen time |
| **Episodio observado** | Intervalo reconstruido de uso continuo de um aplicativo. | Abertura, sessao bruta, evento |
| **Cobertura observada** | Grau em que o recorte tem dados suficientes, parciais ou indisponiveis. | Confiabilidade geral, qualidade do usuario |
| **Notificacoes observadas** | Contagem de notificacoes unicas observadas por app/dia pelo Notification Listener depois da habilitacao. | Conteudo de notificacoes, notificacoes historicas, atualizacoes da mesma notificacao |
| **Conteudo textual de notificacoes** | Titulo e texto armazenados opcionalmente por app autorizado e por ate sete dias. | Contagem de notificacoes, analise de conteudo |
| **Autorizar apps observados** | Acao em Configuracoes que autoriza conteudo textual para todos os pacotes de apps ja observados localmente. | Permissao Android global, alterar contagem |
| **Desbloqueios** | Metrica diaria do dispositivo, nao atribuida causalmente a aplicativos especificos. | Desbloqueios do app, gatilho do app |
| **Zero observado** | Valor zero quando a coleta estava disponivel e nenhum evento foi observado. | Indisponivel, sem permissao |
| **Dado indisponivel** | Ausencia de leitura por permissao, suporte, cobertura ou catalogacao insuficiente. | Zero, baixo uso |

## Interpretacao cientifica

| Term | Definition | Aliases to avoid |
| --- | --- | --- |
| **Sinais observados** | Sinais comportamentais detectados por heuristicas versionadas em dados observados. | Sintomas, diagnostico, alerta clinico |
| **Intensidade dos sinais observados** | Faixa baixa, media ou alta derivada de `score_sinais` para comunicacao ao usuario. | Score do dia, estado do usuario |
| **`score_sinais`** | Valor tecnico calculado por pesos e limiares versionados para um episodio. | Score global, score de dependencia |
| **`score_total`** | Valor integrado e versionado de classificacao do episodio em escala de 0 a 1, agregando sinais, mecanismos, tecnicas psicologicas e intencoes institucionais curadas. | Diagnostico, risco clinico, score longitudinal |
| **Estado de analise** | Resultado heuristico do episodio: contexto indisponivel, sinais insuficientes, sinais para revisao ou convergencia de sinais. | Diagnostico, risco final |
| **Contexto TCC/OWL aprovado** | Contexto de app com associacoes catalogadas, evidencias e papel contextual definidos. | Contexto disponivel, candidato automatico |
| **Contexto insuficiente** | Situacao em que o app nao tem contexto TCC/OWL aprovado para sustentar inferencia contextual. | Reprovado, app sem risco, zero retencao |
| **Sugestao automatica** | Hipotese de contexto derivada automaticamente, ainda sem aprovacao catalogada. | Contexto aprovado, classificacao final |
| **Forca contextual** | Indicador do quanto associacoes aprovadas do catalogo sustentam leitura de retencao. | Retencao comprovada, forca de vicio |
| **Mecanismo tecnico** | Classe ou recurso do app associado a retencao, como feed algoritimico ou rolagem infinita. | Tecnica psicologica |
| **Tecnica psicologica** | Associacao curada que liga um mecanismo tecnico a uma tecnica psicologica explicita, quando houver evidencia suficiente. | Mecanismo tecnico, intencao institucional, inferencia por uso alto |
| **Intencao institucional** | Associacao curada que liga um app ou mecanismo tecnico a uma finalidade institucional explicita, quando houver evidencia suficiente. | Modelo de negocio presumido, objetivo inferido, inferencia por popularidade |
| **Rastreabilidade cientifica** | Camada progressiva com metrica, valor, unidade, cobertura, versoes, OWL e cautela. | Texto principal, explicacao simplificada |
| **Cautela inferencial** | Aviso que limita a leitura a descricao exploratoria, sem diagnostico ou prova causal. | Disclaimer generico |

## Catalogo e identidade de apps

| Term | Definition | Aliases to avoid |
| --- | --- | --- |
| **App observado** | Aplicativo que apareceu no historico local carregado ou em contagens de notificacao. | App catalogado |
| **App catalogado** | Aplicativo presente no catalogo versionado com metadados e possivel contexto TCC/OWL. | App observado |
| **Nome amigavel** | Nome resolvido pelo Android ou pelo catalogo para aparecer na UI principal. | `packageName` visivel |
| **`packageName`** | Identificador tecnico estavel usado para catalogo, persistencia e diagnostico. | Nome do app para usuario final |
| **Categoria nativa Android** | Categoria operacional fornecida pelo Android quando disponivel. | Categoria TCC/OWL |
| **Tipo de aplicativo** | Termo visivel para agrupar apps pelo catalogo do TCC na UI principal. | Categoria TCC/OWL, perfil do app |
| **Como o smartphone foi usado** | Titulo do card de distribuicao do tempo de tela por tipo ou app na pagina Hoje. | Rosca observacional |
| **Resumo do dia** | Primeiro card da pagina Hoje com metricas macro observadas do smartphone. | Diagnostico do dia, score do usuario |
| **Indicios de retencao hoje** | Sintese macro do dia com faixas Baixos, Moderados e Altos, derivada de sinais, mecanismos, tecnicas psicologicas e intencoes institucionais curadas. | Score do dia, diagnostico, usuario retido |
| **Tipo aprovado** | Estado de UI para app com categoria analitica revisada, evidenciada e catalogada. | Retencao assumida so por uso alto |
| **Tipo sugerido** | Estado de UI para hipotese automatica ou preliminar com uso observado e ao menos um mecanismo plausivel mapeavel ao TCC/OWL. | Tipo aprovado, fila de aprovacao, uso alto sozinho |
| **Tipo nao avaliado** | Estado de UI para app observado que ainda nao recebeu classificacao contextual suficiente. | Contexto OWL insuficiente como rotulo principal |
| **Categoria analitica TCC/OWL** | Termo tecnico de rastreabilidade para a categoria conceitual aprovada pelo TCC/OWL. | Categoria Android, tipo de aplicativo na UI principal |

## Relationships

- **Hoje** apresenta **uso observado** do dia; **Analises** compara **janelas de analise** e destaca **episodios observados** relevantes; **Apps** apresenta **detalhe do aplicativo**; **Configuracoes** apresenta permissoes, privacidade e **conteudo textual de notificacoes**.
- Uma **janela de analise** contem zero ou mais **episodios observados** e um ou mais dias com **cobertura observada**.
- Em **Analises**, as janelas **3 dias**, **7 dias** e **30 dias** sao atalhos
  visiveis; **15 dias** e **Semestre** ficam em acesso secundario.
- **Analises** ordena a leitura como seletor de janela, **Resumo da janela**,
  **Sinais e mecanismos observados**, **Mudancas no periodo**, **Episodios
  relevantes** e dias da janela.
- **Sinais e mecanismos observados** resume apenas conceitos com aplicacao no uso da
  janela; campos nao curados, como **tecnica psicologica** e **intencao
  institucional**, ficam no detalhe.
- **Mudancas no periodo** substitui **Tendencia da janela** na UI principal.
- **Mudancas no periodo** prioriza mudancas em **Indicios de retencao**, depois
  tempo de tela, depois episodios, e mostra ausencia de comparacao quando a
  janela nao tiver dados suficientes.
- **Episodios relevantes** substitui **Explorar episodios da janela** na UI
  principal.
- **Episodios relevantes** mostra App, **Indicios de retencao** e Duracao como
  filtros padrao; demais criterios ficam em **Mais filtros**.
- Um **episodio observado** pertence a exatamente um **app observado** e pode ter um **estado de analise**.
- Um **app observado** pode ou nao ser um **app catalogado**.
- Um **app catalogado** pode mapear estados tecnicos internos para os selos
  visiveis **tipo aprovado**, **tipo sugerido** ou **tipo nao avaliado**.
- Um **tipo de aplicativo** traduz uma **categoria analitica TCC/OWL** para a UI principal.
- Todo **app observado** entra no fluxo unico de classificacao progressiva:
  **tipo aprovado**, **tipo sugerido** ou **tipo nao avaliado**.
- **Tipo sugerido** entra na analise sem depender de aprovacao posterior, mas
  deve ficar visualmente distinto de **tipo aprovado**.
- **Tipo sugerido** participa da rosca e dos resumos principais junto com
  **tipo aprovado**; a diferenca deve aparecer por selo, texto curto ou detalhe,
  nao por exclusao da visualizacao principal.
- Na rosca, cor identifica a fatia do grafico; o estado **tipo aprovado**,
  **tipo sugerido** ou **tipo nao avaliado** aparece por selo textual.
- O detalhe de uma fatia selecionada em **Como o smartphone foi usado** abre
  inline abaixo do item selecionado, nao como card separado no fim da secao.
- A expansao inline de uma fatia deve conter resumo numerico, selo de
  classificacao e apps do grupo; mecanismos, IRI, evidencias e cautelas ficam em
  detalhe progressivo.
- **Tipo sugerido** exige ao menos um mecanismo plausivel mapeavel ao TCC/OWL;
  tempo de tela alto, intensidade alta ou recorrencia isolada nao bastam.
- O mecanismo que sustenta **tipo sugerido** deve vir de regra ou catalogo local
  versionado, nao de inferencia livre em runtime nem de consulta externa nao
  reprodutivel.
- A fronteira entre **tipo aprovado** e **tipo sugerido** e a origem da
  classificacao: catalogo curado do TCC/OWL para aprovado; regra local
  heuristica versionada para sugerido.
- Os rotulos visiveis dos estados sao **Tipo aprovado**, **Tipo sugerido** e
  **Tipo nao avaliado**. Nao usar "TCC/OWL" no selo principal; reservar TCC/OWL
  para detalhe, evidencia e rastreabilidade.
- **Tipo nao avaliado** indica pendencia de classificacao, nao exclusao do app da analise.
- **Notificacoes observadas** podem existir sem **conteudo textual de notificacoes**.
- **Notificacoes observadas** contam chaves unicas por app/dia; atualizacoes ou
  reposts da mesma notificacao nao incrementam a metrica.
- Contagens antigas de **notificacoes observadas** geradas antes da deduplicacao
  nao sao migradas; a serie corrigida reinicia para evitar totais inflados.
- Chaves de deduplicacao de **notificacoes observadas** ficam retidas por 7 dias,
  alinhadas ao conteudo textual opcional de notificacoes.
- **Notificacoes observadas** excluem notificacoes persistentes ou operacionais
  no numero principal quando o Android permitir identificar esse tipo de evento.
- **Conteudo textual de notificacoes** exige autorizacao por app e nao altera **sinais observados**, **score_sinais**, **estado de analise** ou **forca contextual**.
- **Autorizar apps observados** muda apenas a lista de pacotes autorizados para
  conteudo textual; nao altera contagem de notificacoes nem analises.
- **Desbloqueios** pertencem ao dia, nao ao app.
- **Indicios de retencao hoje** resume o dia sem criar score global do usuario;
  ele pode considerar contribuicoes curadas de **score_total**, **tecnica
  psicologica** e **intencao institucional** quando houver rastreabilidade.
- **Indicios de retencao hoje** aparece no **Resumo do dia** junto das metricas
  macro, mas como faixa descritiva dos indicios observados, nao como numero.
- **Sinais observados hoje** detalha cientificamente os **Indicios de retencao
  hoje** e nao repete **Tempo de tela**, **Desbloqueios** nem **Notificacoes**.
- **Cobertura observada** deve aparecer na UI principal como qualidade da leitura
  do dia; **Contexto TCC/OWL aprovado** deve aparecer como tempo em tipos
  aprovados ou sugeridos, preservando a rastreabilidade tecnica no detalhe.
- **Tecnica psicologica** e **intencao institucional** so devem aparecer como determinadas quando o catalogo tiver evidencia curada e relacao explicita com **mecanismo tecnico** ou **app observado**.
- **Tecnica psicologica** e **intencao institucional** so podem promover
  convergencia quando tiverem evidencia media ou alta, papel contextual de
  retencao, IRI, escopo e cautela exibiveis.
- **`score_total`** usa pesos maximos por dimensao: sinais comportamentais 0.40,
  mecanismos tecnicos 0.25, tecnicas psicologicas 0.20 e intencoes institucionais
  0.15.
- A UI principal comunica **`score_total`** como **Indicios de retencao**; o
  nome tecnico, valor numerico e decomposicao ficam na **rastreabilidade
  cientifica**.

## Example dialogue

> **Dev:** "Nike Run Club apareceu com 28 minutos e intensidade alta. Posso dizer que ele apresenta retencao?"

> **Domain expert:** "Ele entra na analise. Se houver sinais suficientes para hipotese contextual, aparece como **tipo sugerido**; se nao houver, aparece como **tipo nao avaliado**."

> **Dev:** "Entao o usuario ainda pode analisar o app?"

> **Domain expert:** "Sim. A UI deve mostrar dados observados e a classificacao disponivel, distinguindo **tipo sugerido** de **tipo aprovado**."

> **Dev:** "E YouTube com tecnica psicologica nao determinada?"

> **Domain expert:** "YouTube tem **mecanismos tecnicos** aprovados no catalogo, mas os campos **tecnica psicologica** e **intencao institucional** nao foram curados; a UI deve explicar isso sem parecer erro."

## Flagged ambiguities

- "Contexto OWL insuficiente" e "Contexto indisponivel" aparecem como sinonimos, mas devem ser separados: **contexto insuficiente** e sobre catalogacao do app; **dado indisponivel** e sobre leitura, permissao ou cobertura.
- "Tempo de tela", "tempo ativo" e "duracao ativa" aparecem juntos; para UI principal, usar **tempo de tela** e reservar duracao ativa para detalhe tecnico.
- "score-sinais" aparece em UI final; para usuario, preferir **intensidade dos sinais observados** e manter `score_sinais` na rastreabilidade.
- "Categoria TCC/OWL" nao deve aparecer como termo principal para usuario final; usar **Tipo de aplicativo** e reservar **Categoria analitica TCC/OWL** para rastreabilidade.
- "Rosca observacional" descreve o formato do grafico, nao a pergunta do usuario; usar **Como o smartphone foi usado** como titulo do card.
- "Contexto OWL insuficiente" nao deve ser o rotulo principal para apps observados sem classificacao suficiente; usar **Tipo nao avaliado** na UI. Quando houver hipotese automatica suficiente, usar **Tipo sugerido** sem apresentar isso como fila de aprovacao.
- "Apps do dia" nao deve ser card separado em Hoje quando repetir a rosca; apps
  individuais ficam no agrupamento por app e na expansao inline do card **Como o
  smartphone foi usado**.
- "Tendencia da janela" esta acumulando resumo, ranking, estados e interpretacao; o termo deve significar variacao longitudinal, nao card textual completo.
- "Explorar episodios da janela" mistura exploracao, ordenacao e filtros avancados; o termo recomendado e **explorador longitudinal**, com filtros essenciais visiveis e filtros avancados ocultos ou progressivos.
- "Consultar conteudo armazenado de notificacoes" aparece em **Analises**, mas pertence a **Configuracoes**, porque trata privacidade e autorizacao, nao leitura longitudinal.
- "Tecnica psicologica" e "intencao institucional" aparecem como "nao determinada" sem contexto; a UI deve dizer "nao curada no catalogo" quando o app estiver catalogado, para diferenciar de ausencia de classe na OWL.
