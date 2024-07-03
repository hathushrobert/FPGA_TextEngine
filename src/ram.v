module RAM #(

    // Parameters
    parameter   INIT_FILE = "imMage.hex"
) (

    // Inputs
    input               clk,
    input               w_en,
    input               r_en,
    input       [13:0]   w_addr,
    input       [13:0]   r_addr,
    input       [7:0]   w_data,
    
    // Outputs
    output  reg [7:0]   r_data
);

    // Declare memory
    reg [7:0]  mem [0:1024];
/*
    integer i;

   initial begin

    for (i =0; i < 1024; i = i + 1 ) begin
      
      mem[i] <= 2**(i%8) - 1;
      
        end

    end
*/
    
    // Interact with the memory block
    always @ (posedge clk) begin
    
        // Write to memory
        if (w_en == 1'b1) begin
            mem[w_addr] <= w_data;
        end
        
        // Read from memory
        if (r_en == 1'b1) begin
            r_data <= mem[r_addr];
        end
    end
    
    // Initialization (if available)
    initial if (INIT_FILE) begin
        $readmemh(INIT_FILE, mem);
    end
    
endmodule