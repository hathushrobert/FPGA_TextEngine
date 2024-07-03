module oled #(
    parameter WAIT_TIME = 10000
) (
    input clk,
    input [7:0] i_pixel_data,
    output reg w_en,
    output io_sclk,
    output io_sdin,
    output io_reset,
    output io_cs,
    output io_dc
);

    wire [7:0] w_pixel_data;

    assign w_pixel_data = i_pixel_data;



    localparam STATE_POWER_ON = 0;
    localparam STATE_LOAD_COMMAND = 1;
    localparam STATE_SEND_DATA = 2;
    localparam STATE_CHECK_NEXT_INSTRUCTION = 3;
    localparam STATE_LOAD_PIXEL_DATA = 4;

    reg sclk = 1;
    reg sdin = 0;
    reg reset = 1;
    reg cs = 1;
    reg dc = 0;

    reg [2:0] state = STATE_POWER_ON;
    reg [32:0] counter = 0;
    reg [7:0] data_to_send = 8'd0;
    reg [2:0] sdin_bit_index = 3'b111;

    
    

    assign io_sclk = sclk;
    assign io_sdin = sdin;
    assign io_reset = reset;
    assign io_cs = cs; 
    assign io_dc = dc;




    localparam SETUP_INSTRUCTIONS = 23;
    
    reg [(SETUP_INSTRUCTIONS*8)-1:0] startup_commands = {
    8'hAE,  // display off

    8'h81,  // contast value to 0x7F according to datasheet
    8'h7F,  

    8'hA6,  // normal screen mode (not inverted)

    8'h20,  // horizontal addressing mode
    8'h00,  

    8'hC8,  // normal scan direction

    8'h40,  // first line to start scanning from

    8'hA1,  // address 0 is segment 0

    8'hA8,  // mux ratio
    8'h3f,  // 63 (64 -1)

    8'hD3,  // display offset
    8'h00,  // no offset

    8'hD5,  // clock divide ratio
    8'h80,  // set to default ratio/osc frequency

    8'hD9,  // set precharge
    8'h22,  // switch precharge to 0x22 default

    8'hDB,  // vcom deselect level
    8'h20,  // 0x20 

    8'h8D,  // charge pump config
    8'h14,  // enable charge pump

    8'hA4,  // resume RAM content

    8'hAF   // display on
  };
    reg[7:0] command_bit_index = (SETUP_INSTRUCTIONS*8);





    always @(posedge clk) begin
        
        case(state)

            STATE_POWER_ON:begin
                w_en <= 0;
                counter <= counter + 1;
                if (counter < WAIT_TIME) begin
                    reset <= 1;                    
                end
                else if (counter < WAIT_TIME*2) begin
                    reset <= 0;
                end
                else if (counter < WAIT_TIME * 3) begin
                    reset <= 1;
                end
                else begin
                  counter <= 32'd0;
                  state <= STATE_LOAD_COMMAND;
                  
                end  
            end

            STATE_LOAD_COMMAND:begin

                data_to_send <= startup_commands[(command_bit_index - 1)-:8];
                command_bit_index <= command_bit_index - 8;
                sdin_bit_index <= 3'b111;
                state <= STATE_SEND_DATA;  

                dc <= 0;
                cs <= 0;     
                counter <= 32'd0;  
            end

            STATE_SEND_DATA:begin
                if (counter == 32'd0) begin

                    counter <= 32'd1;
                    sclk <= 0;    // Falling edge, this is when the sdin bit is updated
                    sdin <= data_to_send[sdin_bit_index];               
                end
                else begin
                    counter <= 32'd0;
                    sclk <= 1;          // Rising edge, this is when the bit index is read and checked
                    if (sdin_bit_index == 3'b000) begin
                        state <= STATE_CHECK_NEXT_INSTRUCTION;
                    end
                    else sdin_bit_index <= sdin_bit_index - 1; 
                end                  
            end

            STATE_CHECK_NEXT_INSTRUCTION:begin
                
                if (command_bit_index == 0) begin
                    cs <= 1;
                    state <= STATE_LOAD_PIXEL_DATA;
                    w_en <= 1;
                end
                else begin
                    state <= STATE_LOAD_COMMAND;
                end
            end

            STATE_LOAD_PIXEL_DATA:begin
                
                dc <= 1;
                cs <= 0;
                sdin_bit_index <= 3'b111;
                

                if (w_en) begin
                    state <= STATE_SEND_DATA;
                    data_to_send <= w_pixel_data;
                end
                else data_to_send <= 0;

            end       
        endcase
    end

    
    
endmodule