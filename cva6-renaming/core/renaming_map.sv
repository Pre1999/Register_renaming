// Renaming map module
// While you are free to structure your implementation however you
// like, you are advised to only add code to the TODO sections
module renaming_map import ariane_pkg::*; #(
    parameter int unsigned ARCH_REG_WIDTH = 5,
    parameter int unsigned PHYS_REG_WIDTH = 6
)(
    // Clock and reset signals
    input logic clk_i,
    input logic rst_ni,

    // Indicator that there is a new instruction to rename
    input logic fetch_entry_ready_i,

    // Input decoded instruction entry from the ID stage
    input issue_struct_t issue_n,

    // Output instruction entry with registers renamed
    output issue_struct_t issue_q,

    // Destination register of the committing instruction
    input logic [PHYS_REG_WIDTH-1:0] waddr_i,
    
    // Indicator signal that there is a new committing instruction
    input logic we_gp_i
);

    // 32 architectural registers and 64 physical registers
    localparam ARCH_NUM_REGS = 2**ARCH_REG_WIDTH;
    localparam PHYS_NUM_REGS = 2**PHYS_REG_WIDTH;

    logic [PHYS_REG_WIDTH-1:0] rs1 =6'b0;
    logic [PHYS_REG_WIDTH-1:0] rs2 = 6'b0;
    logic [PHYS_REG_WIDTH-1:0] rd = 6'b0;
    logic [PHYS_REG_WIDTH-1:0] phys_reg_to_dealloc; //temp variable
    // TODO: ADD STRUCTURES TO EXECUTE REGISTER RENAMING
    localparam FREE_LIST_SIZE=2**PHYS_REG_WIDTH;
    logic [FREE_LIST_SIZE-1:0] free_list;

    logic [PHYS_REG_WIDTH-1:0] rename_map [0:2**ARCH_REG_WIDTH-1];

    logic [PHYS_REG_WIDTH-1:0] dealloc [0:2**ARCH_REG_WIDTH-1];

    // [LOCAL] Signals internal to the rename module
    logic [PHYS_REG_WIDTH-1:0] prd = 6'b0;

    // Positive clock edge used for renaming new instructions
    always @(posedge clk_i, negedge rst_ni) begin
        // Processor reset: revert renaming state to reset conditions    
        if (~rst_ni) begin

            // TODO: ADD LOGIC TO RESET RENAMING STATE
            rename_map <= '{default: '0};
            free_list <= 64'hffff_ffff_ffff_fffe;
            dealloc <= '{default: '0};

    
        // New incoming valid instruction to rename   
        end else if (fetch_entry_ready_i && issue_n.valid) begin
            // Get values of registers in new instruction
            rs1 = issue_n.sbe.rs1[PHYS_REG_WIDTH-1:0];
            rs2 = issue_n.sbe.rs2[PHYS_REG_WIDTH-1:0];
            rd = issue_n.sbe.rd[PHYS_REG_WIDTH-1:0];

            // Set outgoing instruction to incoming instruction without
            // renaming by default. Keep this line since all fields of the 
            // incoming issue_struct_t should carry over to the output
            // except for the register values, which you may rename below
            issue_q = issue_n;

            // TODO: ADD LOGIC TO RENAME OUTGOING INSTRUCTION
            //rs1: if not in alloc  map: leave as 0
            rs1 = rename_map[rs1];
            rs2 = rename_map[rs2];

            prd = 6'b0;
            if (rd != 0) begin
                for(int i=63; i >= 0; i--) begin
                    if(free_list[i] == 1'b1) prd = i;
                end
                free_list[prd] = 1'b0;
                
                //first time we see an DEST_ARCH_REG, we will not dealloc
                //it maps to PHYS_REG 0, the second time, we see a DEST_ARCH_REG
                //we will mark for dealloc the PHYS_REG it maps to, because the new PHYS_REG
                //holds the most up to date value
                if (rename_map[rd] != 0) begin
                    //we mark the previous arch->phys for deallocation when the current prd commits
                    dealloc[prd] = rename_map[rd];
                end
                rename_map[rd] = prd;
                
            end


            // The registers of the outgoing instruction issue_q can be set like so:
            issue_q.sbe.rs1[PHYS_REG_WIDTH-1:0] = rs1;
            issue_q.sbe.rs2[PHYS_REG_WIDTH-1:0] = rs2;
            issue_q.sbe.rd[PHYS_REG_WIDTH-1:0] = prd;
    
        // If there is no new instruction this clock cycle, simply pass on the
        // incoming instruction without renaming
        end else begin
            issue_q = issue_n;
        end
    end
    

    // Negative clock edge used for physical register deallocation 
    always @(negedge clk_i) begin
        if (rst_ni) begin
            $display("clean value of waddr_i: %b", waddr_i);
            // If there is a new committing instruction and its prd is not pr0,
            // execute register deallocation logic to reuse physical registers
            if (we_gp_i && waddr_i != 0 && dealloc[waddr_i] != 0) begin
        
                // TODO: IMPLEMENT REGISTER DEALLOCATION LOGIC
                phys_reg_to_dealloc = dealloc[waddr_i];
                free_list[phys_reg_to_dealloc] = 1'b1;
            end
        end
    end
endmodule
