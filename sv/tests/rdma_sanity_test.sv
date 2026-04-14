//============================================================================
// RDMA VIP - Sanity Test
// Basic sanity check for the VIP
//============================================================================

`ifndef RDMA_SANITY_TEST_SV
`define RDMA_SANITY_TEST_SV

class rdma_sanity_test extends rdma_base_test;
    `uvm_component_utils(rdma_sanity_test)
    
    // Test sequence
    rdma_virtual_sequence virt_seq;
    
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
        
        // Configure for sanity test
        cfg.enable_psn_check = 1;
        cfg.enable_mem_protection = 1;
        cfg.cov_enable = 1;
    endfunction
    
    //----------------------------------------------------------------------------
    // Run Phase
    //----------------------------------------------------------------------------
    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this, "RDMA Sanity Test");
        
        `uvm_info("SANITY_TEST", "Starting SANITY test", UVM_MEDIUM)
        
        // Create and configure sequence
        virt_seq = rdma_virtual_sequence::type_id::create("virt_seq");
        virt_seq.num_writes = 5;
        virt_seq.num_reads = 5;
        virt_seq.num_atomics = 2;
        
        // Start sequence
        virt_seq.start(env.req_tx_agt.sequencer);
        
        // Wait for completion
        #10000ns;
        
        `uvm_info("SANITY_TEST", "SANITY test completed", UVM_MEDIUM)
        
        phase.drop_objection(this, "RDMA Sanity Test");
    endtask
    
endclass

`endif // RDMA_SANITY_TEST_SV
