# SafeCrack Pro: Cofre Digital com Senha Programável em SystemVerilog

## Visão Geral

[cite_start]Este repositório contém o projeto final da disciplina de Sistemas Digitais do Centro de Informática (CIn) da Universidade Federal de Pernambuco (UFPE)[cite: 7, 8, 9]. [cite_start]O projeto, intitulado **"SafeCrack Pro"**, consiste na reimplementação e extensão de um cofre digital com uma Máquina de Estados Finitos (FSM) em SystemVerilog, projetado para a placa FPGA DE2-115[cite: 13, 15, 16].

[cite_start]A principal característica desta implementação é a regra de segurança de **"Tolerância Zero"**: uma única tentativa de senha incorreta resulta em um bloqueio imediato do sistema por 10 segundos[cite: 19].

## Funcionalidades Implementadas

* [cite_start]**Senha Programável:** O usuário pode definir uma nova senha de três dígitos ao entrar no modo de programação[cite: 16].
* [cite_start]**Feedback Visual:** LEDs na placa DE2-115 são utilizados para fornecer feedback em tempo real sobre o status do sistema, indicando progresso, sucesso, erro e o estado de bloqueio[cite: 16].
* [cite_start]**Bloqueio por "Tolerância Zero":** Após uma única tentativa com a combinação de 3 dígitos incorreta, o sistema entra em um estado de bloqueio por 10 segundos[cite: 19].
* [cite_start]**Entradas Físicas Robustas:** O design inclui sincronizadores de dois estágios e lógica de detecção de borda de descida para as entradas dos botões, garantindo que cada pressionamento seja registrado de forma limpa e evitando problemas de metaestabilidade[cite: 48, 49, 50].

## Estrutura da Máquina de Estados (FSM)

[cite_start]A FSM é o núcleo de controle do projeto, gerenciando todo o fluxo de operação[cite: 26]. [cite_start]Ela foi desenhada com estados explícitos para cada etapa, garantindo clareza e robustez na lógica[cite: 28]. Os principais estados são:

* [cite_start]**`S_IDLE` (Ocioso):** Estado inicial e de repouso do sistema[cite: 30]. [cite_start]Aguarda a ativação do modo de programação ou o início de uma tentativa[cite: 31].
* [cite_start]**`S_PROGRAM` (Programação):** Ativado pela chave `confirm` (SW1)[cite: 32]. [cite_start]Permite a inserção de uma nova senha de 3 dígitos pressionando os botões KEY[cite: 33].
* [cite_start]**`S_INPUT_1`, `S_INPUT_2`, `S_INPUT_3`:** Estados de espera pela entrada de cada um dos três dígitos durante uma tentativa de desbloqueio[cite: 34].
* [cite_start]**`S_FEEDBACK_1`, `S_FEEDBACK_2`, `S_FEEDBACK_3`:** Estados temporários que fornecem feedback visual (pisca o LED verde) se o dígito inserido estiver correto[cite: 36, 37].
* [cite_start]**`S_CHECK` (Verificação):** Estado transitório que compara a senha digitada com a senha armazenada para decidir entre sucesso ou falha[cite: 38, 39, 40].
* [cite_start]**`S_UNLOCKED` (Destravado):** Estado de sucesso[cite: 41]. [cite_start]O cofre está aberto e o LED verde permanece aceso[cite: 42].
* [cite_start]**`S_LOCKED` (Bloqueado):** Estado de falha ativado após uma tentativa incorreta[cite: 43]. [cite_start]O sistema fica bloqueado por 10 segundos com o LED vermelho aceso[cite: 44].

## Mapa de Pinos

assets/IMG_PINOS.png
assets/MAPA_PINOS.png

### Modo de Programação

1.  [cite_start]Ligue a chave `confirm` (SW1) para entrar no modo de programação (`S_PROGRAM`)[cite: 52].
2.  [cite_start]Pressione três botões (`KEY0` a `KEY3`) em sequência para definir os três dígitos da sua senha[cite: 53].
3.  Desligue a chave `confirm` (SW1). [cite_start]O sistema salvará a senha se 3 dígitos tiverem sido inseridos e retornará ao estado `S_IDLE`[cite: 54].

### Modo de Verificação

1.  [cite_start]Certifique-se de que a chave `confirm` (SW1) esteja desligada[cite: 55]. O sistema estará em um dos estados `S_INPUT`.
2.  [cite_start]Insira os três dígitos da senha, um por vez[cite: 34].
3.  [cite_start]**Feedback:** A cada dígito correto, o LED verde piscará por meio segundo[cite: 57].
4.  **Resultado:**
    * [cite_start]**Senha Correta:** Após o terceiro dígito correto, o sistema entrará em `S_UNLOCKED` e o LED verde ficará aceso continuamente[cite: 41, 42].
    * [cite_start]**Senha Incorreta:** O sistema entrará em `S_LOCKED`, e o LED vermelho ficará aceso por 10 segundos[cite: 43, 44].

## Problemas Conhecidos

* [cite_start]A simulação no Waveform não se comportou de maneira consistente com os testes realizados na placa física[cite: 95].
* [cite_start]Deixar as chaves de `confirm` e `reset` ligadas simultaneamente pode causar um mau funcionamento temporário do sistema[cite: 96].
* [cite_start]A lógica de bloqueio atual só é ativada após a inserção da combinação completa dos 3 dígitos[cite: 97]. [cite_start]Não há um feedback claro de erro para dígitos parciais, o que pode confundir o usuário[cite: 98].

## Autores

* [cite_start]Luiz Taiguara de Oliveira Guimarães `<ltog>` [cite: 11]
* [cite_start]Henrique Lima `<hsl3>` [cite: 11]
* [cite_start]Mateus Barbosa `<mbos>` [cite: 11]
* [cite_start]Mateus Martins `<mmb2>` [cite: 11]
