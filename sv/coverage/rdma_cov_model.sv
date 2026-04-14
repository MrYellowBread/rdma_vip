//============================================================================
// RDMA VIP - Coverage Model
// Functional coverage collection for RDMA operations
//============================================================================

`ifndef RDMA_COV_MODEL_SV
`define RDMA_COV_MODEL_SV

class rdma_cov_model extends uvm_component;
    `uvm_component_utils(rdma_cov_model)
    
    // Configuration
    rdma_vip_cfg cfg;
    
    // Analysis port
    uvm_analysis_export #(rdma_transaction) trans_export;
    uvm_tlm_analysis_fifo #(rdma_transaction) trans_fifo;
    
    // Coverage groups
    covergroup rdma_opcode_cg;
        option.name = "rdma_opcode_coverage";
        option.per_instance = 0;
        
        opcode: coverpoint cov_opcode {
            bins send_ops[] = {RC_SEND_FIRST, RC_SEND_MIDDLE, RC_SEND_LAST, 
                               RC_SEND_LAST_WITH_IMM, RC_SEND_ONLY, RC_SEND_ONLY_WITH_IMM};
            bins write_ops[] = {RC_RDMA_WRITE_FIRST, RC_RDMA_WRITE_MIDDLE, RC_RDMA_WRITE_LAST,
                                RC_RDMA_WRITE_LAST_WITH_IMM, RC_RDMA_WRITE_ONLY, RC_RDMA_WRITE_ONLY_WITH_IMM};
            bins read_ops[] = {RC_RDMA_READ_REQUEST, RC_RDMA_READ_RESPONSE_FIRST,
                               RC_RDMA_READ_RESPONSE_MIDDLE, RC_RDMA_READ_RESPONSE_LAST, RC_RDMA_READ_RESPONSE_ONLY};
            bins atomic_ops[] = {RC_ATOMIC_CMP_SWP, RC_ATOMIC_FETCH_ADD,
                                 RC_ATOMIC_CMP_SWP_RESPONSE, RC_ATOMIC_FETCH_ADD_RESPONSE};
            bins ack_ops[] = {RC_ACK, RC_NAK};
            bins others[] = default;
        }
    endgroup
    
    covergroup rdma_length_cg;
        option.name = "rdma_length_coverage";
        option.per_instance = 0;
        
        length: coverpoint cov_length {
            bins small[] = {[1:64]};
            bins medium[] = {[65:1024]};
            bins large[] = {[1025:4096]};
            bins very_large[] = {[4097:65536]};
            bins extreme[] = {[65537:$]};
        }
        
        length_x_opcode: cross length, cov_opcode;
    endgroup
    
    covergroup rdma_transaction_state_cg;
        option.name = "rdma_transaction_state_coverage";
        option.per_instance = 0;
        
        state: coverpoint cov_state {
            bins all_states[] = {TRAN_PENDING, TRAN_REQ_SENT, TRAN_RESP_RECV, 
                                 TRAN_COMPLETED, TRAN_ERROR, TRAN_TIMEOUT, TRAN_RETRY};
        }
    endgroup
    
    covergroup rdma_qp_state_cg;
        option.name = "rdma_qp_state_coverage";
        option.per_instance = 0;
        
        qp_state: coverpoint cov_qp_state {
            bins all_states[] = {QP_STATE_RESET, QP_STATE_INIT, QP_STATE_RTR, 
                                 QP_STATE_RTS, QP_STATE_SQERR, QP_STATE_ERR, QP_STATE_SQD};
            bins reset_to_rts = (QP_STATE_RESET => QP_STATE_INIT => QP_STATE_RTR => QP_STATE_RTS);
            bins error_recovery = (QP_STATE_ERR => QP_STATE_RESET);
        }
    endgroup
    
    covergroup rdma_cqe_status_cg;
        option.name = "rdma_cqe_status_coverage";
        option.per_instance = 0;
        
        status: coverpoint cov_cqe_status {
            bins success = {WC_SUCCESS};
            bins local_errors[] = {WC_LOC_LEN_ERR, WC_LOC_QP_OP_ERR, WC_LOC_PROT_ERR, WC_LOC_ACCESS_ERR};
            bins remote_errors[] = {WC_REM_ACCESS_ERR, WC_REM_OP_ERR, WC_REM_INV_REQ_ERR};
            bins retry_errors[] = {WC_RETRY_EXC_ERR, WC_RNR_RETRY_EXC_ERR};
            bins timeout = {WC_RESP_TIMEOUT_ERR};
            bins others[] = default;
        }
    endgroup
    
    covergroup rdma_psn_behavior_cg;
        option.name = "rdma_psn_behavior_coverage";
        option.per_instance = 0;
        
        psn_jump: coverpoint cov_psn_diff {
            bins in_order = {0};  // Expected PSN
            bins duplicate = {[1:128]};  // PSN < expected (duplicate)
            bins small_gap = {[129:512]};  // Small loss
            bins large_gap = {[513:$]};  // Large loss
        }
    endgroup
    
    // Coverage variables
    rdma_opcode_t cov_opcode;
    int cov_length;
    trans_state_e cov_state;
    qp_state_e cov_qp_state;
    wc_status_e cov_cqe_status;
    int cov_psn_diff;
    
    // Statistics
    int samples_collected;
    
    //----------------------------------------------------------------------------
    // Constructor
    //----------------------------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
        samples_collected = 0;
        
        // Create coverage groups
        rdma_opcode_cg = new();
        rdma_length_cg = new();
        rdma_transaction_state_cg = new();
        rdma_qp_state_cg = new();
        rdma_cqe_status_cg = new();
        rdma_psn_behavior_cg = new();
    endfunction
    
    //----------------------------------------------------------------------------
    // Build Phase
    //----------------------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        if (!uvm_config_db#(rdma_vip_cfg)::get(this, "", "cfg", cfg)) begin
            cfg = new();
        end
        
        trans_export = new("trans_export", this);
        trans_fifo = new("trans_fifo", this);
    endfunction
    
    //----------------------------------------------------------------------------
    // Connect Phase
    //----------------------------------------------------------------------------
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        trans_export.connect(trans_fifo.analysis_export);
    endfunction
    
    //----------------------------------------------------------------------------
    // Run Phase
    //----------------------------------------------------------------------------
    task run_phase(uvm_phase phase);
        rdma_transaction txn;
        
        forever begin
            trans_fifo.get(txn);
            sample_transaction(txn);
        end
    endtask
    
    //----------------------------------------------------------------------------
    // Sample transaction for coverage
    //----------------------------------------------------------------------------
    function void sample_transaction(rdma_transaction txn);
        // Sample opcode
        cov_opcode = txn.opcode;
        rdma_opcode_cg.sample();
        
        // Sample length
        cov_length = txn.length;
        rdma_length_cg.sample();
        
        // Sample state
        cov_state = txn.state;
        rdma_transaction_state_cg.sample();
        
        samples_collected++;
        
        `uvm_info("COV_MODEL", $sformatf("Sampled transaction: %s (total samples=%0d)",
                  txn.convert2string(), samples_collected), UVM_HIGH)
    endfunction
    
    //----------------------------------------------------------------------------
    // Sample QP state transition
    //----------------------------------------------------------------------------
    function void sample_qp_state(qp_state_e state);
        cov_qp_state = state;
        rdma_qp_state_cg.sample();
    endfunction
    
    //----------------------------------------------------------------------------
    // Sample CQE status
    //----------------------------------------------------------------------------
    function void sample_cqe_status(wc_status_e status);
        cov_cqe_status = status;
        rdma_cqe_status_cg.sample();
    endfunction
    
    //----------------------------------------------------------------------------
    // Sample PSN behavior
    //----------------------------------------------------------------------------
    function void sample_psn(int psn_diff);
        cov_psn_diff = psn_diff;
        rdma_psn_behavior_cg.sample();
    endfunction
    
    //----------------------------------------------------------------------------
    // Report Phase
    //----------------------------------------------------------------------------
    function void report_phase(uvm_phase phase);
        `uvm_info("COV_MODEL_REPORT", $sformatf("Coverage Report:"), UVM_LOW)
        `uvm_info("COV_MODEL_REPORT", $sformatf("  Total Samples: %0d", samples_collected), UVM_LOW)
        `uvm_info("COV_MODEL_REPORT", $sformatf("  Opcode Coverage: %0.2f%%", rdma_opcode_cg.get_coverage()), UVM_LOW)
        `uvm_info("COV_MODEL_REPORT", $sformatf("  Length Coverage: %0.2f%%", rdma_length_cg.get_coverage()), UVM_LOW)
        `uvm_info("COV_MODEL_REPORT", $sformatf("  Transaction State Coverage: %0.2f%%", rdma_transaction_state_cg.get_coverage()), UVM_LOW)
        `uvm_info("COV_MODEL_REPORT", $sformatf("  QP State Coverage: %0.2f%%", rdma_qp_state_cg.get_coverage()), UVM_LOW)
        `uvm_info("COV_MODEL_REPORT", $sformatf("  CQE Status Coverage: %0.2f%%", rdma_cqe_status_cg.get_coverage()), UVM_LOW)
        `uvm_info("COV_MODEL_REPORT", $sformatf("  PSN Behavior Coverage: %0.2f%%", rdma_psn_behavior_cg.get_coverage()), UVM_LOW)
        `uvm_info("COV_MODEL_REPORT", $sformatf("  Total Coverage: %0.2f%%", get_total_coverage()), UVM_LOW)
    endfunction
    
    //----------------------------------------------------------------------------
    // Get total coverage
    //----------------------------------------------------------------------------
    function real get_total_coverage();
        real total;
        total = (rdma_opcode_cg.get_coverage() + 
                 rdma_length_cg.get_coverage() +
                 rdma_transaction_state_cg.get_coverage() +
                 rdma_qp_state_cg.get_coverage() +
                 rdma_cqe_status_cg.get_coverage() +
                 rdma_psn_behavior_cg.get_coverage()) / 6.0;
        return total;
    endfunction
    
endclass

`endif // RDMA_COV_MODEL_SV
