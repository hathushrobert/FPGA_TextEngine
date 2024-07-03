module textEngine (
    input clk,
    input [7:0] i_character_data,
    input i_byte_ready,
    output reg [13:0] o_ram_address = 0,
    output reg [7:0] o_ram_data = 0,
    output reg w_en = 0
);
    parameter STATE_IDLE = 0;
    parameter STATE_LOAD_BMP_ADDRESS = 1;
    parameter STATE_SEND_TO_RAM = 2;

   parameter NUMBER_OF_CHARS_ENCODED = 28;
    
    reg [7:0] character_list[NUMBER_OF_CHARS_ENCODED-1:0];
    reg [7:0] bmp_memory [NUMBER_OF_CHARS_ENCODED*16 - 1:0];

    reg [2:0] state = STATE_IDLE;
    reg [7:0] r_input_character = 0;
    reg [5:0] r_cursor_position = 0;

    reg [9:0] r_char_list_address = 0;
    reg [9:0] r_bmp_memory_address = 0;
    reg [4:0] r_bmp_row_counter = 0;

    // Read file into memory
    initial begin
        $readmemh("font.hex", bmp_memory);
        $readmemh("characters.hex", character_list);
    end



    always @(posedge clk) begin

        case (state)
            STATE_IDLE:begin
                
                if (i_byte_ready)begin
                    r_input_character <= i_character_data;
                    state <= STATE_LOAD_BMP_ADDRESS;
                    r_char_list_address <= 0;
                end
            end

            STATE_LOAD_BMP_ADDRESS: begin
                
                if (r_input_character == character_list[r_char_list_address])begin
                    r_bmp_memory_address <= r_char_list_address * 16;
                    state <= STATE_SEND_TO_RAM;
                    r_bmp_row_counter <= 0;
                    w_en <= 1;
                    if (r_input_character == 8'h7F) r_cursor_position <= r_cursor_position - 1;
                end
                else r_char_list_address <= r_char_list_address + 1;

                if (r_char_list_address == NUMBER_OF_CHARS_ENCODED) begin
                    r_char_list_address <= 0;
                    state <= STATE_IDLE;
                end
            end

            STATE_SEND_TO_RAM: begin

                if (r_bmp_row_counter < 8) begin
                    
                    o_ram_address <= r_cursor_position * 8 + r_bmp_row_counter + (r_cursor_position/16 * 128);
                end
                else begin
                    o_ram_address <= r_cursor_position * 8 + r_bmp_row_counter - 8 + 128 + (r_cursor_position/16 * 128);              
                end
                o_ram_data <= bmp_memory[r_bmp_memory_address];  
                r_bmp_memory_address <= r_bmp_memory_address + 1;
                r_bmp_row_counter <= r_bmp_row_counter + 1;  

                if (r_bmp_row_counter == 16) begin
                    
                    state <= STATE_IDLE;
                    w_en <= 0;
                    if (r_input_character != 8'h7F) r_cursor_position <= r_cursor_position + 1;
                end             
            end
            default: state <= STATE_IDLE;
        endcase

        
        
    end


    
endmodule