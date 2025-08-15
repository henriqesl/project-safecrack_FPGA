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
    input             clk,
    input             rst,
    input             confirm,
    input      [3:0]  btn_n,
    output reg        led_green,
    output reg        led_red
);

    // --- Parâmetros Globais ---
    localparam CLK_FREQ = 50_000_000;
    localparam LOCK_TIME_SECONDS = 10;
    localparam LOCK_MAX_CYCLES = CLK_FREQ * LOCK_TIME_SECONDS;
    localparam BLINK_FREQ_HZ = 10;
    localparam BLINK_PERIOD_CYCLES = CLK_FREQ / BLINK_FREQ_HZ;
    localparam FEEDBACK_DURATION_CYCLES = CLK_FREQ / 2;

    // --- Definição de Estados ---
    localparam [3:0] S_IDLE       = 4'd0;
    localparam [3:0] S_PROGRAM    = 4'd1;
    localparam [3:0] S_INPUT_1    = 4'd2;
    localparam [3:0] S_FEEDBACK_1 = 4'd3;
    localparam [3:0] S_INPUT_2    = 4'd4;
    localparam [3:0] S_FEEDBACK_2 = 4'd5;
    localparam [3:0] S_INPUT_3    = 4'd6;
    localparam [3:0] S_FEEDBACK_3 = 4'd7;
    localparam [3:0] S_CHECK      = 4'd8;
    localparam [3:0] S_UNLOCKED   = 4'd9;
    localparam [3:0] S_LOCKED     = 4'd10;

    // --- Sinais ---
    reg  [3:0] state, next_state;
    reg  [3:0] password_reg [0:2];
    reg  [3:0] attempt_reg [0:2];
    reg        password_set;
    reg  [1:0] password_idx;
    // error_count foi REMOVIDO
    reg  [31:0] lock_counter;
    reg  [31:0] feedback_timer;
    reg        correct_digit_flag;
    reg  [3:0] btn_s1, btn_s2, btn_s2_prev;
    reg        confirm_s1, confirm_s2, confirm_s2_prev;
    reg  [31:0] blink_counter;
    reg  [3:0] current_digit;

    wire [3:0] btn_fall_edge;
    wire       confirm_fall_edge;
    wire       password_is_correct;
    wire       blink_on;
    wire       is_feedback_state;

    // --- Lógica de Sincronização e Detecção de Borda ---
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
    assign btn_fall_edge = btn_s2_prev & ~btn_s2;
    assign confirm_fall_edge = confirm_s2_prev & ~confirm_s2;

    // --- Máquina de Estados Finitos (FSM) ---

    always @(posedge clk or posedge rst) begin
        if (rst) state <= S_IDLE;
        else     state <= next_state;
    end
    
    assign password_is_correct = (password_reg[0] == attempt_reg[0]) &&
                                 (password_reg[1] == attempt_reg[1]) &&
                                 (password_reg[2] == attempt_reg[2]);

    always @(*) begin
        next_state = state;
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
            
            // #############################################################
            // ############## LÓGICA FINAL E SIMPLIFICADA ##################
            // #############################################################
            S_CHECK: begin
                if (password_is_correct)
                    next_state = S_UNLOCKED; // Acertou -> Abre
                else
                    next_state = S_LOCKED;   // Errou -> BLOQUEIA!
            end

            S_UNLOCKED:
                if (confirm_s2) next_state = S_PROGRAM;
            S_LOCKED:
                if (lock_counter >= LOCK_MAX_CYCLES - 1) next_state = S_IDLE;
        endcase
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            password_set <= 1'b0; password_idx <= 0;
            lock_counter <= 0; feedback_timer <= 0;
            attempt_reg[0] <= 0; attempt_reg[1] <= 0; attempt_reg[2] <= 0;
        end else begin
            if (feedback_timer > 0) feedback_timer <= feedback_timer - 1;
            if (state == S_LOCKED)  lock_counter <= lock_counter + 1;
            
            case (state)
                S_IDLE: begin lock_counter <= 0; end
                S_PROGRAM: begin
                    if (!confirm_s2_prev) begin password_idx <= 0; password_set <= 1'b0; end
                    if (|btn_fall_edge && password_idx < 3) begin
                        if      (btn_fall_edge[0]) password_reg[password_idx] <= 4'd0; else if (btn_fall_edge[1]) password_reg[password_idx] <= 4'd1; else if (btn_fall_edge[2]) password_reg[password_idx] <= 4'd2; else if (btn_fall_edge[3]) password_reg[password_idx] <= 4'd3;
                        password_idx <= password_idx + 1;
                    end
                    if (confirm_fall_edge) begin if (password_idx == 3) password_set <= 1'b1; end
                end
                S_INPUT_1: begin
                    if (|btn_fall_edge) begin
                        if      (btn_fall_edge[0]) current_digit = 4'd0; else if (btn_fall_edge[1]) current_digit = 4'd1; else if (btn_fall_edge[2]) current_digit = 4'd2; else current_digit = 4'd3;
                        attempt_reg[0] <= current_digit;
                        correct_digit_flag <= (current_digit == password_reg[0]);
                        feedback_timer <= FEEDBACK_DURATION_CYCLES;
                    end
                end
                S_INPUT_2: begin
                    if (|btn_fall_edge) begin
                        if      (btn_fall_edge[0]) current_digit = 4'd0; else if (btn_fall_edge[1]) current_digit = 4'd1; else if (btn_fall_edge[2]) current_digit = 4'd2; else current_digit = 4'd3;
                        attempt_reg[1] <= current_digit;
                        correct_digit_flag <= (current_digit == password_reg[1]);
                        feedback_timer <= FEEDBACK_DURATION_CYCLES;
                    end
                end
                S_INPUT_3: begin
                    if (|btn_fall_edge) begin
                        if      (btn_fall_edge[0]) current_digit = 4'd0; else if (btn_fall_edge[1]) current_digit = 4'd1; else if (btn_fall_edge[2]) current_digit = 4'd2; else current_digit = 4'd3;
                        attempt_reg[2] <= current_digit;
                        correct_digit_flag <= (current_digit == password_reg[2]);
                        feedback_timer <= FEEDBACK_DURATION_CYCLES;
                    end
                end
            endcase
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) blink_counter <= 0;
        else if (blink_counter >= BLINK_PERIOD_CYCLES - 1) blink_counter <= 0;
        else blink_counter <= blink_counter + 1;
    end
    
    assign blink_on = blink_counter > (BLINK_PERIOD_CYCLES / 2);
    assign is_feedback_state = (state == S_FEEDBACK_1) || (state == S_FEEDBACK_2) || (state == S_FEEDBACK_3);

    always @(*) begin
        led_green = 1'b0;
        led_red   = 1'b0;

        if ((state == S_UNLOCKED) || (is_feedback_state && correct_digit_flag && blink_on)) begin
            led_green = 1'b1;
        end
        
        if (state == S_LOCKED) begin
            led_red = 1'b1;
        end
    end

endmodule
