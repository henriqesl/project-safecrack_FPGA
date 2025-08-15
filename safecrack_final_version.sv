/**
 * @module safecrack_final_version
 * @author Henrique Lima, Luiz Taiguara, Mateus Barbosa e Mateus Martins
 * @date 14 de agosto de 2025
 * @version 13.0
 * @brief Versão melhorada do safecrackPRO
 *
 * @details
 * - SW0 (rst):     Reset geral do sistema (ativo em alto).
 * - SW1 (confirm): Mantido em 'ON' para entrar no modo de programação.
 * - KEY0-3 (btn_n): Botões para inserir os dígitos da senha.
 * - LEDR0 (led_red):   Indica bloqueio por 10s.
 * - LEDG0 (led_green): Indica cofre destravado ou dígito correto (pisca).
 */
module safecrack_final_version (
    input             clk,         // Entrada do clock de 50 MHz da placa
    input             rst,         // Entrada do botão de reset (SW0)
    input             confirm,     // Entrada da chave de programação (SW1)
    input      [3:0]  btn_n,       // Entradas dos 4 botões (KEY0-3)
    output reg        led_green,   // Saída para o LED verde
    output reg        led_red      // Saída para o LED vermelho
);

    // --- Parâmetros Globais ---
    // Parâmetros são constantes usadas para facilitar a leitura e manutenção do código.
    localparam CLK_FREQ = 50_000_000;                     // Frequência do clock em Hz
    localparam LOCK_TIME_SECONDS = 10;                     // Duração do bloqueio em segundos
    localparam LOCK_MAX_CYCLES = CLK_FREQ * LOCK_TIME_SECONDS; // Duração do bloqueio em ciclos de clock
    localparam BLINK_FREQ_HZ = 10;                         // Frequência do pisca-pisca dos LEDs em Hz
    localparam BLINK_PERIOD_CYCLES = CLK_FREQ / BLINK_FREQ_HZ; // Período do pisca-pisca em ciclos de clock
    localparam FEEDBACK_DURATION_CYCLES = CLK_FREQ / 2;    // Duração do feedback visual (0.5 segundos)

    // --- Definição de Estados ---
    // Cada estado da máquina de estados (FSM) recebe um código binário único.
    localparam [3:0] S_IDLE       = 4'd0;  // Estado de espera
    localparam [3:0] S_PROGRAM    = 4'd1;  // Estado de programação de senha
    localparam [3:0] S_INPUT_1    = 4'd2;  // Estado de entrada do 1º dígito
    localparam [3:0] S_FEEDBACK_1 = 4'd3;  // Estado de feedback do 1º dígito
    localparam [3:0] S_INPUT_2    = 4'd4;  // Estado de entrada do 2º dígito
    localparam [3:0] S_FEEDBACK_2 = 4'd5;  // Estado de feedback do 2º dígito
    localparam [3:0] S_INPUT_3    = 4'd6;  // Estado de entrada do 3º dígito
    localparam [3:0] S_FEEDBACK_3 = 4'd7;  // Estado de feedback do 3º dígito
    localparam [3:0] S_CHECK      = 4'd8;  // Estado que checa se a senha está correta
    localparam [3:0] S_UNLOCKED   = 4'd9;  // Estado de cofre aberto
    localparam [3:0] S_LOCKED     = 4'd10; // Estado de cofre bloqueado

    // --- Sinais ---
    // 'reg' armazena valores, 'wire' são como fios que conectam coisas.
    reg  [3:0] state, next_state;          // Sinais que controlam o estado atual e o próximo estado da FSM
    reg  [3:0] password_reg [0:2];        // Array para armazenar a senha correta
    reg  [3:0] attempt_reg [0:2];         // Array para armazenar a tentativa do usuário
    reg        password_set;              // Flag que indica se uma senha já foi definida
    reg  [1:0] password_idx;              // Índice usado durante a programação da senha
    reg  [31:0] lock_counter;              // Contador para o tempo de bloqueio
    reg  [31:0] feedback_timer;            // Timer para a duração do feedback visual
    reg        correct_digit_flag;        // Flag que indica se o último dígito digitado foi correto
    reg  [3:0] btn_s1, btn_s2, btn_s2_prev; // Sinais para sincronização dos botões
    reg        confirm_s1, confirm_s2, confirm_s2_prev; // Sinais para sincronização da chave
    reg  [31:0] blink_counter;             // Contador para gerar o efeito de pisca-pisca
    reg  [3:0] current_digit;             // Variável temporária para o dígito pressionado

    wire [3:0] btn_fall_edge;             // Sinal que fica '1' por um ciclo quando um botão é pressionado
    wire       confirm_fall_edge;         // Sinal que fica '1' por um ciclo quando a chave é desligada
    wire       password_is_correct;       // Sinal auxiliar que fica '1' se a tentativa for igual à senha
    wire       blink_on;                  // Sinal que oscila para criar o efeito de piscar
    wire       is_feedback_state;         // Sinal auxiliar que indica se a FSM está em um estado de feedback

    // --- Lógica de Sincronização e Detecção de Borda ---
    // Esta seção garante que os sinais externos (botões e chaves), que são assíncronos,
    // sejam lidos de forma segura pelo sistema síncrono (baseado no clock).
    always @(posedge clk or posedge rst) begin
        if (rst) begin btn_s1 <= 4'hF; btn_s2 <= 4'hF; end
        else begin btn_s1 <= btn_n; btn_s2 <= btn_s1; end
    end
    always @(posedge clk or posedge rst) begin
        if (rst) begin confirm_s1 <= 1'b0; confirm_s2 <= 1'b0; end
        else begin confirm_s1 <= confirm; confirm_s2 <= confirm_s1; end
    end
    always @(posedge clk or posedge rst) begin
        if (rst) begin btn_s2_prev <= 4'hF; confirm_s2_prev <= 1'b0; end
        else begin btn_s2_prev <= btn_s2; confirm_s2_prev <= confirm_s2; end
    end
    // A detecção de borda de descida compara o valor atual do sinal com o valor do ciclo anterior.
    assign btn_fall_edge = btn_s2_prev & ~btn_s2;
    assign confirm_fall_edge = confirm_s2_prev & ~confirm_s2;

    // --- Máquina de Estados Finitos (FSM) ---

    // Bloco 1: Registro de Estado (Sequencial)
    // Este bloco atualiza o estado atual (`state`) com o próximo estado (`next_state`) a cada subida do clock.
    always @(posedge clk or posedge rst) begin
        if (rst) state <= S_IDLE;
        else     state <= next_state;
    end
    
    // Sinal auxiliar para simplificar a lógica de checagem no Bloco 2.
    assign password_is_correct = (password_reg[0] == attempt_reg[0]) &&
                                 (password_reg[1] == attempt_reg[1]) &&
                                 (password_reg[2] == attempt_reg[2]);

    // Bloco 2: Lógica de Próximo Estado (Combinacional)
    // Este é o "cérebro" da FSM. Ele decide qual será o próximo estado baseado no estado atual e nas entradas.
    always @(*) begin
        next_state = state; // Valor padrão: permanecer no mesmo estado.
        case (state)
            S_IDLE:
                if (confirm_s2) next_state = S_PROGRAM;
                else if (password_set) next_state = S_INPUT_1;
            S_PROGRAM:
                if (confirm_fall_edge) next_state = S_IDLE;
            S_INPUT_1:    if (|btn_fall_edge) next_state = S_FEEDBACK_1;
            S_FEEDBACK_1: if (feedback_timer == 0) next_state = S_INPUT_2;
            S_INPUT_2:    if (|btn_fall_edge) next_state = S_FEEDBACK_2;
            S_FEEDBACK_2: if (feedback_timer == 0) next_state = S_INPUT_3;
            S_INPUT_3:    if (|btn_fall_edge) next_state = S_FEEDBACK_3;
            S_FEEDBACK_3: if (feedback_timer == 0) next_state = S_CHECK;
            
            S_CHECK: begin
                // Se a senha estiver correta, vai para o estado de sucesso.
                if (password_is_correct)
                    next_state = S_UNLOCKED; 
                // Se a senha estiver errada (qualquer erro), vai IMEDIATAMENTE para o estado de bloqueio.
                else
                    next_state = S_LOCKED;   
            end

            S_UNLOCKED:
                if (confirm_s2) next_state = S_PROGRAM;
            S_LOCKED:
                if (lock_counter >= LOCK_MAX_CYCLES - 1) next_state = S_IDLE;
        endcase
    end

    // Bloco 3: Lógica de Ações de Estado (Sequencial)
    // Este bloco define as "ações" que acontecem em cada estado, como alterar contadores e salvar dados.
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Reseta todas as variáveis importantes
            password_set <= 1'b0; password_idx <= 0;
            lock_counter <= 0; feedback_timer <= 0;
            attempt_reg[0] <= 0; attempt_reg[1] <= 0; attempt_reg[2] <= 0;
        end else begin
            // Decrementa o timer de feedback se ele estiver ativo
            if (feedback_timer > 0) feedback_timer <= feedback_timer - 1;
            // Incrementa o contador de bloqueio se estiver no estado S_LOCKED
            if (state == S_LOCKED)  lock_counter <= lock_counter + 1;
            
            case (state)
                S_IDLE: begin lock_counter <= 0; end // Zera o contador de bloqueio ao ficar ocioso
                S_PROGRAM: begin
                    if (!confirm_s2_prev) begin password_idx <= 0; password_set <= 1'b0; end // Ao entrar no modo prog.
                    if (|btn_fall_edge && password_idx < 3) begin
                        if      (btn_fall_edge[0]) password_reg[password_idx] <= 4'd0; else if (btn_fall_edge[1]) password_reg[password_idx] <= 4'd1; else if (btn_fall_edge[2]) password_reg[password_idx] <= 4'd2; else if (btn_fall_edge[3]) password_reg[password_idx] <= 4'd3;
                        password_idx <= password_idx + 1;
                    end
                    if (confirm_fall_edge) begin if (password_idx == 3) password_set <= 1'b1; end // Ao sair do modo prog.
                end
                S_INPUT_1: begin
                    if (|btn_fall_edge) begin
                        if      (btn_fall_edge[0]) current_digit = 4'd0; else if (btn_fall_edge[1]) current_digit = 4'd1; else if (btn_fall_edge[2]) current_digit = 4'd2; else current_digit = 4'd3;
                        attempt_reg[0] <= current_digit; // Salva o 1º dígito da tentativa
                        correct_digit_flag <= (current_digit == password_reg[0]); // Verifica se o dígito está certo
                        feedback_timer <= FEEDBACK_DURATION_CYCLES; // Inicia o timer do feedback visual
                    end
                end
                S_INPUT_2: begin
                    if (|btn_fall_edge) begin
                        if      (btn_fall_edge[0]) current_digit = 4'd0; else if (btn_fall_edge[1]) current_digit = 4'd1; else if (btn_fall_edge[2]) current_digit = 4'd2; else current_digit = 4'd3;
                        attempt_reg[1] <= current_digit; // Salva o 2º dígito
                        correct_digit_flag <= (current_digit == password_reg[1]);
                        feedback_timer <= FEEDBACK_DURATION_CYCLES;
                    end
                end
                S_INPUT_3: begin
                    if (|btn_fall_edge) begin
                        if      (btn_fall_edge[0]) current_digit = 4'd0; else if (btn_fall_edge[1]) current_digit = 4'd1; else if (btn_fall_edge[2]) current_digit = 4'd2; else current_digit = 4'd3;
                        attempt_reg[2] <= current_digit; // Salva o 3º dígito
                        correct_digit_flag <= (current_digit == password_reg[2]);
                        feedback_timer <= FEEDBACK_DURATION_CYCLES;
                    end
                end
            endcase
        end
    end

    // --- Lógica de Geração do Pisca-Pisca ---
    // Contador que reinicia continuamente para criar uma onda quadrada (pisca-pisca).
    always @(posedge clk or posedge rst) begin
        if (rst) blink_counter <= 0;
        else if (blink_counter >= BLINK_PERIOD_CYCLES - 1) blink_counter <= 0;
        else blink_counter <= blink_counter + 1;
    end
    
    // O sinal 'blink_on' fica '1' durante metade do período e '0' na outra metade.
    assign blink_on = blink_counter > (BLINK_PERIOD_CYCLES / 2);
    // Sinal auxiliar para facilitar a lógica de saída.
    assign is_feedback_state = (state == S_FEEDBACK_1) || (state == S_FEEDBACK_2) || (state == S_FEEDBACK_3);

    // --- Lógica de Saída (LEDs) ---
    // Bloco combinacional que define o estado dos LEDs baseado no estado atual da FSM e outros sinais.
    always @(*) begin
        led_green = 1'b0; // Valor padrão: LED apagado
        led_red   = 1'b0; // Valor padrão: LED apagado

        // Condição para acender o LED verde:
        // Ou o cofre está aberto, ou estamos em um estado de feedback com o dígito correto e o sinal de piscar está ativo.
        if ((state == S_UNLOCKED) || (is_feedback_state && correct_digit_flag && blink_on)) begin
            led_green = 1'b1;
        end
        
        // Condição para acender o LED vermelho:
        // Apenas se o cofre estiver no estado de bloqueio.
        if (state == S_LOCKED) begin
            led_red = 1'b1;
        end
    end

endmodule
