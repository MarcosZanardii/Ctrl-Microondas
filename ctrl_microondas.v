`define CONF    3'b001    // Estado de configuração
`define RUN     3'b010    // Estado de execução
`define PAUSED  3'b100    // Estado de pausa

module ctrl_microondas (
  // Declaração das portas
  // Entradas
  input start, stop, pause,       // Botões de controle
  input porta, mais, menos, potencia,  // Sinais de controle adicionais
  input [1:0] min_mod,           // Modificadores de minutos
  input sec_mod,                 // Modificador de segundos
  input reset, clock,            // Sinal de reset e clock

  // Saídas
  output [7:0] an, dec_cat,      // Saídas para o display
  output reg [2:0] potencia_rbg  // Saída para controle de potência
);

  // WIRES
  wire start_clear, stop_clear, pause_clear, mais_clear, menos_clear, done, wStart, wPause, wStop;
  wire [5:0] dP;
  wire [3:0] preferencia;

  // REGS
  reg [12:0]sec_total;   // Total de segundos
  reg [6:0] min, sec;    // Minutos e segundos
  reg [2:0] EA, PE;      // Estados atual e próximo
  reg [1:0] rPotencia;   // Potência ajustada

  // Instanciação dos edge_detectors
  edge_detector DUT_start(.clock(clock), .reset(reset), .din(start),  .rising(start_clear));
  edge_detector DUT_stop(.clock(clock), .reset(reset), .din(stop),   .rising(stop_clear));
  edge_detector DUT_pause(.clock(clock), .reset(reset), .din(pause),  .rising(pause_clear));
  edge_detector DUT_mais(.clock(clock), .reset(reset), .din(mais),   .rising(mais_clear));
  edge_detector DUT_menos(.clock(clock), .reset(reset), .din(menos),  .rising(menos_clear));

  // Controla valor do display conforme potência
  assign dP = (rPotencia == 2'd1) ? {1'd1, 4'hA, 1'd0} : 
              (rPotencia == 2'd2) ? {1'd1, 4'hB, 1'd0} : {1'd1, 4'hC, 1'd0} ;

  // Define preferências de entrada
  assign preferencia = {potencia, min_mod[1], min_mod[0], sec_mod};  

  // Controle das preferências de entrada e ajuste dos valores
always @(posedge clock or posedge reset) begin
    if (reset) begin
        min <= 7'd0;
        sec <= 7'd0;
        rPotencia <= 3'd1;
        sec_total <= 13'd0;
    end else if (EA == `CONF) begin
        casex (preferencia)
            // Ajuste de potência
            4'b1xxx: begin
                rPotencia <= mais_clear ? //Ajusta potencia com os limites de [1, 3]
                             (rPotencia < 3'd3 ? rPotencia + 3'd1 : rPotencia) : 
                             (menos_clear ? (rPotencia > 3'd1 ? rPotencia - 3'd1 : rPotencia) : rPotencia);
            end
            // Ajuste da dezena de minutos
            4'bx1xx: begin
                sec_total <= mais_clear ? //Soma ou diminui 600sec = 10 * 1min, com os limite de 99min
                             ((sec_total + 13'd600 < 13'd5999) ? sec_total + 13'd600 : sec_total) :
                             (menos_clear ? ((sec_total < 13'd600) ? 13'd0 : sec_total - 13'd600) : sec_total);
            end
            // Ajuste da unidade de minutos
            4'bxx1x: begin
                sec_total <= mais_clear ? //Soma ou diminui 60sec = 1min, com os limite de 99min
                             ((sec_total + 13'd60 < 13'd5999) ? sec_total + 13'd60 : sec_total) :
                             (menos_clear ? ((sec_total < 13'd60) ? 13'd0 : sec_total - 13'd60) : sec_total);
            end
            // Ajuste da dezena de segundos
            4'bxxx1: begin
                sec_total <= mais_clear ? //Soma ou diminui 10sec, com os limites de 59sec
                             ((sec_total + 13'd10 < 13'd5999) ? sec_total + 13'd10 : sec_total) :
                             (menos_clear ? ((sec_total < 13'd10) ? 13'd0 : sec_total - 13'd10) : sec_total);
            end
            // Ajuste da unidade de segundos
            default: begin
                sec_total <= mais_clear ? //Soma ou diminui 1sec, com os limites de 59sec
                             ((sec_total < 13'd5999) ? sec_total + 13'd1 : sec_total) :
                             (menos_clear ? ((sec_total > 0) ? sec_total - 13'd1 : 13'd0) : sec_total);
            end
        endcase
        // Atualiza minutos e segundos a partir de sec_total
        min <= sec_total / 13'd60;
        sec <= sec_total % 13'd60;
    end else
        sec_total <= 13'd0; // Zera sec_total fora do estado CONF  
end

  // Controle da potência, ativa somente no estado RUN
  always @(*) begin
      if (EA == `RUN) begin
          potencia_rbg =  (rPotencia == 2'd1) ? 3'b001 : //Baixa
                          (rPotencia == 2'd2) ? 3'b010 : //Média
                          (rPotencia == 2'd3) ? 3'b100 : 3'b000;//Alta
      end else
          potencia_rbg = 3'b000;
  end

  // Controle do sinal de pausa com base na porta e no estado atual
  assign wPause = (EA == `RUN) ? ((~porta) ? 1'd1 : pause_clear) : ((~porta) ? 1'd0 : pause_clear);

  // Controle do sinal de start com base na porta
  assign wStart = (porta) ? start_clear : 1'd0;

  // Atribuição simples do sinal de stop
  assign wStop = stop_clear;

  // Máquina de estados
  always @(posedge clock or posedge reset) begin
    EA <= (reset) ? `CONF : PE;
  end
 
  // Lógica da transição de estados
  always @(*) begin
    case (EA)
        `CONF: PE = (wStart) ? `RUN : `CONF;

        `RUN:  PE = (wStop  || done)    ? `CONF :
                    (wPause || ~porta)  ? `PAUSED : `RUN;

        `PAUSED: PE = (wPause || wStart) ? `RUN :
                      (wStop) ? `CONF : `PAUSED;

        default: PE = `CONF;
    endcase
end

  // Instanciação do timer
  timer DUT (
      .start(wStart),        // Sinal de start
      .stop(wStop),          // Sinal de stop
      .pause(wPause),        // Sinal de pause
      .min(min),             // Valor de minutos
      .sec(sec),             // Valor de segundos
      .reset(reset),         // Sinal de reset
      .clock(clock),         // Sinal de clock
      .an(an),               // Segmentos do display
      .dec_cat(dec_cat),     // Catodos do display
      .d6(dP),               // Display de potência
      .done(done)            // Sinal de finalização
  );

endmodule
