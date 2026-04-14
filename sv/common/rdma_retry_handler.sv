//============================================================================
// RDMA VIP - Retry Handler
// Manages retransmission for reliable connection service
//============================================================================

`ifndef RDMA_RETRY_HANDLER_SV
`define RDMA_RETRY_HANDLER_SV

class rdma_retry_handler extends uvm_component;
    `uvm_component_utils(rdma_retry_handler)
    
    // Configuration
    rdma_vip_cfg cfg;
    
    // Retry queue per QP - stores transactions waiting for retry
    rdma_transaction retry_queue[int][$];
    
    // Timer management - tracks time until retry for each QP
    int retry_timers[int];
    
    // Retry count tracking
    int retry_counts[int];
    
    // Pending ACK tracking
    bit [23:0] pending_psn[int];
    
    // Events
    uvm_event retry_triggered_e;
    
    // Statistics
    int total_retries;
    int total_timeouts;
    int max_retry_exceeded;
    
    //----------------------------------------------------------------------------
    // Constructor
    //----------------------------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
        total_retries = 0;
        total_timeouts = 0;
        max_retry_exceeded = 0;
    endfunction
    
    //----------------------------------------------------------------------------
    // Build Phase
    //----------------------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(rdma_vip_cfg)::get(this, "", "cfg", cfg)) begin
            cfg = new();
        end
        retry_triggered_e = new("retry_triggered_e");
    endfunction
    
    //----------------------------------------------------------------------------
    // Run Phase - Monitor timers and trigger retries
    //----------------------------------------------------------------------------
    task run_phase(uvm_phase phase);
        forever begin
            // Check all timers
            foreach (retry_timers[qp_num]) begin
                if (retry_timers[qp_num] > 0) begin
                    retry_timers[qp_num]--;
                end else if (retry_queue[qp_num].size() > 0) begin
                    // Timer expired and there are pending retries
                    if (!retry_limit_exceeded(qp_num)) begin
                        trigger_retry(qp_num);
                    end else begin
                        handle_max_retry_exceeded(qp_num);
                    end
                end
            end
            @(posedge cfg.clk);
        end
    endtask
    
    //----------------------------------------------------------------------------
    // Add transaction to retry queue
    //----------------------------------------------------------------------------
    function void add_to_retry_queue(rdma_transaction txn, int qp_num);
        `uvm_info("RETRY_HDL", $sformatf("Adding transaction to retry queue for QP=%0d", qp_num), UVM_MEDIUM)
        
        retry_queue[qp_num].push_back(txn);
        
        if (!retry_timers.exists(qp_num)) begin
            retry_timers[qp_num] = cfg.req_tx_cfg.retry_timeout_cycles;
        end
        
        if (!retry_counts.exists(qp_num)) begin
            retry_counts[qp_num] = 0;
        end
        
        // Track pending PSN
        pending_psn[qp_num] = txn.start_psn;
    endfunction
    
    //----------------------------------------------------------------------------
    // Trigger retry for a QP
    //----------------------------------------------------------------------------
    task trigger_retry(int qp_num);
        rdma_transaction txn;
        
        if (retry_queue[qp_num].size() == 0) return;
        
        // Get transaction from queue
        txn = retry_queue[qp_num][0];  // Peek first, don't remove yet
        
        // Mark for retry
        txn.mark_retry();
        retry_counts[qp_num]++;
        total_retries++;
        
        `uvm_info("RETRY_HDL", $sformatf("Retry %0d/%0d for QP=%0d: %s", 
                  retry_counts[qp_num], cfg.req_tx_cfg.max_retries, qp_num, 
                  txn.convert2string()), UVM_MEDIUM)
        
        // Trigger retry event
        retry_triggered_e.trigger();
        retry_triggered_e.reset();
        
        // Reset timer for next potential retry
        retry_timers[qp_num] = cfg.req_tx_cfg.retry_timeout_cycles * (1 + retry_counts[qp_num]);
    endtask
    
    //----------------------------------------------------------------------------
    // Handle successful ACK - remove from retry queue
    //----------------------------------------------------------------------------
    function void handle_ack(int qp_num, bit [23:0] ack_psn);
        int i;
        
        if (!retry_queue.exists(qp_num)) return;
        
        // Remove all transactions with PSN <= ack_psn
        for (i = retry_queue[qp_num].size() - 1; i >= 0; i--) begin
            if (is_psn_less_or_equal(retry_queue[qp_num][i].start_psn, ack_psn)) begin
                `uvm_info("RETRY_HDL", $sformatf("Removing ACKed transaction PSN=%0d from retry queue", 
                          retry_queue[qp_num][i].start_psn), UVM_HIGH)
                retry_queue[qp_num].delete(i);
            end
        end
        
        // Reset retry count if all cleared
        if (retry_queue[qp_num].size() == 0) begin
            retry_counts[qp_num] = 0;
            retry_timers.delete(qp_num);
        end
    endfunction
    
    //----------------------------------------------------------------------------
    // Check if retry limit exceeded
    //----------------------------------------------------------------------------
    function bit retry_limit_exceeded(int qp_num);
        if (!retry_counts.exists(qp_num)) return 0;
        return (retry_counts[qp_num] >= cfg.req_tx_cfg.max_retries);
    endfunction
    
    //----------------------------------------------------------------------------
    // Handle max retry exceeded
    //----------------------------------------------------------------------------
    function void handle_max_retry_exceeded(int qp_num);
        rdma_transaction txn;
        
        `uvm_error("RETRY_HDL", $sformatf("Max retry count (%0d) exceeded for QP=%0d", 
                   cfg.req_tx_cfg.max_retries, qp_num))
        
        max_retry_exceeded++;
        total_timeouts++;
        
        // Mark all pending transactions as failed
        while (retry_queue[qp_num].size() > 0) begin
            txn = retry_queue[qp_num].pop_front();
            txn.mark_timeout();
        end
        
        retry_counts[qp_num] = 0;
        retry_timers.delete(qp_num);
    endfunction
    
    //----------------------------------------------------------------------------
    // PSN comparison helper (handles wrap-around)
    //----------------------------------------------------------------------------
    function bit is_psn_less_or_equal(bit [23:0] psn_a, bit [23:0] psn_b);
        bit [23:0] diff;
        diff = psn_b - psn_a;
        return (diff < 24'h800000) || (psn_a == psn_b);
    endfunction
    
    //----------------------------------------------------------------------------
    // Clear retry queue for a QP
    //----------------------------------------------------------------------------
    function void clear_qp(int qp_num);
        retry_queue.delete(qp_num);
        retry_timers.delete(qp_num);
        retry_counts.delete(qp_num);
        pending_psn.delete(qp_num);
    endfunction
    
    //----------------------------------------------------------------------------
    // Report Phase
    //----------------------------------------------------------------------------
    function void report_phase(uvm_phase phase);
        `uvm_info("RETRY_REPORT", $sformatf("Retry Statistics: Total=%0d Timeouts=%0d MaxRetryExceeded=%0d",
                  total_retries, total_timeouts, max_retry_exceeded), UVM_LOW)
    endfunction
    
endclass

`endif // RDMA_RETRY_HANDLER_SV
