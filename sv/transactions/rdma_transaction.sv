//============================================================================
// RDMA VIP - Core Transaction Class
// Central TLM modeling class for RDMA operations
//============================================================================

`ifndef RDMA_TRANSACTION_SV
`define RDMA_TRANSACTION_SV

class rdma_transaction extends uvm_sequence_item;
    `uvm_object_utils(rdma_transaction)
    
    // Transaction identification and type
    rand rdma_opcode_t    opcode;
    rand int              local_qpn;         // Local Queue Pair Number
    rand int              remote_qpn;        // Remote Queue Pair Number
    rand bit [23:0]       start_psn;         // Starting Packet Sequence Number
    
    // Memory access semantics (core fields)
    rand bit [63:0]       local_vaddr;       // Local virtual address (source/target)
    rand bit [63:0]       remote_vaddr;      // Remote virtual address
    rand bit [31:0]       l_key;             // Local Memory Key
    rand bit [31:0]       r_key;             // Remote Memory Key
    rand int unsigned     length;            // Total data length
    rand bit [31:0]       immediate_data;    // Optional immediate data
    rand bit              fence;             // Fence flag
    
    // Data payload
    rand byte             data_payload[];    // Actual data to transfer
    
    // Protocol header instances (dynamically used based on opcode)
    rdma_reth             reth;
    rdma_atomic_eth       atomic_eth;
    rdma_aeth             aeth;
    
    // Transaction state and lifecycle
    trans_state_e         state = TRAN_PENDING;
    bit                   completed;
    bit                   error;
    bit [31:0]            completion_status; // Maps to CQE status
    
    // Timing information
    time                  start_time;
    time                  completion_time;
    int                   retry_count;
    
    //----------------------------------------------------------------------------
    // Constraints - Ensure transaction parameters are semantically consistent
    //----------------------------------------------------------------------------
    constraint valid_semantic_c {
        // RDMA WRITE/READ operations must have valid remote address and R_Key
        (opcode inside {RC_RDMA_WRITE_FIRST, RC_RDMA_WRITE_ONLY, 
                        RC_RDMA_WRITE_FIRST, RC_RDMA_READ_REQUEST}) -> 
            (remote_vaddr != 0 && r_key != 0 && length > 0);
        
        // ATOMIC operations need AtomicETH
        (opcode inside {RC_ATOMIC_CMP_SWP, RC_ATOMIC_FETCH_ADD}) -> 
            (length == 8);  // Atomic operations are 8 bytes
        
        // SEND operations may carry immediate data but don't use RETH
        (opcode inside {RC_SEND_ONLY_WITH_IMM}) -> 
            (immediate_data != 0);
        
        // Length constraint (0 to 2^31 bytes as per IB spec)
        length <= (1 << 31);
        
        // QP numbers must be valid
        local_qpn >= 0 && local_qpn < (1 << 24);
        remote_qpn >= 0 && remote_qpn < (1 << 24);
    }
    
    constraint valid_payload_c {
        data_payload.size() == length;
    }
    
    //----------------------------------------------------------------------------
    // Constructor
    //----------------------------------------------------------------------------
    function new(string name = "rdma_transaction");
        super.new(name);
        retry_count = 0;
        start_time = $time;
    endfunction
    
    //----------------------------------------------------------------------------
    // Build headers based on transaction attributes
    //----------------------------------------------------------------------------
    virtual function void build_headers();
        case(opcode)
            RC_RDMA_WRITE_FIRST, RC_RDMA_WRITE_ONLY, 
            RC_RDMA_WRITE_MIDDLE, RC_RDMA_WRITE_LAST,
            RC_RDMA_READ_REQUEST: begin
                reth = new();
                reth.virtual_addr = this.remote_vaddr;
                reth.r_key = this.r_key;
                reth.dma_length = this.length;
            end
            
            RC_ATOMIC_CMP_SWP, RC_ATOMIC_FETCH_ADD: begin
                atomic_eth = new();
                atomic_eth.virtual_addr = this.remote_vaddr;
                atomic_eth.r_key = this.r_key;
            end
            
            default: begin
                // No special headers for SEND operations
            end
        endcase
    endfunction
    
    //----------------------------------------------------------------------------
    // Process response and update transaction state
    //----------------------------------------------------------------------------
    virtual function bit process_response(rdma_aeth resp_aeth);
        this.aeth = resp_aeth;
        if (resp_aeth.is_success()) begin
            this.state = TRAN_COMPLETED;
            this.completed = 1;
            this.error = 0;
            this.completion_status = WC_SUCCESS;
            this.completion_time = $time;
        end else begin
            this.state = TRAN_ERROR;
            this.completed = 1;
            this.error = 1;
            // Map AETH syndrome to WC status
            case (resp_aeth.get_status())
                AETH_NAK_RMT_ACC: this.completion_status = WC_REM_ACCESS_ERR;
                AETH_NAK_RMT_OP:  this.completion_status = WC_REM_OP_ERR;
                AETH_NAK_PSNT:    this.completion_status = WC_RETRY_EXC_ERR;
                AETH_RNR:         this.completion_status = WC_RNR_RETRY_EXC_ERR;
                default:          this.completion_status = WC_GENERAL_ERR;
            endcase
            this.completion_time = $time;
        end
        return this.completed;
    endfunction
    
    //----------------------------------------------------------------------------
    // Mark transaction for retry
    //----------------------------------------------------------------------------
    virtual function void mark_retry();
        state = TRAN_RETRY;
        retry_count++;
        completed = 0;
        error = 0;
    endfunction
    
    //----------------------------------------------------------------------------
    // Mark transaction as timeout
    //----------------------------------------------------------------------------
    virtual function void mark_timeout();
        state = TRAN_TIMEOUT;
        completed = 1;
        error = 1;
        completion_status = WC_RESP_TIMEOUT_ERR;
        completion_time = $time;
    endfunction
    
    //----------------------------------------------------------------------------
    // Check if transaction requires a response
    //----------------------------------------------------------------------------
    virtual function bit requires_response();
        case (opcode)
            RC_RDMA_READ_REQUEST,
            RC_ATOMIC_CMP_SWP,
            RC_ATOMIC_FETCH_ADD: return 1;
            RC_SEND_ONLY, RC_SEND_ONLY_WITH_IMM,
            RC_RDMA_WRITE_ONLY, RC_RDMA_WRITE_ONLY_WITH_IMM: return 0;  // ACK expected but not data
            default: return 0;
        endcase
    endfunction
    
    //----------------------------------------------------------------------------
    // Get operation name
    //----------------------------------------------------------------------------
    virtual function string get_opcode_name();
        case (opcode)
            RC_SEND_FIRST: return "SEND_FIRST";
            RC_SEND_MIDDLE: return "SEND_MIDDLE";
            RC_SEND_LAST: return "SEND_LAST";
            RC_SEND_ONLY: return "SEND_ONLY";
            RC_SEND_ONLY_WITH_IMM: return "SEND_ONLY_WITH_IMM";
            RC_RDMA_WRITE_FIRST: return "WRITE_FIRST";
            RC_RDMA_WRITE_MIDDLE: return "WRITE_MIDDLE";
            RC_RDMA_WRITE_LAST: return "WRITE_LAST";
            RC_RDMA_WRITE_ONLY: return "WRITE_ONLY";
            RC_RDMA_WRITE_ONLY_WITH_IMM: return "WRITE_ONLY_WITH_IMM";
            RC_RDMA_READ_REQUEST: return "READ_REQUEST";
            RC_RDMA_READ_RESPONSE_ONLY: return "READ_RESP_ONLY";
            RC_RDMA_READ_RESPONSE_FIRST: return "READ_RESP_FIRST";
            RC_ATOMIC_CMP_SWP: return "ATOMIC_CMP_SWP";
            RC_ATOMIC_FETCH_ADD: return "ATOMIC_FETCH_ADD";
            RC_ACK: return "ACK";
            RC_NAK: return "NAK";
            default: return $sformatf("UNKNOWN(0x%02X)", opcode);
        endcase
    endfunction
    
    //----------------------------------------------------------------------------
    // UVM Methods
    //----------------------------------------------------------------------------
    virtual function void do_copy(uvm_object rhs);
        rdma_transaction rhs_;
        if (!$cast(rhs_, rhs)) begin
            `uvm_error("do_copy", "Cast failed")
            return;
        end
        super.do_copy(rhs);
        
        opcode = rhs_.opcode;
        local_qpn = rhs_.local_qpn;
        remote_qpn = rhs_.remote_qpn;
        start_psn = rhs_.start_psn;
        local_vaddr = rhs_.local_vaddr;
        remote_vaddr = rhs_.remote_vaddr;
        l_key = rhs_.l_key;
        r_key = rhs_.r_key;
        length = rhs_.length;
        immediate_data = rhs_.immediate_data;
        fence = rhs_.fence;
        state = rhs_.state;
        completed = rhs_.completed;
        error = rhs_.error;
        completion_status = rhs_.completion_status;
        retry_count = rhs_.retry_count;
        
        // Copy dynamic arrays
        data_payload = new[rhs_.data_payload.size()];
        foreach (rhs_.data_payload[i]) begin
            data_payload[i] = rhs_.data_payload[i];
        end
        
        // Copy objects (shallow copy)
        if (rhs_.reth != null) reth = rhs_.reth;
        if (rhs_.atomic_eth != null) atomic_eth = rhs_.atomic_eth;
        if (rhs_.aeth != null) aeth = rhs_.aeth;
    endfunction
    
    virtual function string convert2string();
        string s;
        s = $sformatf("RDMA_TRANS: %s LQP=%0d RQP=%0d PSN=0x%06X Len=%0d State=%s",
                      get_opcode_name(), local_qpn, remote_qpn, start_psn, 
                      length, state.name());
        return s;
    endfunction
    
    virtual function void do_print(uvm_printer printer);
        printer.m_string = convert2string();
    endfunction
    
endclass

`endif // RDMA_TRANSACTION_SV
