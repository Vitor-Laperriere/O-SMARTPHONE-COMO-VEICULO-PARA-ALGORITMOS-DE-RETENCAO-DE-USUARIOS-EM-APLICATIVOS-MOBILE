# foco_tela

Protótipo Flutter do TCC sobre smartphone, retenção e leitura de uso do dispositivo.

## O que este app faz hoje

- Mostra o dashboard longitudinal com janelas de 3, 7, 15, 30 dias e semestre,
  mantendo os últimos 7 dias como recorte padrão.
- Exibe resumo da janela, comparação com período anterior equivalente quando
  há cobertura suficiente, mudanças no período, conceitos observados do TCC/OWL
  e episódios relevantes com filtros progressivos.
- Lista os episódios reconstruídos com início, fim e duração ativa.
- Abre um detalhe diário com métricas, cobertura e lista de episódios e permite
  auditar a classificação bidimensional de cada episódio elegível.
- Carrega uma configuração heurística versionada para os sinais `LongSessionDuration`,
  `HighScreenTime` e `FrequentUnlocking`, tratada como exploração técnica e não
  como corte clínico.
- Carrega um catálogo local versionado com 16 aplicativos verificados e gera um
  asset sincronizado a partir de `catalog/apps.yaml` e `catalog/evidence.yaml`.
- Apresenta `score_sinais` e força contextual de retenção separadamente, com
  contribuições, evidências, cobertura, provisoriedade e versões dos artefatos.
- Calcula `score_total` por episódio, integrando sinais comportamentais,
  mecanismos técnicos e associações curadas de técnica psicológica e intenção
  institucional. A UI principal usa **Indícios de retenção**; o termo técnico,
  valor numérico, pesos, versões, IRIs e cautelas ficam apenas na
  rastreabilidade científica.
- Persiste apenas derivados em SQLite: episódios detalhados por até 30 dias e,
  entre o 31º dia e seis meses, agregados diários por aplicativo com duração,
  quantidade de episódios, distribuição de estados, cobertura e versões.
  Eventos de uso permanecem efêmeros e nunca entram no banco.
- Coleta `NotificationCount` quando o Android concede acesso real a
  notificações. Sem permissão ou suporte, a UI mostra indisponível, não zero.
- Oferece modo opcional de conteúdo textual de notificações, desativado por
  padrão, separado da contagem, com allowlist por app, retenção máxima de sete
  dias, exclusão de backup e autenticação de dispositivo antes da consulta.
- Mantém conteúdo textual de notificações apenas consultável por aplicativo e
  horário; ele não alimenta métricas, sinais, scores, estados ou classificações.
- Exibe `PatternExplanation` nos estados de revisão e convergência, com
  linguagem exploratória, não diagnóstica e sem `score_total`.
- No detalhe convergente, oferece `SelfRegulationAlert` e, após confirmação,
  abre as configurações de uso do aplicativo ou seus detalhes como fallback,
  sem alterar qualquer configuração.
- Solicita permissão de acesso ao uso no Android quando necessário.
- Funciona localmente e sem Firebase ou outro serviço de nuvem.
- Usa `provider` e permite substituir as dependências de plataforma em testes.
- Distingue acesso negado, concedido e falha ao abrir as configurações sem
  fabricar métricas.
- Completa a navegação pelos fluxos de acesso, dashboard, detalhe diário,
  detalhe do episódio e configurações/privacidade, agora com navegação
  persistente entre Hoje, Análises, Apps e Configurações e abertura inicial em
  Hoje.
- Em Hoje, o Resumo do dia mostra Tempo de tela, Desbloqueios, Notificações e
  a faixa descritiva Indícios de retenção hoje, sem score global nem
  diagnóstico. O card Como o smartphone foi usado concentra a distribuição do
  tempo de tela por tipo de aplicativo ou app, com detalhe inline da fatia
  selecionada. O bloco Sinais observados hoje funciona como detalhe científico
  dos indícios, mostrando episódios com sinais, maior intensidade, sinais
  ativos, qualidade da leitura e tempo em tipos avaliados.
- Na área Apps, os cartões resolvem metadados locais do Android quando
  disponíveis: nome amigável, ícone e categoria nativa entram na leitura
  principal; `packageName` fica acessível no detalhe técnico. Os cartões também
  expõem o status de catalogação explícito como Tipo aprovado, Tipo sugerido ou
  Tipo não avaliado.
- A área Apps lista os aplicativos observados no histórico local carregado,
  incluindo apps não catalogados, permite filtrar por Tipo aprovado, Tipo
  sugerido e Tipo não avaliado, e abre detalhe inline com tempo de tela no dia/semana,
  episódios, notificações observadas quando disponíveis e a cautela de que
  desbloqueios são métrica diária contextual, não atribuída causalmente ao app.
- Em Análises, o seletor mostra 3, 7 e 30 dias sem exigir rolagem horizontal,
  mantém 15 dias e Semestre em acesso secundário, e organiza a leitura em
  Resumo da janela, Sinais e mecanismos observados, Mudanças no período e
  Episódios relevantes. O detalhe diário prioriza números analíticos TCC/OWL
  antes das métricas brutas, separa o filtro de episódios do dia do explorador
  longitudinal da janela e o detalhe de episódio destaca duração, Indícios de
  retenção, sinais ativos e contexto OWL antes da rastreabilidade científica.
- Em configurações/privacidade, reconsulta a permissão, mostra o diagnóstico da
  coleta de notificações, mostra as versões do catálogo, da heurística e do
  contrato OWL, explica a retenção local e permite apagar derivados após
  confirmação, preservando os artefatos.
- Em Configurações, separa a Coleta de notificações do Conteúdo textual de
  notificações: contar notificações não armazena mensagens; o modo textual fica
  desativado por padrão, é granular por app, exige autenticação para visualização,
  expira em até sete dias e não alimenta métricas, sinais, scores ou
  classificações.
- Em Configurações, oferece páginas informativas para Como os sinais são
  calculados e Configuração heurística, mostrando `score_sinais`, sinais, pesos,
  limiares, versão, unidades e cautelas sem permitir edição de parâmetros pela
  UI.

## Escopo do protótipo

- Android é a plataforma principal.
- iOS é secundário e deve ser tratado como comparação ou limitação.
- Não há autorrelato.
- Não há diagnóstico automático.
- Não há bloqueio coercitivo.

Para o contexto de decisão do protótipo, veja [`CONTEXT.md`](./CONTEXT.md).

Planejamento local relacionado:

- `../docs/prototipo/prd-analises-score-total-foco-tela-2026-06-26.md`: PRD
  local implementado tecnicamente para Análises e `score_total`; publicação
  externa não autorizada.
- `../docs/prototipo/issues-analises-score-total/`: issues locais AS-01 a
  AS-10 implementadas e validadas tecnicamente; revisão visual/mobile e aceite
  do pesquisador continuam pendentes em AS-10.

## Como rodar

Requisitos: Flutter 3.38.1 ou compatível, Android Studio e um dispositivo ou
emulador com Android 9/API 28 ou superior.

1. Instale as dependências:

   ```bash
   flutter pub get
   ```

2. Rode no dispositivo ou emulador desejado:

   ```bash
   flutter run
   ```

## Estrutura principal

- `lib/main.dart`: inicialização do app e seleção do repositório por plataforma.
- `lib/features/dashboard/`: análise diária em episódios, view model e
  repositórios de uso e derivados. O coordenador classifica antes da
  apresentação e o SQLite permanece encapsulado no repositório de dados.
- `lib/features/notifications/`: contratos de disponibilidade, contagem e
  diagnóstico do Notification Listener, além de conteúdo textual opcional de
  notificações, com implementação Android, fake testável e autorização em lote
  para apps observados.
- `lib/features/usage_access/`: contrato versionado, adaptador Dart e estados do
  fluxo de acesso aos dados de uso.
- `lib/features/assistive_action/`: contrato versionado, repositório e estado de
  apresentação da ação opcional de revisar configurações nativas.
- `lib/features/settings/`: modelo, view model e tela de configurações e
  privacidade, incluindo o comando confirmado de exclusão de derivados.
- `ios/`: integração nativa e experimentos de Screen Time no iOS.

## Verificação

```bash
flutter analyze
dart run tool/catalog/build_catalog.dart
dart run tool/catalog/validate_catalog.dart
flutter test
flutter test integration_test/v3_main_flow_test.dart -d flutter-tester
flutter test integration_test/v2_dashboard_flow_test.dart -d flutter-tester
flutter test integration_test/settings_privacy_flow_test.dart \
  -d flutter-tester
flutter test test/features/dashboard/data/sqflite_derived_analysis_repository_test.dart
flutter test test/features/notifications/data/android_notification_repository_test.dart
flutter test integration_test/daily_episode_flow_test.dart -d <android-device>
flutter test integration_test/episode_classification_flow_test.dart \
  -d <android-device>
flutter test integration_test/usage_access_flow_test.dart -d <android-device>
flutter test integration_test/android_usage_access_channel_test.dart \
  -d <android-device> --dart-define=EXPECTED_USAGE_ACCESS=denied
flutter test integration_test/android_usage_access_channel_test.dart \
  -d <android-device> --dart-define=EXPECTED_USAGE_ACCESS=granted
flutter test integration_test/android_usage_events_channel_test.dart \
  -d <android-device>
flutter test integration_test/android_assistive_settings_channel_test.dart \
  -d <android-device>
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/settings_privacy_flow_test.dart \
  -d <android-device>
cd android && ./gradlew app:testDebugUnitTest
```

O teste do canal nativo aceita `EXPECTED_USAGE_ACCESS=denied` ou `granted` por
`--dart-define` e deve ser executado depois de configurar o estado equivalente
no dispositivo.

Para validar a V3-08 em Android real, abra Configurações > Coleta de
notificações, toque em **Abrir acesso a notificações**, conceda o acesso do
Foco Tela no Android, volte ao app, toque em **Verificar novamente** e receba
uma notificação real após a habilitação. Só depois desse evento a última leitura
e as contagens deixam de ser "dado ainda não observado".

## Observações

- A V2 foi implementada localmente em 23/06/2026 a partir de
  `../docs/prototipo/prd-v2-foco-tela-2026-06-23.md` e das issues locais em
  `../docs/prototipo/issues-v2/`. Não houve publicação no GitHub.
- O projeto ainda está em consolidação documental e técnica.
- Parte da implementação iOS existente deve ser lida como exploração, não como fechamento de escopo.
- O fluxo de permissão foi validado em Android 14/API 34: o canal informa os
  estados reais, abre a tela nativa correta e o app segue após a concessão sem
  reinicialização.
- O catálogo inicial da V1-07 cobre 16 aplicativos verificados por packageName,
  com amostra aprovada de retenção/social, casos mistos e controles utilitários.
- A V1-08 classifica episódios elegíveis em quatro estados por uma matriz
  determinística. Dias encerrados com cobertura parcial mantêm os dados
  observados, mas não executam a classificação dependente dos sinais diários.
- A V1-09 limita a ação assistiva ao detalhe convergente e exige confirmação
  explícita. Cancelar ou retornar das configurações não altera a análise.
- A V1-10 persiste cada dia derivado em transação própria, substitui o lote
  provisório do mesmo dia, recupera somente versões compatíveis e remove
  automaticamente dias anteriores à janela móvel de sete dias.
- A V1-11 completa os cinco fluxos e a tela de privacidade. A exclusão manual
  remove os derivados do banco e da UI, mas mantém catálogo e configuração;
  uma atualização posterior pode reconstruir novos resultados observáveis.
- A validação técnica da V1-12 foi executada em Android físico API 34, incluindo
  permissão negada/concedida, canais de eventos e intents, cinco fluxos,
  retrato/paisagem, persistência/privacidade e operação offline. O fechamento
  formal aguarda a revisão do pesquisador no registro do repositório principal.
- A configuração heurística da V1-05 é técnica, exploratória e não diagnóstica;
  o parâmetro técnico `session_merge_gap_seconds` permanece separado dos
  limiares comportamentais.
- Se o Android Studio exibir erro de run configuration na IDE, recrie a configuração Flutter apontando para `lib/main.dart` ou rode `flutter run` no terminal a partir da raiz do projeto.
- Na V2, a política de retenção substitui a janela móvel de sete dias da V1:
  detalhes duram até 30 dias e agregados por aplicativo permanecem por até seis
  meses. Textos autorizados de notificações expiram em até sete dias.
- A V3-08 foi implementada localmente em 25/06/2026 com diagnóstico testável do
  Notification Listener e card Coleta de notificações; a validação HITL em
  Android real segue pendente antes de afirmar funcionamento completo em
  dispositivo.
- A V3-09 foi implementada localmente em 25/06/2026 com privacidade textual de
  notificações separada da contagem, heurística informativa e página central de
  `score_sinais`; `flutter analyze`, `flutter test` e
  `flutter test integration_test/settings_privacy_flow_test.dart -d flutter-tester`
  passaram.
- A V3-10 foi validada tecnicamente em 25/06/2026 com o novo fluxo principal
  `integration_test/v3_main_flow_test.dart`, validações Flutter e testes
  unitários Android. A validação HITL de Notification Listener em Android real
  e o aceite do pesquisador continuam pendentes.
- A iteração AS-01 a AS-10 de Análises e `score_total` foi implementada e
  validada tecnicamente em 26/06/2026. Foram executados
  `dart run tool/catalog/build_catalog.dart`,
  `dart run tool/catalog/validate_catalog.dart`, `flutter analyze`,
  `flutter test` e
  `flutter test integration_test/v3_main_flow_test.dart -d flutter-tester`.
  A validação visual/mobile no Android Studio para MacBook e o aceite do
  pesquisador permanecem pendentes.
