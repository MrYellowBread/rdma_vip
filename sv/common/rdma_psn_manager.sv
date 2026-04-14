//============================================================================
// RDMA VIP - PSN Manager
// Packet Sequence Number management for reliable transmission
//============================================================================

`ifndef RDMA_PSN_MANAGER_SV
`define RDMA_PSN_MANAGER_SV

class rdma_psn_manager extends uvm_component;
    `uvm_component_utils(rdma_psn_manager)
    
    // Configuration
    rdma_vip_cfg cfg;
    
    // PSN tracking per QP
    typedef struct {
        bit [23:0] expected_psn;
        bit [23:0] next_psn;
        bit [23:0] last_acked_psn;
        bit [23:0] retry_psn_start;
        int retry_count;
        bit in_retry;
    } psn_state_t;
    
    psn_state_t psn_table[int];  // Indexed by QP number
    
    // Statistics
    int packets_received;
    int packets_duplicate;
    int packets_out_of_order;
    int retransmissions;
    
    //----------------------------------------------------------------------------
    // Constructor
    //----------------------------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
        packets_received = 0;
        packets_duplicate = 0;
        packets_out_of_order = 0;
        retransmissions = 0;
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
    // Initialize PSN for a QP
    //----------------------------------------------------------------------------
    function void init_qp(int qp_num, bit [23:0] start_psn);
        psn_state_t psn_state;
        psn_state.expected_psn = start_psn;
        psn_state.next_psn = start_psn;
        psn_state.last_acked_psn = start_psn;
        psn_state.retry_psn_start = start_psn;
        psn_state.retry_count = 0;
        psn_state.in_retry = 0;
        psn_table[qp_num] = psn_state;
        `uvm_info("PSN_MGR", $sformatf("Initialized QP=%0d with PSN=%0d", qp_num, start_psn), UVM_MEDIUM)
    endfunction
    
    //----------------------------------------------------------------------------
    // Check PSN validity
    // Returns 1 if PSN is valid (expected), 0 if out-of-order or duplicate
    //----------------------------------------------------------------------------
    function bit check_psn(bit [23:0] psn, rdma_qp_context qp_ctx);
        int qp_num = qp_ctx.qp_num;
        bit [23:0] expected;
        bit [23:0] psn_diff;
        bit result;
        
        if (!psn_table.exists(qp_num)) begin
            init_qp(qp_num, qp_ctx.rq_psn);
        end
        
        expected = psn_table[qp_num].expected_psn;
        
        if (psn == expected) begin
            // Expected PSN - normal case
            result = 1;
        end else if (is_psn_less(psn, expected)) begin
            // Duplicate packet (PSN < expected)
            result = 0;
            packets_duplicate++;
            `uvm_info("PSN_MGR", $sformatf("Duplicate packet: PSN=%0d < expected=%0d", psn, expected), UVM_MEDIUM)
        end else begin
            // Out-of-order (PSN > expected) - indicates packet loss
            result = 0;
            packets_out_of_order++;
            `uvm_warning("PSN_MGR", $sformatf("Out-of-order packet: PSN=%0d > expected=%0d", psn, expected))
        end
        
        return result;
    endfunction
    
    //----------------------------------------------------------------------------
    // Advance PSN after successful packet processing
    //----------------------------------------------------------------------------
    function void advance_psn(rdma_qp_context qp_ctx);
        int qp_num = qp_ctx.qp_num;
        
        if (!psn_table.exists(qp_num)) begin
            init_qp(qp_num, qp_ctx.rq_psn);
        end
        
        psn_table[qp_num].expected_psn = (psn_table[qp_num].expected_psn + 1) & `RDMA_PSN_MASK;
        packets_received++;
    endfunction
    
    //----------------------------------------------------------------------------
    // Get next PSN for sending
    //----------------------------------------------------------------------------
    function bit [23:0] get_next_psn(int qp_num);
        bit [23:0] psn;
        
        if (!psn_table.exists(qp_num)) begin
            init_qp(qp_num, 0);
        end
        
        psn = psn_table[qp_num].next_psn;
        psn_table[qp_num].next_psn = (psn_table[qp_num].next_psn + 1) & `RDMA_PSN_MASK;
        return psn;
    endfunction
    
    //----------------------------------------------------------------------------
    // Start retry sequence (Go-back-N)
    //----------------------------------------------------------------------------
    function void start_retry(int qp_num);
        if (!psn_table.exists(qp_num)) return;
        
        psn_table[qp_num].in_retry = 1;
        psn_table[qp_num].retry_psn_start = psn_table[qp_num].last_acked_psn;
        psn_table[qp_num].retry_count++;
        psn_table[qp_num].next_psn = psn_table[qp_num].last_acked_psn;
        retransmissions++;
        
        `uvm_info("PSN_MGR", $sformatf("Started retry for QP=%0d from PSN=%0d (retry_count=%0d)", 
                  qp_num, psn_table[qp_num].last_acked_psn, psn_table[qp_num].retry_count), UVM_MEDIUM)
    endfunction
    
    //----------------------------------------------------------------------------
    // Update last ACKed PSN
    //----------------------------------------------------------------------------
    function void update_ack(int qp_num, bit [23:0] ack_psn);
        if (!psn_table.exists(qp_num)) return;
        
        if (is_psn_less(psn_table[qp_num].last_acked_psn, ack_psn)) begin
            psn_table[qp_num].last_acked_psn = ack_psn;
            psn_table[qp_num].in_retry = 0;
            `uvm_info("PSN_MGR", $sformatf("QP=%0d ACKed up to PSN=%0d", qp_num, ack_psn), UVM_HIGH)
        end
    endfunction
    
    //----------------------------------------------------------------------------
    // Check if retry limit exceeded
    //----------------------------------------------------------------------------
    function bit retry_limit_exceeded(int qp_num, int max_retries);
        if (!psn_table.exists(qp_num)) return 0;
        return (psn_table[qp_num].retry_count > max_retries);
    endfunction
    
    //----------------------------------------------------------------------------
    // PSN comparison (handles wrap-around)
    // Returns true if psn_a < psn_b considering 24-bit wrap-around
    //----------------------------------------------------------------------------
    function bit is_psn_less(bit [23:0] psn_a, bit [23:0] psn_b);
        bit [23:0] diff;
        diff = psn_b - psn_a;
        // If diff is small positive, psn_a < psn_b
        // If diff is large (close to max), psn_a > psn_b (wrap-around case)
        return (diff < 24'h800000);
    endfunction
    
    //----------------------------------------------------------------------------
    // Report Phase
    //----------------------------------------------------------------------------
    function void report_phase(uvm_phase phase);
        `uvm_info("PSN_MGR_REPORT", $sformatf("PSN Statistics: Received=%0d Duplicates=%0d Out-of-order=%0d Retransmissions=%0d",
                  packets_received, packets_duplicate, packets_out_of_order, retransmissions), UVM_LOW)
    endfunction
    
endclass

`endif // RDMA_PSN_MANAGER_SV
