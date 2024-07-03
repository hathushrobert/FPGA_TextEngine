module uart #(
    parameter DELAY_FRAMES = 234    // 27MHz / 115200 baudrate (234 ticks per bit sent)
) (

    input clk,
    input uart_rx,
    input btn,
    output uart_tx,
    output reg[5:0] led,
    output o_byte_ready,
    output reg [7:0] o_data_byte = 0
    
);

    localparam HALF_DELAY = DELAY_FRAMES / 2;   // Because we read the bit at the "middle" of the bit signal instead of its left edge

    // Registers and flags
    reg [7:0] input_shift_register = 0;
    reg [0:2] rx_bit_number = 0;   // Keeps track of the bit being read
    reg byte_ready = 0;         // Flag is set to 1 when a whole byte has been read and ready to be used
    reg [0:2] rx_state = 0;        // State variable upon which the module's behaviour depends on
    reg [7:0] rx_counter = 0;   // Counter variable that is active during RX protocol

    assign o_byte_ready = byte_ready;


    // Define machine states
    localparam RX_IDLE = 0;
    localparam RX_START_BIT = 1;
    localparam RX_READ_WAIT = 2;
    localparam RX_READ = 3;
    localparam RX_STOP_BIT = 4;
    localparam RX_HOLD_BYTE_EN = 5;

    // define the behaviour of the module
    always @(posedge clk) begin
        
        case (rx_state)
            RX_IDLE:begin // When idle, it does nothing until it detects a (low) startbit

                byte_ready <= 0;
                if (uart_rx == 0) begin
                    rx_state <= RX_START_BIT;
                    rx_counter <= 1;
                    rx_bit_number <= 0;
                    byte_ready <= 0;                   
                end
            end

            RX_START_BIT: begin // When start bit is detected, wait for HALF_DELAY ticks (you're essentially just setting a time offset)
                
                rx_counter <= rx_counter + 1;
                if (rx_counter == HALF_DELAY) begin

                    rx_state <= RX_READ_WAIT;
                    rx_counter <= 1;
                end            
            end

            RX_READ_WAIT: begin // Now wait for DELAY_FRAMES ticks and then switch state to RX_READ

                rx_counter <= rx_counter + 1;
                if (rx_counter + 1  == DELAY_FRAMES) begin
                    rx_state <= RX_READ;
                    rx_counter <= 1;
                end
            end

            RX_READ: begin // Enter the read bit into the shift register. If its the last bit then state change to STOP_BIT else change to READ_WAIT
                input_shift_register <= {uart_rx, input_shift_register[7:1]};
                rx_bit_number <= rx_bit_number + 1;

                if (rx_bit_number == 3'd7)begin

                  rx_state <= RX_STOP_BIT;
                end
                else rx_state <= RX_READ_WAIT;
            end

            RX_STOP_BIT:begin // wait for DELAY_FRAMES and then change state to idle. Set byte ready flag to 1

                rx_counter <= rx_counter + 1;
                if (rx_counter == DELAY_FRAMES) begin
                    rx_state <= RX_IDLE;
                    rx_counter <= 1;
                    byte_ready <= 1;
                    o_data_byte <= input_shift_register;
                end            
            end

            RX_HOLD_BYTE_EN: begin
                if (rx_counter == 5) begin
                    
                    rx_counter <= 1;
                    rx_state <= RX_IDLE;
                end
                else rx_counter <= rx_counter + 1;
            end

        endcase
    end

    // Carry the output of the shift register to the LEDs and to the output
    always @(posedge clk) begin

        if (byte_ready)
        begin
            led <= ~input_shift_register[5:0];    
            
        end
              
    end


    // Program the transmitter
    reg[2:0] tx_state = 0;              // State of the machine in tx mode
    reg[24:0]tx_counter = 0;            // Counts clock cycles in tx mode
    reg tx_pin = 0;                     // Will be assigned to the tx output pin
    reg [7:0] output_register = 8'd0;     // Contains the byte to be transmitted
    reg [2:0] tx_bit_number = 3'd0;         // Counts the number of bits transmitted of the current byte
    reg [7:0] tx_byte_counter = 8'd0;       // Counts of the byte number of the memory thats being transmitted


    assign uart_tx = tx_pin;
    localparam MEMORY_LENGTH = 12;
    reg[7:0] testMemory[MEMORY_LENGTH-1: 0];       // Creates a memory store of length 12 where each element is 8 bits wide

    // Initialize the memory
    initial begin
    testMemory[0] = "L";
    testMemory[1] = "u";
    testMemory[2] = "s";
    testMemory[3] = "h";
    testMemory[4] = "a";
    testMemory[5] = "y";
    testMemory[6] = " ";
    testMemory[7] = "L";
    testMemory[8] = "a";
    testMemory[9] = "b";
    testMemory[10] = "s";
    testMemory[11] = "\n";
end

// Define tx states
localparam TX_IDLE = 0;
localparam TX_START_BIT = 1;
localparam TX_WRITE = 2;
localparam TX_STOP_BIT = 3;
localparam TX_DEBOUNCE = 4;


always @(posedge clk) begin

    case (tx_state)
    TX_IDLE: begin          // When idle, keep tx_pin high unless a button press is detected

        if (btn == 0) begin //button is active low
            tx_state <= TX_START_BIT;
            tx_counter <= 0;
            tx_bit_number <= 0;
            tx_byte_counter <= 0;
        end
        else tx_pin <= 1;     
    end

    TX_START_BIT:begin  // When in this state, pull the tx pin to 0 and wait for DELAY_FRAMES and then switch states to write

        tx_pin <= 0;
        if (tx_counter + 1 == DELAY_FRAMES) begin
            tx_state <= TX_WRITE;
            tx_counter <= 0;
            output_register <= testMemory[tx_byte_counter];
            tx_bit_number <= 0;           
        end
        else tx_counter <= tx_counter + 1;     
    end

    TX_WRITE:begin // in write state, iterate over all the bits of the output register and send it to tx_pin. After setting a bit. wait for DELAY_FRAMES

        tx_pin <= output_register[tx_bit_number];

        if (tx_counter + 1 == DELAY_FRAMES)begin

            if (tx_bit_number == 3'b111)begin
              
              tx_state <= TX_STOP_BIT;
            end
            else begin
              tx_bit_number <= tx_bit_number + 1;
              tx_state <= TX_WRITE;
            end
            tx_counter <= 0;
        end
        else tx_counter <= tx_counter + 1;
      
    end

    TX_STOP_BIT:begin  // At this stage,set tx_pin to high, wait for DELAY_FRAMES and then reset the state to either debounce or start,depending on whether there are more bytes to read

        tx_pin <= 1;
        if (tx_counter + 1 == DELAY_FRAMES)begin

            if (tx_byte_counter == MEMORY_LENGTH - 1)begin
              
              tx_state <= TX_DEBOUNCE;             
            end
            else begin
              tx_byte_counter <= tx_byte_counter + 1;
              tx_state <= TX_START_BIT;
            end
            tx_counter <= 0;
        end
        else tx_counter <= tx_counter + 1;
    end


    TX_DEBOUNCE: begin // Wait for 10ms (thats 262144 clock pulses) and then IF button is not pressed, set state to IDLE

        if (tx_counter == 23'd262144)begin

            if (btn == 1)begin
                tx_state <= TX_IDLE;
                tx_counter <= 0;
              
            end
        end
        else tx_counter <= tx_counter + 1;
      
    end
endcase
    
end




    
endmodule