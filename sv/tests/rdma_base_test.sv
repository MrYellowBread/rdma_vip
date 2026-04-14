//============================================================================
// RDMA VIP - Base Test
// Base class for all RDMA tests
//============================================================================

`ifndef RDMA_BASE_TEST_SV
`define RDMA_BASE_TEST_SV

class rdma_base_test extends uvm_test;
    `uvm_component_utils(rdma_base_test)
    
    // Environment
    rdma_vip_env env;
    
    // Configuration
    rdma_vip_cfg cfg;
    
    // Virtual sequencer
    uvm_sequencer #(rdma_transaction) v_seqr;
    
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
        
        // Create or get configuration
        if (!uvm_config_db#(rdma_vip_cfg)::get(this, "", "cfg", cfg)) begin
            `uvm_info("TEST", "Creating default configuration", UVM_MEDIUM)
            cfg = rdma_vip_cfg::type_id::create("cfg");
            void'(cfg.randomize());
        end
        
        // Set configuration for environment
        uvm_config_db#(rdma_vip_cfg)::set(this, "env", "cfg", cfg);
        
        // Create environment
        env = rdma_vip_env::type_id::create("env", this);
        
        // Create virtual sequencer
        v_seqr = new("v_seqr", this);
    endfunction
    
    //----------------------------------------------------------------------------
    // Connect Phase
    //----------------------------------------------------------------------------
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        
        // Connect virtual sequencer to agent sequencers
        // (This would be done in a real implementation)
    endfunction
    
    //----------------------------------------------------------------------------
    // End of Elaboration Phase
    //----------------------------------------------------------------------------
    virtual function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        `uvm_info("TEST", "Testbench structure:", UVM_LOW)
        uvm_top.print_topology();
    endfunction
    
    //----------------------------------------------------------------------------
    // Report Phase
    //----------------------------------------------------------------------------
    virtual function void report_phase(uvm_phase phase);
        uvm_report_server server;
        int errors;
        int warnings;
        
        server = uvm_report_server::get_server();
        errors = server.get_severity_count(UVM_ERROR);
        warnings = server.get_severity_count(UVM_WARNING);
        
        `uvm_info("TEST_REPORT", $sformatf("Test Results: Errors=%0d Warnings=%0d", 
                  errors, warnings), UVM_LOW)
        
        if (errors == 0) begin
            `uvm_info("TEST_REPORT", "TEST PASSED", UVM_LOW)
        end else begin
            `uvm_error("TEST_REPORT", $sformatf("TEST FAILED: %0d errors", errors))
        end
    endfunction
    
endclass

`endif // RDMA_BASE_TEST_SV
