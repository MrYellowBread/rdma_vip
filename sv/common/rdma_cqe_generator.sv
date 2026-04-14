//============================================================================
// RDMA VIP - CQE Generator
// Generates Completion Queue Entries for completed operations
//============================================================================

`ifndef RDMA_CQE_GENERATOR_SV
`define RDMA_CQE_GENERATOR_SV

class rdma_cqe_generator extends uvm_component;
    `uvm_component_utils(rdma_cqe_generator)
    
    // Configuration
    rdma_vip_cfg cfg;
    
    // Output port for CQE
    uvm_analysis_port #(rdma_cqe) cqe_ap;
    
    // CQE queue (per QP for ordering)
    rdma_cqe pending_cqes[$];
    
    // Statistics
    int cqes_generated;
    int success_cqes;
    int error_cqes;
    
    // WR_ID tracking per QP (for ordering)
    int next_wr_id[int];
    
    //----------------------------------------------------------------------------
    // Constructor
    //----------------------------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
        cqe_ap = new("cqe_ap", this);
        cqes_generated = 0;
        success_cqes = 0;
        error_cqes = 0;
    endfunction
    
    //----------------------------------------------------------------------------
    // Build Phase
    //----------------------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(rdma_vip_cfg)::get(this, "", "cfg", cfg)) begin
            cfg = new();
        end
    endfunction
    
    //----------------------------------------------------------------------------
    // Register QP for CQE generation
    //----------------------------------------------------------------------------
    function void register_qp(int qp_num, int start_wr_id = 0);
        next_wr_id[qp_num] = start_wr_id;
        `uvm_info("CQE_GEN", $sformatf("Registered QP=%0d with start WR_ID=%0d", qp_num, start_wr_id), UVM_MEDIUM)
    endfunction
    
    //----------------------------------------------------------------------------
    // Generate success CQE from packet
    //----------------------------------------------------------------------------
    function void generate_success_cqe(rdma_packet pkt, rdma_qp_context qp_ctx);
        rdma_cqe cqe;
        int wr_id;
        
        if (!cfg.req_rx_cfg.generate_cqe) begin
            `uvm_info("CQE_GEN", "CQE generation disabled", UVM_HIGH)
            return;
        end
        
        cqe = new("cqe");
        cqe.status = WC_SUCCESS;
        cqe.opcode = pkt.opcode;
        cqe.qp_num = qp_ctx.qp_num;
        cqe.byte_len = pkt.length;
        cqe.src_qp = pkt.qp_num;
        cqe.completion_time = $time;
        
        // Assign WR_ID (maintains order per QP)
        if (next_wr_id.exists(qp_ctx.qp_num)) begin
            wr_id = next_wr_id[qp_ctx.qp_num];
            next_wr_id[qp_ctx.qp_num]++;
        end else begin
            wr_id = 0;
            next_wr_id[qp_ctx.qp_num] = 1;
        end
        cqe.wr_id = wr_id;
        
        // Output CQE
        cqe_ap.write(cqe);
        
        cqes_generated++;
        success_cqes++;
        
        `uvm_info("CQE_GEN", $sformatf("Generated SUCCESS CQE: %s", cqe.convert2string()), UVM_MEDIUM)
    endfunction
    
    //----------------------------------------------------------------------------
    // Generate error CQE from packet
    //----------------------------------------------------------------------------
    function void generate_error_cqe(rdma_packet pkt, wc_status_e status);
        rdma_cqe cqe;
        int wr_id;
        
        if (!cfg.req_rx_cfg.generate_cqe) begin
            `uvm_info("CQE_GEN", "CQE generation disabled", UVM_HIGH)
            return;
        end
        
        cqe = new("cqe");
        cqe.status = status;
        cqe.opcode = pkt.opcode;
        cqe.qp_num = pkt.dest_qp_num;
        cqe.byte_len = 0;  // No data transferred on error
        cqe.src_qp = pkt.qp_num;
        cqe.error_syndrome = status;  // Map status to syndrome
        cqe.completion_time = $time;
        
        // Assign WR_ID
        if (next_wr_id.exists(pkt.dest_qp_num)) begin
            wr_id = next_wr_id[pkt.dest_qp_num];
            next_wr_id[pkt.dest_qp_num]++;
        end else begin
            wr_id = 0;
            next_wr_id[pkt.dest_qp_num] = 1;
        end
        cqe.wr_id = wr_id;
        
        // Output CQE
        cqe_ap.write(cqe);
        
        cqes_generated++;
        error_cqes++;
        
        `uvm_info("CQE_GEN", $sformatf("Generated ERROR CQE: %s", cqe.convert2string()), UVM_MEDIUM)
    endfunction
    
    //----------------------------------------------------------------------------
    // Generate CQE from transaction
    //----------------------------------------------------------------------------
    function void generate_cqe_from_transaction(rdma_transaction txn);
        rdma_cqe cqe;
        
        if (!cfg.req_rx_cfg.generate_cqe) begin
            return;
        end
        
        cqe = new("cqe");
        
        if (txn.error) begin
            cqe.status = wc_status_e'(txn.completion_status);
        end else begin
            cqe.status = WC_SUCCESS;
        end
        
        cqe.opcode = txn.opcode;
        cqe.qp_num = txn.local_qpn;
        cqe.byte_len = txn.length;
        cqe.immediate_data = txn.immediate_data;
        cqe.completion_time = txn.completion_time;
        cqe.wr_id = 0;  // Would come from original WQE
        
        cqe_ap.write(cqe);
        
        cqes_generated++;
        if (cqe.status == WC_SUCCESS) begin
            success_cqes++;
        end else begin
            error_cqes++;
        end
        
        `uvm_info("CQE_GEN", $sformatf("Generated CQE from transaction: %s", cqe.convert2string()), UVM_MEDIUM)
    endfunction
    
    //----------------------------------------------------------------------------
    // Map AETH syndrome to WC status
    //----------------------------------------------------------------------------
    function wc_status_e map_syndrome_to_status(aeth_syndrome_e syndrome);
        case (syndrome)
            AETH_ACK:          return WC_SUCCESS;
            AETH_NAK_PSNT:     return WC_RETRY_EXC_ERR;
            AETH_NAK_INVL:     return WC_REM_INV_REQ_ERR;
            AETH_NAK_RMT_ACC:  return WC_REM_ACCESS_ERR;
            AETH_NAK_RMT_OP:   return WC_REM_OP_ERR;
            AETH_RNR:          return WC_RNR_RETRY_EXC_ERR;
            AETH_NAK_INVL_RD:  return WC_REM_INV_RD_REQ_ERR;
            default:           return WC_GENERAL_ERR;
        endcase
    endfunction
    
    //----------------------------------------------------------------------------
    // Flush pending CQEs for a QP (when QP goes to error state)
    //----------------------------------------------------------------------------
    function void flush_qp(int qp_num);
        int i;
        rdma_cqe cqe;
        
        `uvm_info("CQE_GEN", $sformatf("Flushing CQEs for QP=%0d", qp_num), UVM_MEDIUM)
        
        // Generate flush CQE for any pending operations
        cqe = new("cqe");
        cqe.status = WC_WR_FLUSH_ERR;
        cqe.opcode = RC_INVALID;
        cqe.qp_num = qp_num;
        cqe.byte_len = 0;
        cqe.completion_time = $time;
        
        if (next_wr_id.exists(qp_num)) begin
            cqe.wr_id = next_wr_id[qp_num];
        end else begin
            cqe.wr_id = 0;
        end
        
        cqe_ap.write(cqe);
        error_cqes++;
    endfunction
    
    //----------------------------------------------------------------------------
    // Report Phase
    //----------------------------------------------------------------------------
    function void report_phase(uvm_phase phase);
        `uvm_info("CQE_GEN_REPORT", $sformatf("CQE Statistics: Generated=%0d Success=%0d Error=%0d",
                  cqes_generated, success_cqes, error_cqes), UVM_LOW)
    endfunction
    
endclass

`endif // RDMA_CQE_GENERATOR_SV
