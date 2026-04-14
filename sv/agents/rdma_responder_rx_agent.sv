//============================================================================
// RDMA VIP - Responder RX Agent
// Receives RDMA requests and generates responses
//============================================================================

`ifndef RDMA_RESPONDER_RX_AGENT_SV
`define RDMA_RESPONDER_RX_AGENT_SV

class rdma_responder_rx_agent extends uvm_agent;
    `uvm_component_utils(rdma_responder_rx_agent)
    
    // TLM ports
    uvm_analysis_export #(rdma_packet) pkt_export;
    uvm_analysis_port #(rdma_packet) rsp_pkt_ap;
    uvm_analysis_port #(rdma_cqe) cqe_ap;
    
    // Sub-components
    rdma_responder_rx_driver  driver;
    rdma_responder_rx_monitor monitor;
    
    // Configuration
    rdma_vip_cfg cfg;
    
    //----------------------------------------------------------------------------
    // Constructor
    //----------------------------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        if (!uvm_config_db#(rdma_vip_cfg)::get(this, "", "cfg", cfg)) begin
            cfg = new();
        end
        
        pkt_export = new("pkt_export", this);
        rsp_pkt_ap = new("rsp_pkt_ap", this);
        cqe_ap = new("cqe_ap", this);
        
        monitor = rdma_responder_rx_monitor::type_id::create("monitor", this);
        
        if (cfg.is_active) begin
            driver = rdma_responder_rx_driver::type_id::create("driver", this);
        end
    endfunction
    
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (driver != null) begin
            driver.pkt_export.connect(pkt_export);
            driver.rsp_pkt_ap.connect(rsp_pkt_ap);
        end
    endfunction
    
endclass

class rdma_responder_rx_driver extends uvm_driver #(rdma_packet);
    `uvm_component_utils(rdma_responder_rx_driver)
    
    uvm_analysis_export #(rdma_packet) pkt_export;
    uvm_analysis_imp #(rdma_packet, rdma_responder_rx_driver) pkt_imp;
    uvm_analysis_port #(rdma_packet) rsp_pkt_ap;
    
    rdma_vip_cfg cfg;
    rdma_packet pending_pkts[$];
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
        pkt_export = new("pkt_export", this);
        pkt_imp = new("pkt_imp", this);
        rsp_pkt_ap = new("rsp_pkt_ap", this);
    endfunction
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(rdma_vip_cfg)::get(this, "", "cfg", cfg)) begin
            cfg = new();
        end
    endfunction
    
    virtual function void write(rdma_packet pkt);
        pending_pkts.push_back(pkt);
    endfunction
    
    task run_phase(uvm_phase phase);
        rdma_packet pkt, rsp_pkt;
        
        forever begin
            while (pending_pkts.size() == 0) begin
                #1ns;
            end
            
            pkt = pending_pkts.pop_front();
            `uvm_info("RESPONDER", $sformatf("Processing request: %s", pkt.convert2string()), UVM_MEDIUM)
            
            // Process based on opcode
            case (pkt.opcode)
                RC_RDMA_READ_REQUEST: begin
                    // Generate Read Response
                    rsp_pkt = create_read_response(pkt);
                    rsp_pkt_ap.write(rsp_pkt);
                end
                RC_RDMA_WRITE_ONLY, RC_RDMA_WRITE_FIRST: begin
                    // Process write - generate ACK
                    rsp_pkt = create_ack_packet(pkt);
                    if (cfg.resp_rx_cfg.generate_ack) begin
                        rsp_pkt_ap.write(rsp_pkt);
                    end
                end
                RC_SEND_ONLY: begin
                    // Process send - generate ACK for RC
                    rsp_pkt = create_ack_packet(pkt);
                    rsp_pkt_ap.write(rsp_pkt);
                end
                default: begin
                    `uvm_warning("RESPONDER", $sformatf("Unhandled opcode: %s", pkt.opcode.name()))
                end
            endcase
        end
    endtask
    
    function rdma_packet create_read_response(rdma_packet req_pkt);
        rdma_packet rsp = new();
        rsp.opcode = RC_RDMA_READ_RESPONSE_ONLY;
        rsp.psn = req_pkt.psn;
        rsp.qp_num = req_pkt.dest_qp_num;
        rsp.dest_qp_num = req_pkt.qp_num;
        rsp.length = req_pkt.length;
        rsp.virtual_addr = req_pkt.virtual_addr;
        rsp.r_key = req_pkt.r_key;
        rsp.payload = new[req_pkt.length];
        foreach (rsp.payload[i]) begin
            rsp.payload[i] = $urandom_range(0, 255);
        end
        return rsp;
    endfunction
    
    function rdma_packet create_ack_packet(rdma_packet req_pkt);
        rdma_packet rsp = new();
        rsp.opcode = RC_ACK;
        rsp.psn = req_pkt.psn;
        rsp.qp_num = req_pkt.dest_qp_num;
        rsp.dest_qp_num = req_pkt.qp_num;
        rsp.syndrome = 8'h00;  // ACK success
        return rsp;
    endfunction
endclass

class rdma_responder_rx_monitor extends uvm_monitor;
    `uvm_component_utils(rdma_responder_rx_monitor)
    
    uvm_analysis_port #(rdma_transaction) trans_ap;
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
        trans_ap = new("trans_ap", this);
    endfunction
    
    task run_phase(uvm_phase phase);
        `uvm_info("MONITOR", "Responder RX Monitor started", UVM_MEDIUM)
    endtask
endclass

`endif // RDMA_RESPONDER_RX_AGENT_SV
