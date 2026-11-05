# BaixaTudo

[English](README.md) | **Português (Brasil)**

Aplicativo para macOS que baixa vídeos, áudio e conteúdos do Instagram a partir de links, com interface nativa em SwiftUI.

O BaixaTudo é uma evolução do [DLYT, projeto original de Mentor Neto](https://github.com/Neto/DLYT). Esta versão acrescenta melhorias na seleção de qualidade, downloads de fotos e carrosséis do Instagram, suporte experimental a Stories e configurações separadas de cookies para vídeos e Stories. Os créditos e o histórico de autoria do projeto original foram preservados.

Use apenas com conteúdos que você tem autorização para baixar.

## Recursos

- Downloads de YouTube, Instagram, TikTok, Vimeo e outros sites compatíveis com o yt-dlp. A disponibilidade varia conforme o site e o conteúdo.
- Seleção de qualidade por vídeo, incluindo até 4K quando disponível, e extração de áudio em MP3.
- Saída de vídeo em H.264 + AAC para reprodução no QuickTime; conversão quando necessária.
- Fotos e carrosséis do Instagram, além de Stories e destaques com suporte experimental.
- Fila de downloads, pasta de destino configurável e opções para mostrar ou abrir o arquivo ao concluir.
- yt-dlp, ffmpeg, ffprobe e deno empacotados no aplicativo compilado.

## Requisitos e instalação

- Mac com Apple Silicon (arm64).
- macOS 15 ou posterior.

O código está disponível neste repositório. Pacotes de instalação, quando publicados, ficam em [Releases](https://github.com/rcava/BaixaTudo/releases). Para compilar sua própria cópia, veja abaixo.

## Como usar

Cole o link, escolha a qualidade disponível e inicie o download. Os arquivos são salvos em Downloads por padrão; a pasta pode ser alterada nas preferências.

Se o conteúdo exigir login, configure os cookies do navegador conforme a seção seguinte.

## Preferências e cookies

Cookies podem conter informações da sua sessão. O BaixaTudo usa o yt-dlp para ler os cookies do navegador selecionado e utilizá-los nas solicitações ao site de origem. Não é necessário digitar sua senha no aplicativo.

### Cookies para vídeos

Esta opção vale para YouTube, Reels, posts do Instagram e outros links.

| Opção | Comportamento |
| --- | --- |
| Nenhum | Não lê cookies do navegador. É o padrão para vídeos e o ponto de partida para conteúdo público. |
| Automático | Tenta sem login primeiro e pode recorrer aos navegadores se necessário. |
| Navegador específico | Usa os cookies desse navegador. |

As opções de navegador são Safari, Brave, Chrome, Firefox e Edge. Entre na conta pelo navegador antes de tentar baixar um conteúdo que exige login.

### Cookies para Instagram Stories

Stories de imagem e vídeo, incluindo destaques, usam uma configuração independente: **Cookies para Instagram Stories**. Selecione um navegador em que você esteja conectado ao Instagram e tenha acesso ao conteúdo. Essa opção usa somente o navegador escolhido.

O padrão em uma instalação nova é Brave; altere se você usa outro navegador. Selecionar um navegador não garante que a sessão será aceita pelo Instagram.

Para ler os cookies do Safari, o aplicativo precisa de **Acesso Total ao Disco**, em Ajustes do Sistema → Privacidade e Segurança. Essa permissão permite acesso amplo a arquivos protegidos; conceda apenas se quiser utilizar esse recurso e confiar na sua cópia do aplicativo.

### Outras preferências

Em **Geral**, você pode escolher a pasta de destino, a qualidade padrão e se deseja mostrar ou abrir os arquivos ao concluir. Em **Motor**, pode consultar as ferramentas encontradas e, opcionalmente, indicar outro executável do yt-dlp. Deixe esse caminho vazio para usar o que acompanha o aplicativo.

## Limitações e solução de problemas

Os sites podem mudar suas regras e interfaces, causando falhas mesmo em links que funcionavam antes. A qualidade depende do conteúdo disponibilizado na origem. Conversões de vídeo podem levar tempo.

O suporte a Stories é experimental e usa uma adaptação específica do extrator do yt-dlp. Cookies válidos localmente não garantem acesso ao conteúdo. O aplicativo não concede acesso a conteúdos que sua conta não pode visualizar.

Se um download exigir login, confira o navegador selecionado e se a conta está conectada nele. Em caso de erro na leitura dos cookies do Safari, confira a permissão de Acesso Total ao Disco.

### Diagnóstico

Em Preferências → Motor, **Registrar diagnóstico detalhado** registra informações sobre as ferramentas e os erros. Ele começa desligado em Release e ligado por padrão em Debug, salvo preferências já gravadas. **Mostrar logs no Finder** abre `~/Library/Logs/BaixaTudo/`. O resumo de erros fica em `~/Library/Logs/BaixaTudo.log`.

O diagnóstico filtra valores conhecidos de cookies, tokens e credenciais, além de parâmetros e fragmentos de URLs. Revise os logs antes de compartilhar: eles ainda podem conter caminhos locais e informações sobre o conteúdo. O modo detalhado usa zero tentativas internas de repetição no yt-dlp; o fallback entre navegadores ainda pode ocorrer no modo Automático.

**Check Instagram session (offline)** procura o cookie de sessão no navegador escolhido para Stories. A verificação não acessa o Instagram, não exibe o valor do cookie e não confirma sua aceitação pelo servidor. Ela gera um log mesmo com o diagnóstico detalhado desligado.

Nunca publique cookies, senhas ou tokens em relatos de erro.

## Compilar a partir do código

Você precisa de Xcode com as ferramentas de linha de comando e Homebrew. Instale as dependências:

```zsh
brew install xcodegen ffmpeg deno dylibbundler python@3.11
```

Clone e compile:

```zsh
git clone https://github.com/rcava/BaixaTudo.git
cd BaixaTudo
./scripts/bundle-helpers.sh
xcodegen generate
xcodebuild -project BaixaTudo.xcodeproj -scheme BaixaTudo -configuration Debug \
  -destination 'platform=macOS,arch=arm64' build
```

O script de empacotamento baixa dependências e copia as ferramentas para `Vendor/Helpers`, que não faz parte do repositório. Execute-o antes da primeira compilação. Ele pressupõe Homebrew em `/opt/homebrew`.

`build-and-install.zsh` compila e revela o aplicativo no Finder. Arraste o `.app` para Aplicativos para instalar.

### Instalador assinado

`scripts/make-installer.sh` gera um pacote assinado e notarizado. Ele exige certificados Developer ID Application e Developer ID Installer e um perfil do notarytool chamado `BaixaTudo`. Os identificadores de equipe e nomes de certificados herdados do autor original precisam ser adaptados para sua conta. Certificados e chaves privadas não são fornecidos no repositório.

### Verificações locais

Os testes abaixo verificam diagnóstico e fixtures locais; não confirmam downloads reais do Instagram:

```sh
xcrun swiftc -swift-version 6 -D DEBUG BaixaTudo/Services/DiagnosticLog.swift tests/DiagnosticLogTests.swift -o /tmp/baixatudo-diagnostic-tests
/tmp/baixatudo-diagnostic-tests
python3 tests/test_session_diagnostic.py
python3 tests/test_instagram_stories.py
```

## Estrutura

| Pasta ou arquivo | Conteúdo |
| --- | --- |
| `BaixaTudo/Models` | Plataformas, qualidades e trabalhos de download |
| `BaixaTudo/Services` | Integração com yt-dlp, ferramentas e diagnóstico |
| `BaixaTudo/ViewModels` | Estado e gerenciamento da fila |
| `BaixaTudo/Views` | Interface SwiftUI |
| `scripts` | Empacotamento, compilação e instalador |
| `tests` | Verificações locais e fixtures |
| `project.yml` | Definição do projeto XcodeGen |

Tecnologias: Swift 6, SwiftUI e XcodeGen. Veja também o [histórico técnico](CHANGELOG.md).

## Relatar problemas e contribuir

Abra uma [issue](https://github.com/rcava/BaixaTudo/issues) com a versão do aplicativo e do macOS, o site envolvido, os passos para reproduzir e a mensagem de erro. Use links públicos quando possível e remova informações pessoais de capturas e logs.

Propostas de melhoria podem ser discutidas em issues e pull requests. As condições de reutilização do código dependem da definição de uma licença, conforme a seção seguinte.

## Créditos e licença

- Projeto original: [DLYT, de Mentor Neto / Spinoff](https://github.com/Neto/DLYT).
- Evolução do BaixaTudo: Ricardo Cavallini, com autoria preservada no histórico Git.
- Ferramentas: [yt-dlp](https://github.com/yt-dlp/yt-dlp), [FFmpeg](https://ffmpeg.org/) e [Deno](https://deno.com/), sujeitas às respectivas licenças.
- Correção experimental de Stories adaptada do [PR #17885 do yt-dlp](https://github.com/yt-dlp/yt-dlp/pull/17885), com detalhes em [STORIES-FIX.md](BaixaTudo/Resources/Diagnostics/STORIES-FIX.md).

Este repositório e o projeto original consultado não possuem arquivo de licença. A publicação do código não concede, por si só, uma licença de reutilização, modificação ou redistribuição. Nenhuma nova licença foi atribuída ao código herdado.

© 2026 Spinoff e respectivos autores.
