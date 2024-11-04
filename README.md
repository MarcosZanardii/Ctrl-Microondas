# Projeto de Controle para Micro-ondas em Verilog

Este projeto implementa um módulo de controle para um micro-ondas digital, escrito em Verilog. O módulo permite a configuração de tempo e potência, assim como o controle de estados operacionais, incluindo execução, pausa e parada. O sistema controla o display do micro-ondas, indicando o tempo restante e a potência selecionada.

## Estrutura do Projeto

O módulo principal é `ctrl_microondas`, responsável por gerenciar o comportamento do micro-ondas. Ele é dividido em várias partes, cada uma com uma função específica:

- **Entradas e Saídas**: 
  - **Entradas**: Botões para iniciar (`start`), pausar (`pause`), parar (`stop`), e ajuste da potência e tempo (`mais`, `menos`). Outras entradas incluem o estado da porta (`porta`), e um sinal de `clock` e `reset`.
  - **Saídas**: Controla o display de 7 segmentos (`an`, `dec_cat`) e a saída de potência (`potencia_rbg`).

- **Estados Principais**:
  - `CONF`: Estado de configuração, onde o tempo e a potência podem ser ajustados.
  - `RUN`: Estado de execução, no qual o tempo é contado e o micro-ondas opera.
  - `PAUSED`: Estado de pausa, ativado ao pressionar o botão `pause` ou ao abrir a porta.

- **Controle de Potência e Tempo**: 
  - `rPotencia` controla o nível de potência (baixa, média, alta).
  - `sec_total`, `min`, e `sec` mantêm o valor total de tempo em segundos e seus componentes de minutos e segundos.

- **Máquina de Estados Finitos (FSM)**: 
  - Define as transições entre `CONF`, `RUN`, e `PAUSED` com base nos sinais de entrada (`start`, `stop`, `pause`, `porta`).

- **Ajuste de Tempo**: 
  - O ajuste do tempo é feito através dos botões `mais` e `menos`, com limites predefinidos (até 99 minutos).

## Instanciações Internas

O módulo usa outras instâncias de módulos auxiliares, incluindo:
- `edge_detector`: Detecta as bordas de subida para evitar múltiplas leituras.
- `timer`: Controla o tempo restante e envia sinais de `done` quando o tempo termina.

## Diagrama de Funcionamento do FSM

O controle dos estados pode ser representado como:
1. **CONF** -> Configuração de tempo e potência
   - Transição para `RUN` ao pressionar `start`.
2. **RUN** -> Execução do micro-ondas
   - Transição para `CONF` ao pressionar `stop` ou ao final do tempo (`done`).
   - Transição para `PAUSED` ao pressionar `pause` ou ao abrir a porta (`porta`).
3. **PAUSED** -> Pausa temporária
   - Retorna para `RUN` ao pressionar `start` ou `pause`.
   - Retorna para `CONF` ao pressionar `stop`.

## Código para Controle do Display

O valor de potência é exibido no display de 7 segmentos com base em `rPotencia`:
- **Baixa Potência**: 3'b001
- **Média Potência**: 3'b010
- **Alta Potência**: 3'b100

A codificação é gerada no bloco `always @(*)` e é controlada pelo estado atual.

## Instruções para Uso

1. Compile o código e carregue-o na sua plataforma de simulação ou hardware de FPGA compatível.
2. Use os botões (`start`, `pause`, `stop`, `mais`, `menos`) para interagir com o sistema.
3. Monitore o display para ver as mudanças no tempo e potência.

## Observações

- O sistema reseta ao estado `CONF` se o sinal de `reset` for acionado.
- O tempo máximo permitido é de 99 minutos, e o ajuste de potência é feito em incrementos limitados (1 a 3).
  
## Dependências

Este projeto depende dos módulos `edge_detector` e `timer`, que precisam estar implementados para o funcionamento correto do sistema.

## Autor

Projeto desenvolvido em Verilog para fins educacionais e controle de micro-ondas em FPGA.
