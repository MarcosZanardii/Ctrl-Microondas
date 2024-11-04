`define IDLE    3'b001  // Estado inicial, esperando ação
`define CD      3'b010  // Estado de contagem regressiva
`define PAUSED  3'b100  // Estado de pausa

module timer (
  // Entradas
  input start, stop, pause,    // Controle do timer
  input [6:0] min, sec,        // Tempo inicial
  input reset, clock,          // Reset e clock do sistema
  input [5:0] d6,
  
  // Saídas
  output reg done,             // Indica se o timer terminou
  output [7:0] an, dec_cat     // Sinais do display
);

    // Wires para os dígitos do display
    wire [3:0] dez_min, uni_min, dez_sec, uni_sec;
    wire [5:0] d1, d2, d3, d4, dOFF;

    // Registradores para contagem e estado
    reg [25:0] cont_1s;        // Conta ciclos para gerar 1 segundo
    reg [12:0] sec_total;
    reg [2:0] EA, PE;          // Estado atual (EA) e próximo estado (PE)
    reg clock_1s;              // Clock de 1 Hz gerado
	
    // Gera o clock de 1 segundo
    always @(posedge clock or posedge reset) begin
    if (reset) begin
        cont_1s <= 26'd0;   // Zera o contador no reset
        clock_1s <= 1'b0;   // Zera o clock de 1s no reset
    end else begin
        cont_1s <= (cont_1s == 26'd49999999) ? 26'd0 : cont_1s + 1; // Reinicia o contador ou continua contando
        clock_1s <= (cont_1s == 26'd49999999) ? ~clock_1s : clock_1s; // Troca o clock de 1 segundo ou mantém o mesmo
    end 
end

    // Atualiza o estado atual
    always @(posedge clock or posedge reset) begin
        if (reset) 
            EA <= `IDLE; //Se reset, EA inicia em idle
        else 
            EA <= PE; // Atualiza o estado atual com o próximo estado (PE)
    end
        
    // Lógica dos estados
    always @(*) begin
        case(EA)
            `IDLE: PE = (start) ? `CD : `IDLE; // Se start for pressionado, começa a contagem; caso contrário, continua em espera

            `CD: PE =   (pause) ? `PAUSED : 
                        (stop || sec_total == 7'd0) ? `IDLE : `CD; // Pausa o timer ou volta ao início se stop ou tempo zerar; continua contando

            `PAUSED: PE =   (pause || start) ? `CD : 
                            (stop) ? `IDLE : `PAUSED; // Retoma a contagem ou para se o stop for pressionado; fica pausado

            default: PE = `IDLE; // Estado padrão é sempre o IDLE
        endcase
    end

    // Decrementa minutos e segundos
    always @(posedge clock_1s or posedge reset) begin
    sec_total <=    (reset) ? 13'd0 : 
                    (EA == `IDLE) ? (7'd60 * min) + sec :
                    (EA == `CD) ? ((sec_total > 13'd0) ? sec_total - 13'd1 : sec_total) : sec_total;
    end

    // Define se o timer está terminado ou não
    always @(*) begin
        done = (EA == `IDLE) ? 1'b1 : 1'b0;  // Done é 1 quando o tempo zera no estado IDLE
    end

    // Divide o tempo restante em dígitos para o display
    assign dez_min = (sec_total / 13'd60) / 13'd10;  // Dígito das dezenas de minutos
    assign uni_min = (sec_total / 13'd60) % 13'd10;   // Dígito das unidades de minutos
    assign dez_sec = (sec_total % 13'd60) / 13'd10;   // Dígito das dezenas de segundos
    assign uni_sec = (sec_total % 13'd60) % 13'd10;    // Dígito das unidades de segundos

    // Configuração para os displays
    assign dOFF = 6'b000000;
    assign d4 = {1'b1, dez_min, 1'b0};
    assign d3 = {1'b1, uni_min, 1'b0};
    assign d2 = {1'b1, dez_sec, 1'b0};
    assign d1 = {1'b1, uni_sec, 1'b0};

    // Instancia o driver do display
    dspl_drv_NexysA7 DUT_display( 
        .clock(clock), 
        .reset(reset), 
        .d1(d1), 
        .d2(d2), 
        .d3(d3), 
        .d4(d4), 
        .d5(dOFF), 
        .d6(d6), 
        .d7(dOFF), 
        .d8(dOFF), 
        .an(an), 
        .dec_cat(dec_cat)
    );
endmodule
