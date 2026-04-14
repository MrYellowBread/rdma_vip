//============================================================================
// RDMA VIP - Atomic Sequence
// Sequence for ATOMIC operations (Compare-Swap, Fetch-Add)
//============================================================================

`ifndef RDMA_ATOMIC_SEQUENCE_SV
`define RDMA_ATOMIC_SEQUENCE_SV

class rdma_atomic_sequence extends rdma_base_sequence;
    `uvm_object_utils(rdma_atomic_sequence)
    
    // Transaction parameters
    rand bit [63:0] remote_addr;
    rand bit [31:0] r_key;
    rand bit [63:0] swap_data;
    rand bit [63:0] compare_data;
    rand rdma_opcode_t atomic_opcode;
    
    //----------------------------------------------------------------------------
    // Constraints
    //----------------------------------------------------------------------------
    constraint valid_atomic_params_c {
        remote_addr != 0;
        r_key != 0;
        atomic_opcode inside {RC_ATOMIC_CMP_SWP, RC_ATOMIC_FETCH_ADD};
    }
    
    //----------------------------------------------------------------------------
    // Constructor
    //----------------------------------------------------------------------------
    function new(string name = "rdma_atomic_sequence");
        super.new(name);
    endfunction
    
    //----------------------------------------------------------------------------
    // Body
    //----------------------------------------------------------------------------
    virtual task body();
        rdma_transaction txn;
        int i;
        
        `uvm_info("ATOMIC_SEQ", $sformatf("Starting ATOMIC sequence: num=%0d opcode=%s", 
                  num_transactions, atomic_opcode.name()), UVM_MEDIUM)
        
        for (i = 0; i < num_transactions; i++) begin
            txn = rdma_transaction::type_id::create($sformatf("atomic_txn_%0d", i));
            
            assert(txn.randomize() with {
                opcode == local::atomic_opcode;
                local_qpn == qp_ctx.qp_num;
                remote_qpn == qp_ctx.dest_qp_num;
                remote_vaddr == local::remote_addr;
                r_key == local::r_key;
                length == 8;  // Atomic operations are 8 bytes
            });
            
            // Set atomic data
            if (txn.atomic_eth != null) begin
                txn.atomic_eth.swap_data = swap_data;
                txn.atomic_eth.compare_data = compare_data;
            end
            
            start_item(txn);
            finish_item(txn);
            
            `uvm_info("ATOMIC_SEQ", $sformatf("Sent ATOMIC transaction %0d/%0d: %s", 
                      i+1, num_transactions, txn.convert2string()), UVM_MEDIUM)
        end
        
        `uvm_info("ATOMIC_SEQ", "ATOMIC sequence completed", UVM_MEDIUM)
    endtask
    
endclass

`endif // RDMA_ATOMIC_SEQUENCE_SV
