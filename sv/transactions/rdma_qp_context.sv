//============================================================================
// RDMA VIP - Queue Pair Context
// Contains QP state and configuration
//============================================================================

`ifndef RDMA_QP_CONTEXT_SV
`define RDMA_QP_CONTEXT_SV

class rdma_qp_context extends uvm_sequence_item;
    `uvm_object_utils(rdma_qp_context)
    
    // QP Identification
    rand int              qp_num;           // Local QP number
    rand int              dest_qp_num;      // Destination QP number
    rand bit [31:0]       dest_lid;         // Destination LID
    
    // QP State
    rand qp_state_e       state;
    rand qp_type_e        qp_type;
    
    // PSN Management
    rand bit [23:0]       sq_psn;           // Send Queue PSN (next to send)
    rand bit [23:0]       rq_psn;           // Receive Queue PSN (expected)
    rand bit [23:0]       ack_psn;          // ACK PSN
    
    // Queue Depths
    rand int              sq_depth;         // Send Queue depth
    rand int              rq_depth;         // Receive Queue depth
    rand int              cq_depth;         // Completion Queue depth
    
    // MTU and Limits
    rand int              pmtu;             // Path MTU
    rand int              rnr_retry;        // RNR retry count
    rand int              retry_cnt;        // Retry count
    
    // Memory Region info
    rand bit [63:0]       mr_base_addr;
    rand bit [63:0]       mr_length;
    rand bit [31:0]       mr_l_key;
    rand bit [31:0]       mr_r_key;
    
    //----------------------------------------------------------------------------
    // Constraints
    //----------------------------------------------------------------------------
    constraint valid_qp_c {
        qp_num >= 0 && qp_num < (1 << 24);
        dest_qp_num >= 0 && dest_qp_num < (1 << 24);
        sq_depth > 0 && sq_depth <= 65536;
        rq_depth > 0 && rq_depth <= 65536;
        pmtu inside {256, 512, 1024, 2048, 4096};
        rnr_retry >= 0 && rnr_retry <= 7;
        retry_cnt >= 0 && retry_cnt <= 7;
    }
    
    //----------------------------------------------------------------------------
    // Constructor
    //----------------------------------------------------------------------------
    function new(string name = "rdma_qp_context");
        super.new(name);
    endfunction
    
    //----------------------------------------------------------------------------
    // State transition helper
    //----------------------------------------------------------------------------
    virtual function bit transition_to(qp_state_e new_state);
        // Validate state transition
        case (state)
            QP_STATE_RESET: begin
                if (new_state == QP_STATE_INIT) begin
                    state = new_state;
                    return 1;
                end
            end
            QP_STATE_INIT: begin
                if (new_state inside {QP_STATE_RTR, QP_STATE_ERR}) begin
                    state = new_state;
                    return 1;
                end
            end
            QP_STATE_RTR: begin
                if (new_state inside {QP_STATE_RTS, QP_STATE_ERR}) begin
                    state = new_state;
                    return 1;
                end
            end
            QP_STATE_RTS: begin
                if (new_state inside {QP_STATE_SQD, QP_STATE_SQERR, QP_STATE_ERR}) begin
                    state = new_state;
                    return 1;
                end
            end
            QP_STATE_SQERR: begin
                if (new_state inside {QP_STATE_RTS, QP_STATE_ERR}) begin
                    state = new_state;
                    return 1;
                end
            end
            QP_STATE_SQD: begin
                if (new_state inside {QP_STATE_RTS, QP_STATE_ERR}) begin
                    state = new_state;
                    return 1;
                end
            end
            QP_STATE_ERR: begin
                if (new_state == QP_STATE_RESET) begin
                    state = new_state;
                    return 1;
                end
            end
        endcase
        `uvm_warning("QP_STATE", $sformatf("Invalid state transition: %s -> %s",
                     state.name(), new_state.name()))
        return 0;
    endfunction
    
    //----------------------------------------------------------------------------
    // Check if QP can send
    //----------------------------------------------------------------------------
    virtual function bit can_send();
        return (state == QP_STATE_RTS);
    endfunction
    
    //----------------------------------------------------------------------------
    // Check if QP can receive
    //----------------------------------------------------------------------------
    virtual function bit can_receive();
        return (state inside {QP_STATE_RTR, QP_STATE_RTS});
    endfunction
    
    //----------------------------------------------------------------------------
    // UVM Methods
    //----------------------------------------------------------------------------
    virtual function void do_copy(uvm_object rhs);
        rdma_qp_context rhs_;
        if (!$cast(rhs_, rhs)) begin
            `uvm_error("do_copy", "Cast failed")
            return;
        end
        super.do_copy(rhs);
        qp_num = rhs_.qp_num;
        dest_qp_num = rhs_.dest_qp_num;
        dest_lid = rhs_.dest_lid;
        state = rhs_.state;
        qp_type = rhs_.qp_type;
        sq_psn = rhs_.sq_psn;
        rq_psn = rhs_.rq_psn;
        ack_psn = rhs_.ack_psn;
        sq_depth = rhs_.sq_depth;
        rq_depth = rhs_.rq_depth;
        cq_depth = rhs_.cq_depth;
        pmtu = rhs_.pmtu;
        rnr_retry = rhs_.rnr_retry;
        retry_cnt = rhs_.retry_cnt;
        mr_base_addr = rhs_.mr_base_addr;
        mr_length = rhs_.mr_length;
        mr_l_key = rhs_.mr_l_key;
        mr_r_key = rhs_.mr_r_key;
    endfunction
    
    virtual function string convert2string();
        string s;
        s = $sformatf("QP_CTX: QP=%0d DestQP=%0d State=%s Type=%s PSN(SQ/RQ)=%0d/%0d",
                      qp_num, dest_qp_num, state.name(), qp_type.name(), sq_psn, rq_psn);
        return s;
    endfunction
    
    virtual function void do_print(uvm_printer printer);
        printer.m_string = convert2string();
    endfunction
    
endclass

`endif // RDMA_QP_CONTEXT_SV
