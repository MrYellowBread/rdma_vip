//============================================================================
// RDMA VIP - Scoreboard
// End-to-end transaction checking and verification
//============================================================================

`ifndef RDMA_SCOREBOARD_SV
`define RDMA_SCOREBOARD_SV

class rdma_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(rdma_scoreboard)
    
    // Analysis exports
    uvm_analysis_export #(rdma_transaction) expected_trans_export;
    uvm_analysis_export #(rdma_transaction) actual_trans_export;
    uvm_analysis_export #(rdma_packet) req_pkt_export;
    uvm_analysis_export #(rdma_packet) rsp_pkt_export;
    uvm_analysis_export #(rdma_cqe) cqe_export;
    
    // Analysis FIFOs
    uvm_tlm_analysis_fifo #(rdma_transaction) expected_trans_fifo;
    uvm_tlm_analysis_fifo #(rdma_transaction) actual_trans_fifo;
    uvm_tlm_analysis_fifo #(rdma_packet) req_pkt_fifo;
    uvm_tlm_analysis_fifo #(rdma_packet) rsp_pkt_fifo;
    uvm_tlm_analysis_fifo #(rdma_cqe) cqe_fifo;
    
    // Configuration
    rdma_vip_cfg cfg;
    
    // Statistics
    int transactions_checked;
    int transactions_matched;
    int transactions_mismatched;
    int packets_checked;
    int cqes_checked;
    int errors_detected;
    
    // Transaction tracking
    rdma_transaction pending_trans[int];  // Indexed by QP_num
    
    //----------------------------------------------------------------------------
    // Constructor
    //----------------------------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
        transactions_checked = 0;
        transactions_matched = 0;
        transactions_mismatched = 0;
        packets_checked = 0;
        cqes_checked = 0;
        errors_detected = 0;
    endfunction
    
    //----------------------------------------------------------------------------
    // Build Phase
    //----------------------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        if (!uvm_config_db#(rdma_vip_cfg)::get(this, "", "cfg", cfg)) begin
            cfg = new();
        end
        
        // Create exports
        expected_trans_export = new("expected_trans_export", this);
        actual_trans_export = new("actual_trans_export", this);
        req_pkt_export = new("req_pkt_export", this);
        rsp_pkt_export = new("rsp_pkt_export", this);
        cqe_export = new("cqe_export", this);
        
        // Create FIFOs
        expected_trans_fifo = new("expected_trans_fifo", this);
        actual_trans_fifo = new("actual_trans_fifo", this);
        req_pkt_fifo = new("req_pkt_fifo", this);
        rsp_pkt_fifo = new("rsp_pkt_fifo", this);
        cqe_fifo = new("cqe_fifo", this);
    endfunction
    
    //----------------------------------------------------------------------------
    // Connect Phase
    //----------------------------------------------------------------------------
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        
        // Connect exports to FIFOs
        expected_trans_export.connect(expected_trans_fifo.analysis_export);
        actual_trans_export.connect(actual_trans_fifo.analysis_export);
        req_pkt_export.connect(req_pkt_fifo.analysis_export);
        rsp_pkt_export.connect(rsp_pkt_fifo.analysis_export);
        cqe_export.connect(cqe_fifo.analysis_export);
    endfunction
    
    //----------------------------------------------------------------------------
    // Run Phase - Main checking loop
    //----------------------------------------------------------------------------
    task run_phase(uvm_phase phase);
        fork
            check_transactions();
            check_packets();
            check_cqes();
        join
    endtask
    
    //----------------------------------------------------------------------------
    // Check transactions
    //----------------------------------------------------------------------------
    task check_transactions();
        rdma_transaction expected, actual;
        
        forever begin
            expected_trans_fifo.get(expected);
            actual_trans_fifo.get(actual);
            
            transactions_checked++;
            
            `uvm_info("SCOREBOARD", $sformatf("Checking transaction %0d: %s vs %s",
                      transactions_checked, expected.get_opcode_name(), actual.get_opcode_name()), UVM_MEDIUM)
            
            if (compare_transactions(expected, actual)) begin
                transactions_matched++;
                `uvm_info("SCOREBOARD", "Transaction MATCHED", UVM_MEDIUM)
            end else begin
                transactions_mismatched++;
                errors_detected++;
                `uvm_error("SCOREBOARD", "Transaction MISMATCHED")
            end
        end
    endtask
    
    //----------------------------------------------------------------------------
    // Compare two transactions
    //----------------------------------------------------------------------------
    function bit compare_transactions(rdma_transaction expected, rdma_transaction actual);
        bit match = 1;
        
        // Check opcode
        if (expected.opcode != actual.opcode) begin
            `uvm_error("SCOREBOARD", $sformatf("Opcode mismatch: expected=%s actual=%s",
                      expected.opcode.name(), actual.opcode.name()))
            match = 0;
        end
        
        // Check QP numbers
        if (expected.local_qpn != actual.local_qpn) begin
            `uvm_error("SCOREBOARD", $sformatf("Local QPN mismatch: expected=%0d actual=%0d",
                      expected.local_qpn, actual.local_qpn))
            match = 0;
        end
        
        // Check length
        if (expected.length != actual.length) begin
            `uvm_error("SCOREBOARD", $sformatf("Length mismatch: expected=%0d actual=%0d",
                      expected.length, actual.length))
            match = 0;
        end
        
        // Check status (for completed transactions)
        if (expected.completed && actual.completed) begin
            if (expected.error != actual.error) begin
                `uvm_error("SCOREBOARD", $sformatf("Error status mismatch: expected=%0b actual=%0b",
                          expected.error, actual.error))
                match = 0;
            end
        end
        
        return match;
    endfunction
    
    //----------------------------------------------------------------------------
    // Check packets
    //----------------------------------------------------------------------------
    task check_packets();
        rdma_packet req_pkt, rsp_pkt;
        
        forever begin
            // Get request packet
            req_pkt_fifo.get(req_pkt);
            packets_checked++;
            
            `uvm_info("SCOREBOARD", $sformatf("Got request packet: %s", req_pkt.convert2string()), UVM_HIGH)
            
            // For operations that require response, wait for response
            if (requires_response(req_pkt.opcode)) begin
                rsp_pkt_fifo.get(rsp_pkt);
                
                // Verify response matches request
                if (!compare_request_response(req_pkt, rsp_pkt)) begin
                    errors_detected++;
                end
            end
        end
    endtask
    
    //----------------------------------------------------------------------------
    // Check if operation requires response
    //----------------------------------------------------------------------------
    function bit requires_response(rdma_opcode_t opcode);
        case (opcode)
            RC_RDMA_READ_REQUEST: return 1;
            RC_ATOMIC_CMP_SWP: return 1;
            RC_ATOMIC_FETCH_ADD: return 1;
            default: return 0;
        endcase
    endfunction
    
    //----------------------------------------------------------------------------
    // Compare request and response packets
    //----------------------------------------------------------------------------
    function bit compare_request_response(rdma_packet req, rdma_packet rsp);
        bit match = 1;
        
        // Check PSN matches
        if (req.psn != rsp.psn) begin
            `uvm_error("SCOREBOARD", $sformatf("Response PSN mismatch: req=%0d rsp=%0d",
                      req.psn, rsp.psn))
            match = 0;
        end
        
        // Check QP numbers are swapped correctly
        if (req.qp_num != rsp.dest_qp_num || req.dest_qp_num != rsp.qp_num) begin
            `uvm_error("SCOREBOARD", "QP number swap mismatch")
            match = 0;
        end
        
        // Check length for READ response
        if (req.opcode == RC_RDMA_READ_REQUEST) begin
            if (req.length != rsp.length) begin
                `uvm_error("SCOREBOARD", $sformatf("READ response length mismatch: req=%0d rsp=%0d",
                          req.length, rsp.length))
                match = 0;
            end
        end
        
        if (match) begin
            `uvm_info("SCOREBOARD", "Request-Response MATCHED", UVM_MEDIUM)
        end
        
        return match;
    endfunction
    
    //----------------------------------------------------------------------------
    // Check CQEs
    //----------------------------------------------------------------------------
    task check_cqes();
        rdma_cqe cqe;
        
        forever begin
            cqe_fifo.get(cqe);
            cqes_checked++;
            
            `uvm_info("SCOREBOARD", $sformatf("Got CQE: %s", cqe.convert2string()), UVM_MEDIUM)
            
            // Validate CQE fields
            if (cqe.status == WC_SUCCESS) begin
                if (cqe.byte_len > `RDMA_MAX_DMA_LEN) begin
                    `uvm_error("SCOREBOARD", $sformatf("CQE byte_len exceeds max: %0d", cqe.byte_len))
                    errors_detected++;
                end
            end else begin
                `uvm_info("SCOREBOARD", $sformatf("CQE error status: %s", cqe.status.name()), UVM_MEDIUM)
            end
        end
    endtask
    
    //----------------------------------------------------------------------------
    // Report Phase
    //----------------------------------------------------------------------------
    function void report_phase(uvm_phase phase);
        `uvm_info("SCOREBOARD_REPORT", $sformatf("Scoreboard Report:"), UVM_LOW)
        `uvm_info("SCOREBOARD_REPORT", $sformatf("  Transactions: Checked=%0d Matched=%0d Mismatched=%0d",
                  transactions_checked, transactions_matched, transactions_mismatched), UVM_LOW)
        `uvm_info("SCOREBOARD_REPORT", $sformatf("  Packets: Checked=%0d", packets_checked), UVM_LOW)
        `uvm_info("SCOREBOARD_REPORT", $sformatf("  CQEs: Checked=%0d", cqes_checked), UVM_LOW)
        `uvm_info("SCOREBOARD_REPORT", $sformatf("  Errors Detected: %0d", errors_detected), UVM_LOW)
        
        if (errors_detected == 0 && transactions_mismatched == 0) begin
            `uvm_info("SCOREBOARD_REPORT", "ALL CHECKS PASSED", UVM_LOW)
        end else begin
            `uvm_error("SCOREBOARD_REPORT", $sformatf("CHECKS FAILED: %0d errors, %0d mismatches",
                      errors_detected, transactions_mismatched))
        end
    endfunction
    
endclass

`endif // RDMA_SCOREBOARD_SV
