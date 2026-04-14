//============================================================================
// RDMA VIP - Requester RX Agent
// Handles RDMA responses and DMA writes to local memory
//============================================================================

`ifndef RDMA_REQUESTER_RX_AGENT_SV
`define RDMA_REQUESTER_RX_AGENT_SV

class rdma_requester_rx_agent extends uvm_agent;
    `uvm_component_utils(rdma_requester_rx_agent)
    
    // TLM ports
    uvm_analysis_export #(rdma_packet) pkt_export;
    uvm_analysis_port #(rdma_cqe) cqe_ap;
    uvm_analysis_port #(rdma_transaction) trans_ap;
    
    // Sub-components
    rdma_requester_rx_driver    driver;
    rdma_requester_rx_monitor   monitor;
    
    // Configuration
    rdma_vip_cfg cfg;
    
    // Core functional models
    rdma_psn_manager psn_mgr;
    rdma_mr_lookup mr_lookup;
    rdma_dma_write_engine dma_engine;
    rdma_cqe_generator cqe_gen;
    
    // QP context
    rdma_qp_context qp_ctx;
    
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
        
        if (!uvm_config_db#(rdma_vip_cfg)::get(this, "", "cfg", cfg)) begin
            cfg = new();
        end
        
        // Create ports
        pkt_export = new("pkt_export", this);
        cqe_ap = new("cqe_ap", this);
        trans_ap = new("trans_ap", this);
        
        // Create sub-components
        monitor = rdma_requester_rx_monitor::type_id::create("monitor", this);
        
        if (cfg.is_active) begin
            driver = rdma_requester_rx_driver::type_id::create("driver", this);
        end
        
        // Create functional models
        psn_mgr = rdma_psn_manager::type_id::create("psn_mgr", this);
        mr_lookup = rdma_mr_lookup::type_id::create("mr_lookup", this);
        dma_engine = rdma_dma_write_engine::type_id::create("dma_engine", this);
        cqe_gen = rdma_cqe_generator::type_id::create("cqe_gen", this);
        
        // Create default QP context
        qp_ctx = new("qp_ctx");
        qp_ctx.randomize() with {
            state == QP_STATE_RTS;
            qp_type == QP_TYPE_RC;
        };
    endfunction
    
    //----------------------------------------------------------------------------
    // Connect Phase
    //----------------------------------------------------------------------------
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        
        // Connect functional models
        if (driver != null) begin
            driver.pkt_export.connect(pkt_export);
            driver.psn_mgr = psn_mgr;
            driver.mr_lookup = mr_lookup;
            driver.dma_engine = dma_engine;
            driver.cqe_gen = cqe_gen;
            driver.qp_ctx = qp_ctx;
        end
        
        // CQE output
        cqe_gen.cqe_ap.connect(cqe_ap);
        
        // Monitor output
        monitor.trans_ap.connect(trans_ap);
    endfunction
    
endclass

//----------------------------------------------------------------------------
// Requester RX Driver - Core processing logic
//----------------------------------------------------------------------------

class rdma_requester_rx_driver extends uvm_driver #(rdma_packet);
    `uvm_component_utils(rdma_requester_rx_driver)
    
    uvm_analysis_export #(rdma_packet) pkt_export;
    uvm_analysis_imp #(rdma_packet, rdma_requester_rx_driver) pkt_imp;
    
    // References to functional models (set by agent)
    rdma_psn_manager psn_mgr;
    rdma_mr_lookup mr_lookup;
    rdma_dma_write_engine dma_engine;
    rdma_cqe_generator cqe_gen;
    rdma_qp_context qp_ctx;
    
    rdma_vip_cfg cfg;
    
    // Internal queue for pending responses
    rdma_packet pending_pkts[$];
    
    //----------------------------------------------------------------------------
    // Constructor
    //----------------------------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
        pkt_export = new("pkt_export", this);
        pkt_imp = new("pkt_imp", this);
    endfunction
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(rdma_vip_cfg)::get(this, "", "cfg", cfg)) begin
            cfg = new();
        end
    endfunction
    
    //----------------------------------------------------------------------------
    // Write method - called when packet arrives
    //----------------------------------------------------------------------------
    virtual function void write(rdma_packet pkt);
        `uvm_info("DRIVER", $sformatf("Received packet: %s", pkt.convert2string()), UVM_MEDIUM)
        pending_pkts.push_back(pkt);
    endfunction
    
    //----------------------------------------------------------------------------
    // Run Phase - Process packets
    //----------------------------------------------------------------------------
    task run_phase(uvm_phase phase);
        rdma_packet pkt;
        rdma_transaction txn;
        bit psn_ok;
        bit mr_valid;
        bit [63:0] pa;
        bit write_ok;
        bit is_last;
        
        forever begin
            // Wait for packets
            while (pending_pkts.size() == 0) begin
                @(posedge cfg.clk);
            end
            
            pkt = pending_pkts.pop_front();
            
            // Stage 1: Check QP state
            if (qp_ctx.state != QP_STATE_RTS) begin
                `uvm_warning("DRIVER", $sformatf("QP not in RTS state: %s", qp_ctx.state.name()))
                continue;
            end
            
            // Stage 2: PSN check
            if (cfg.enable_psn_check) begin
                psn_ok = psn_mgr.check_psn(pkt.psn, qp_ctx);
                if (!psn_ok) begin
                    if (pkt.psn < qp_ctx.rq_psn) begin
                        `uvm_info("DRIVER", $sformatf("Duplicate packet PSN=%0d, discarding", pkt.psn), UVM_MEDIUM)
                        continue;
                    end else begin
                        `uvm_warning("DRIVER", $sformatf("Out-of-order packet PSN=%0d expected=%0d", 
                                    pkt.psn, qp_ctx.rq_psn))
                        // Handle retransmission
                        continue;
                    end
                end
            end
            
            // Stage 3: For Read Response - MR lookup and permission check
            if (pkt.is_read_response()) begin
                mr_valid = mr_lookup.validate(pkt.r_key, pkt.virtual_addr, pkt.length, 
                                              qp_ctx.mr_l_key, qp_ctx.mr_base_addr, qp_ctx.mr_length);
                if (!mr_valid) begin
                    `uvm_error("DRIVER", "Memory validation failed")
                    cqe_gen.generate_error_cqe(pkt, WC_LOC_ACCESS_ERR);
                    continue;
                end
                
                // Calculate physical address
                pa = mr_lookup.calculate_pa(pkt.virtual_addr, qp_ctx.mr_base_addr);
                
                // Stage 4: DMA write
                write_ok = dma_engine.write(pa, pkt.payload);
                if (!write_ok) begin
                    `uvm_error("DRIVER", "DMA write failed")
                    cqe_gen.generate_error_cqe(pkt, WC_LOC_LEN_ERR);
                    continue;
                end
                
                // Check if this is the last response
                is_last = pkt.is_last_packet();
                if (is_last) begin
                    // Stage 5: Generate CQE
                    cqe_gen.generate_success_cqe(pkt, qp_ctx);
                end
            end
            
            // Update PSN
            psn_mgr.advance_psn(qp_ctx);
            
            `uvm_info("DRIVER", "Packet processed successfully", UVM_HIGH)
        end
    endtask
endclass

//----------------------------------------------------------------------------
// Requester RX Monitor
//----------------------------------------------------------------------------

class rdma_requester_rx_monitor extends uvm_monitor;
    `uvm_component_utils(rdma_requester_rx_monitor)
    
    uvm_analysis_port #(rdma_transaction) trans_ap;
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
        trans_ap = new("trans_ap", this);
    endfunction
    
    task run_phase(uvm_phase phase);
        `uvm_info("MONITOR", "Requester RX Monitor started", UVM_MEDIUM)
    endtask
endclass

`endif // RDMA_REQUESTER_RX_AGENT_SV
