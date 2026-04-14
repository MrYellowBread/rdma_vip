//============================================================================
// RDMA VIP - Read Sequence
// Sequence for RDMA READ operations
//============================================================================

`ifndef RDMA_READ_SEQUENCE_SV
`define RDMA_READ_SEQUENCE_SV

class rdma_read_sequence extends rdma_base_sequence;
    `uvm_object_utils(rdma_read_sequence)
    
    // Transaction parameters
    rand bit [63:0] remote_addr;
    rand bit [31:0] r_key;
    rand int read_length;
    
    //----------------------------------------------------------------------------
    // Constraints
    //----------------------------------------------------------------------------
    constraint valid_read_params_c {
        read_length > 0;
        read_length <= 4096;
        remote_addr != 0;
        r_key != 0;
    }
    
    //----------------------------------------------------------------------------
    // Constructor
    //----------------------------------------------------------------------------
    function new(string name = "rdma_read_sequence");
        super.new(name);
    endfunction
    
    //----------------------------------------------------------------------------
    // Body
    //----------------------------------------------------------------------------
    virtual task body();
        rdma_transaction txn;
        int i;
        
        `uvm_info("READ_SEQ", $sformatf("Starting READ sequence: num=%0d length=%0d", 
                  num_transactions, read_length), UVM_MEDIUM)
        
        for (i = 0; i < num_transactions; i++) begin
            txn = rdma_transaction::type_id::create($sformatf("read_txn_%0d", i));
            
            assert(txn.randomize() with {
                opcode == RC_RDMA_READ_REQUEST;
                local_qpn == qp_ctx.qp_num;
                remote_qpn == qp_ctx.dest_qp_num;
                remote_vaddr == local::remote_addr;
                r_key == local::r_key;
                length == local::read_length;
            });
            
            start_item(txn);
            finish_item(txn);
            
            `uvm_info("READ_SEQ", $sformatf("Sent READ transaction %0d/%0d: %s", 
                      i+1, num_transactions, txn.convert2string()), UVM_MEDIUM)
        end
        
        `uvm_info("READ_SEQ", "READ sequence completed", UVM_MEDIUM)
    endtask
    
endclass

`endif // RDMA_READ_SEQUENCE_SV
