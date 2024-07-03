
module top(
    input clk,
    input btn,
    input uart_rx,
    output uart_tx,
    output io_sclk,
    output io_sdin,
    output io_reset,
    output io_cs,
    output io_dc,
    output [5:0] led
);

    
    wire [7:0] w_uart_output_byte;
    wire [5:0] w_led;

    uart inst_uart(
        
        clk,
        uart_rx,
        btn,
        uart_tx,
        w_led,
        w_byte_ready,
        w_uart_output_byte
    );

    assign led = w_led;

    
    reg [13:0] r_ram_read_address = 0;

    wire [7:0] w_pixel_data;

    wire [13:0] w_ram_read_address;

    wire w_ram_r_en;
    wire[7:0] w_ram_read_data;

    assign w_ram_read_address = r_ram_read_address;
    
    RAM inst_RAM (  
        clk,
        w_ram_w_en,
        w_ram_r_en,
        w_ram_write_address,
        w_ram_read_address,
        w_ram_write_data,
        w_ram_read_data
    );

        
    oled inst_oled (
        clk,
        w_ram_read_data,
        w_ram_r_en,
        io_sclk,
        io_sdin,
        io_reset,
        io_cs,
        io_dc 
    );

    wire [13:0]w_ram_write_address;
    wire [7:0] w_ram_write_data;

    textEngine inst_textEngine(
        
        clk,
        w_uart_output_byte,
        w_byte_ready,
        w_ram_write_address,
        w_ram_write_data,
        w_ram_w_en
    );

    reg [4:0] r_read_wait_counter = 0;

    always @(posedge clk) begin
        
        

        if (w_ram_r_en) begin

            if (r_read_wait_counter == 5'd17) begin

                r_read_wait_counter <= 0;
                r_ram_read_address <= r_ram_read_address + 1;
                if (r_ram_read_address == 14'd1023) r_ram_read_address <= 0;                
            end
            else r_read_wait_counter <= r_read_wait_counter + 1;
            
        end
    end






    
endmodule