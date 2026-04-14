//============================================================================
// RDMA VIP - Read Test
// Tests RDMA READ operations
//============================================================================

`ifndef RDMA_READ_TEST_SV
`define RDMA_READ_TEST_SV

class rdma_read_test extends rdma_base_test;
    `uvm_component_utils(rdma_read_test)
    
    // Test sequence
    rdma_read_sequence read_seq;
    
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
        
        // Configure for READ test
        cfg.default_pmtu = 1024;
        cfg.enable_psn_check = 1;
        cfg.enable_mem_protection = 1;
        cfg.cov_enable = 1;
    endfunction
    
    //----------------------------------------------------------------------------
    // Run Phase
    //----------------------------------------------------------------------------
    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this, "RDMA Read Test");
        
        `uvm_info("READ_TEST", "Starting READ test", UVM_MEDIUM)
        
        // Create and configure sequence
        read_seq = rdma_read_sequence::type_id::create("read_seq");
        read_seq.num_transactions = 20;
        read_seq.read_length = 512;
        read_seq.remote_addr = 64'h10000;
        read_seq.r_key = 32'h12345678;
        
        // Start sequence
        read_seq.start(env.req_tx_agt.sequencer);
        
        // Wait for completion
        #5000ns;
        
        `uvm_info("READ_TEST", "READ test completed", UVM_MEDIUM)
        
        phase.drop_objection(this, "RDMA Read Test");
    endtask
    
endclass

`endif // RDMA_READ_TEST_SV
