//============================================================================
// RDMA VIP - Write Sequence
// Sequence for RDMA WRITE operations
//============================================================================

`ifndef RDMA_WRITE_SEQUENCE_SV
`define RDMA_WRITE_SEQUENCE_SV

class rdma_write_sequence extends rdma_base_sequence;
    `uvm_object_utils(rdma_write_sequence)
    
    // Transaction parameters
    rand bit [63:0] remote_addr;
    rand bit [31:0] r_key;
    rand int write_length;
    rand bit use_imm;
    
    //----------------------------------------------------------------------------
    // Constraints
    //----------------------------------------------------------------------------
    constraint valid_write_params_c {
        write_length > 0;
        write_length <= 4096;
        remote_addr != 0;
        r_key != 0;
    }
    
    //----------------------------------------------------------------------------
    // Constructor
    //----------------------------------------------------------------------------
    function new(string name = "rdma_write_sequence");
        super.new(name);
    endfunction
    
    //----------------------------------------------------------------------------
    // Body
    //----------------------------------------------------------------------------
    virtual task body();
        rdma_transaction txn;
        rdma_opcode_t opcode;
        int i;
        
        `uvm_info("WRITE_SEQ", $sformatf("Starting WRITE sequence: num=%0d length=%0d", 
                  num_transactions, write_length), UVM_MEDIUM)
        
        for (i = 0; i < num_transactions; i++) begin
            // Determine opcode based on length
            if (write_length <= cfg.default_pmtu) begin
                opcode = use_imm ? RC_RDMA_WRITE_ONLY_WITH_IMM : RC_RDMA_WRITE_ONLY;
            end else begin
                opcode = RC_RDMA_WRITE_FIRST;
            end
            
            txn = rdma_transaction::type_id::create($sformatf("write_txn_%0d", i));
            
            assert(txn.randomize() with {
                opcode == local::opcode;
                local_qpn == qp_ctx.qp_num;
                remote_qpn == qp_ctx.dest_qp_num;
                remote_vaddr == local::remote_addr;
                r_key == local::r_key;
                length == local::write_length;
                if (use_imm) immediate_data != 0;
            });
            
            start_item(txn);
            finish_item(txn);
            
            `uvm_info("WRITE_SEQ", $sformatf("Sent WRITE transaction %0d/%0d: %s", 
                      i+1, num_transactions, txn.convert2string()), UVM_MEDIUM)
        end
        
        `uvm_info("WRITE_SEQ", "WRITE sequence completed", UVM_MEDIUM)
    endtask
    
endclass

`endif // RDMA_WRITE_SEQUENCE_SV
