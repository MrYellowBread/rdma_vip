//============================================================================
// RDMA VIP - Atomic Test
// Tests ATOMIC operations
//============================================================================

`ifndef RDMA_ATOMIC_TEST_SV
`define RDMA_ATOMIC_TEST_SV

class rdma_atomic_test extends rdma_base_test;
    `uvm_component_utils(rdma_atomic_test)
    
    // Test sequence
    rdma_atomic_sequence atomic_seq;
    
    //----------------------------------------------------------------------------
    // Constructor
    //----------------------------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    
    //----------------------------------------------------------------------------
    // Build Phase
    //----------------------------------------------------------------------------
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // Configure for ATOMIC test
        cfg.enable_psn_check = 1;
        cfg.enable_mem_protection = 1;
        cfg.cov_enable = 1;
    endfunction
    
    //----------------------------------------------------------------------------
    // Run Phase
    //----------------------------------------------------------------------------
    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this, "RDMA Atomic Test");
        
        `uvm_info("ATOMIC_TEST", "Starting ATOMIC test", UVM_MEDIUM)
        
        // Create and configure sequence
        atomic_seq = rdma_atomic_sequence::type_id::create("atomic_seq");
        atomic_seq.num_transactions = 10;
        atomic_seq.atomic_opcode = RC_ATOMIC_CMP_SWP;
        atomic_seq.remote_addr = 64'h20000;
        atomic_seq.r_key = 32'h87654321;
        atomic_seq.swap_data = 64'hDEADBEEFCAFEBABE;
        atomic_seq.compare_data = 64'h0000000000000000;
        
        // Start sequence
        atomic_seq.start(env.req_tx_agt.sequencer);
        
        // Wait for completion
        #3000ns;
        
        `uvm_info("ATOMIC_TEST", "ATOMIC test completed", UVM_MEDIUM)
        
        phase.drop_objection(this, "RDMA Atomic Test");
    endtask
    
endclass

`endif // RDMA_ATOMIC_TEST_SV
