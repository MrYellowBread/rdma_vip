//============================================================================
// RDMA VIP - Write Test
// Tests RDMA WRITE operations
//============================================================================

`ifndef RDMA_WRITE_TEST_SV
`define RDMA_WRITE_TEST_SV

class rdma_write_test extends rdma_base_test;
    `uvm_component_utils(rdma_write_test)
    
    // Test sequence
    rdma_write_sequence write_seq;
    
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
        
        // Configure for WRITE test
        cfg.default_pmtu = 1024;
        cfg.enable_psn_check = 1;
        cfg.enable_mem_protection = 1;
        cfg.cov_enable = 1;
    endfunction
    
    //----------------------------------------------------------------------------
    // Run Phase
    //----------------------------------------------------------------------------
    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this, "RDMA Write Test");
        
        `uvm_info("WRITE_TEST", "Starting WRITE test", UVM_MEDIUM)
        
        // Create and configure sequence
        write_seq = rdma_write_sequence::type_id::create("write_seq");
        write_seq.num_transactions = 20;
        write_seq.write_length = 512;
        write_seq.remote_addr = 64'h10000;
        write_seq.r_key = 32'h12345678;
        
        // Start sequence
        write_seq.start(env.req_tx_agt.sequencer);
        
        // Wait for completion
        #5000ns;
        
        `uvm_info("WRITE_TEST", "WRITE test completed", UVM_MEDIUM)
        
        phase.drop_objection(this, "RDMA Write Test");
    endtask
    
endclass

`endif // RDMA_WRITE_TEST_SV
