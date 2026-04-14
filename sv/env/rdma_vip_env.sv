//============================================================================
// RDMA VIP - Top-Level Environment
// Integrates all agents and verification components
//============================================================================

`ifndef RDMA_VIP_ENV_SV
`define RDMA_VIP_ENV_SV

class rdma_vip_env extends uvm_env;
    `uvm_component_utils(rdma_vip_env)
    
    // Centralized configuration object
    rdma_vip_cfg    cfg;
    
    // Core functional agents
    rdma_requester_tx_agent   req_tx_agt;
    rdma_responder_rx_agent   resp_rx_agt;
    rdma_requester_rx_agent   req_rx_agt;
    
    // Verification components
    rdma_scoreboard      scb;
    rdma_cov_model       cov_model;
    
    // TLM ports for cross-agent communication
    uvm_tlm_analysis_port #(rdma_transaction) global_trans_ap;
    
    //----------------------------------------------------------------------------
    // Constructor
    //----------------------------------------------------------------------------
    function new(string name = "rdma_vip_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    
    //----------------------------------------------------------------------------
    // Build Phase
    //----------------------------------------------------------------------------
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // 1. Get or create configuration object
        if (!uvm_config_db#(rdma_vip_cfg)::get(this, "", "cfg", cfg)) begin
            `uvm_info("CFG", "Creating default configuration", UVM_LOW)
            cfg = rdma_vip_cfg::type_id::create("cfg");
            void'(cfg.randomize());
        end
        `uvm_info("CFG", cfg.sprint(), UVM_LOW)
        
        // 2. Set child component configurations
        uvm_config_db#(rdma_vip_cfg)::set(this, "req_tx_agt", "cfg", cfg);
        uvm_config_db#(rdma_vip_cfg)::set(this, "resp_rx_agt", "cfg", cfg);
        uvm_config_db#(rdma_vip_cfg)::set(this, "req_rx_agt", "cfg", cfg);
        
        // 3. Create agents
        req_tx_agt = rdma_requester_tx_agent::type_id::create("req_tx_agt", this);
        resp_rx_agt = rdma_responder_rx_agent::type_id::create("resp_rx_agt", this);
        req_rx_agt = rdma_requester_rx_agent::type_id::create("req_rx_agt", this);
        
        // 4. Create verification components
        scb = rdma_scoreboard::type_id::create("scb", this);
        if (cfg.cov_enable) begin
            cov_model = rdma_cov_model::type_id::create("cov_model", this);
        end
        
        // 5. Create global analysis port
        global_trans_ap = new("global_trans_ap", this);
    endfunction
    
    //----------------------------------------------------------------------------
    // Connect Phase
    //----------------------------------------------------------------------------
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        
        // Connect agent monitors to scoreboard and coverage
        req_tx_agt.monitor.trans_ap.connect(scb.expected_trans_export);
        resp_rx_agt.monitor.trans_ap.connect(scb.actual_trans_export);
        req_rx_agt.monitor.trans_ap.connect(scb.actual_trans_export);
        
        // Connect CQE outputs to scoreboard
        if (req_rx_agt.cqe_ap != null) begin
            req_rx_agt.cqe_ap.connect(scb.cqe_export);
        end
        if (resp_rx_agt.cqe_ap != null) begin
            resp_rx_agt.cqe_ap.connect(scb.cqe_export);
        end
        
        // Connect coverage model
        if (cfg.cov_enable && cov_model != null) begin
            global_trans_ap.connect(cov_model.trans_export);
            req_tx_agt.monitor.trans_ap.connect(cov_model.trans_export);
        end
        
        `uvm_info("CONNECT", "RDMA VIP Environment connected", UVM_HIGH)
    endfunction
    
    //----------------------------------------------------------------------------
    // Report Phase
    //----------------------------------------------------------------------------
    virtual function void report_phase(uvm_phase phase);
        `uvm_info("REPORT", $sformatf("RDMA VIP Environment Report:\n%s", cfg.sprint()), UVM_LOW)
    endfunction
    
endclass

`endif // RDMA_VIP_ENV_SV
