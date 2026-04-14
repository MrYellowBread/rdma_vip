//============================================================================
// RDMA VIP - Requester TX Agent
// Handles RDMA request generation and transmission
//============================================================================

`ifndef RDMA_REQUESTER_TX_AGENT_SV
`define RDMA_REQUESTER_TX_AGENT_SV

class rdma_requester_tx_agent extends uvm_agent;
    `uvm_component_utils(rdma_requester_tx_agent)
    
    // TLM ports
    uvm_analysis_port #(rdma_transaction) trans_ap;
    uvm_analysis_port #(rdma_packet) pkt_ap;
    
    // Sub-components
    rdma_requester_tx_driver    driver;
    rdma_requester_tx_sequencer sequencer;
    rdma_requester_tx_monitor   monitor;
    
    // Configuration
    rdma_vip_cfg cfg;
    
    // PSN manager for this agent
    rdma_psn_manager psn_mgr;
    
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
        
        // Get configuration
        if (!uvm_config_db#(rdma_vip_cfg)::get(this, "", "cfg", cfg)) begin
            `uvm_warning("CFG", "Configuration not found, using default")
            cfg = new();
        end
        
        // Create ports
        trans_ap = new("trans_ap", this);
        pkt_ap = new("pkt_ap", this);
        
        // Create sub-components
        monitor = rdma_requester_tx_monitor::type_id::create("monitor", this);
        
        if (cfg.is_active) begin
            driver = rdma_requester_tx_driver::type_id::create("driver", this);
            sequencer = rdma_requester_tx_sequencer::type_id::create("sequencer", this);
        end
        
        // Create PSN manager
        psn_mgr = rdma_psn_manager::type_id::create("psn_mgr", this);
    endfunction
    
    //----------------------------------------------------------------------------
    // Connect Phase
    //----------------------------------------------------------------------------
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        
        if (cfg.is_active) begin
            driver.seq_item_port.connect(sequencer.seq_item_export);
            driver.pkt_ap.connect(pkt_ap);
        end
        
        monitor.trans_ap.connect(trans_ap);
    endfunction
    
endclass

//----------------------------------------------------------------------------
// Sub-component definitions
//----------------------------------------------------------------------------

class rdma_requester_tx_driver extends uvm_driver #(rdma_transaction);
    `uvm_component_utils(rdma_requester_tx_driver)
    
    uvm_analysis_port #(rdma_packet) pkt_ap;
    rdma_vip_cfg cfg;
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
        pkt_ap = new("pkt_ap", this);
    endfunction
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(rdma_vip_cfg)::get(this, "", "cfg", cfg)) begin
            cfg = new();
        end
    endfunction
    
    task run_phase(uvm_phase phase);
        rdma_transaction txn;
        rdma_packet pkt;
        
        forever begin
            seq_item_port.get_next_item(txn);
            `uvm_info("DRIVER", $sformatf("Processing transaction: %s", txn.convert2string()), UVM_MEDIUM)
            
            // Build headers
            txn.build_headers();
            
            // Convert transaction to packet(s)
            pkt = new();
            pkt.from_transaction(txn);
            
            // Send packet
            pkt_ap.write(pkt);
            `uvm_info("DRIVER", "Packet sent", UVM_HIGH)
            
            seq_item_port.item_done();
        end
    endtask
endclass

class rdma_requester_tx_sequencer extends uvm_sequencer #(rdma_transaction);
    `uvm_component_utils(rdma_requester_tx_sequencer)
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
endclass

class rdma_requester_tx_monitor extends uvm_monitor;
    `uvm_component_utils(rdma_requester_tx_monitor)
    
    uvm_analysis_port #(rdma_transaction) trans_ap;
    rdma_vip_cfg cfg;
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
        trans_ap = new("trans_ap", this);
    endfunction
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(rdma_vip_cfg)::get(this, "", "cfg", cfg)) begin
            cfg = new();
        end
    endfunction
    
    task run_phase(uvm_phase phase);
        // Monitor logic would observe actual interface signals
        // For TLM VIP, this monitors transactions passing through
        `uvm_info("MONITOR", "Requester TX Monitor started", UVM_MEDIUM)
    endtask
endclass

`endif // RDMA_REQUESTER_TX_AGENT_SV
