//============================================================================
// RDMA VIP - Completion Queue Entry (CQE)
// Represents completion status for WQEs
//============================================================================

`ifndef RDMA_CQE_SV
`define RDMA_CQE_SV

class rdma_cqe extends uvm_sequence_item;
    `uvm_object_utils(rdma_cqe)
    
    // CQE Fields
    rand wc_status_e      status;           // Completion status
    rand rdma_opcode_t    opcode;           // Operation code
    rand int              qp_num;           // Queue Pair number
    rand int              wr_id;            // Work Request ID from WQE
    rand int unsigned     byte_len;         // Bytes transferred
    rand bit [31:0]       immediate_data;   // Immediate data (if applicable)
    rand bit [31:0]       error_syndrome;   // Error details
    
    // Source identification
    rand int              src_qp;           // Source QP (for UD)
    rand bit [31:0]       src_lid;          // Source LID
    
    // Timing
    time                  completion_time;
    
    //----------------------------------------------------------------------------
    // Constraints
    //----------------------------------------------------------------------------
    constraint valid_byte_len_c {
        byte_len <= `RDMA_MAX_DMA_LEN;
    }
    
    //----------------------------------------------------------------------------
    // Constructor
    //----------------------------------------------------------------------------
    function new(string name = "rdma_cqe");
        super.new(name);
        completion_time = $time;
    endfunction
    
    //----------------------------------------------------------------------------
    // Create CQE from transaction
    //----------------------------------------------------------------------------
    static function rdma_cqe create_from_transaction(rdma_transaction txn);
        rdma_cqe cqe = new();
        cqe.opcode = txn.opcode;
        cqe.qp_num = txn.local_qpn;
        cqe.wr_id = 0;  // Would be set from WQE
        cqe.byte_len = txn.length;
        cqe.immediate_data = txn.immediate_data;
        
        if (txn.error) begin
            cqe.status = wc_status_e'(txn.completion_status);
        end else begin
            cqe.status = WC_SUCCESS;
        end
        
        return cqe;
    endfunction
    
    //----------------------------------------------------------------------------
    // UVM Methods
    //----------------------------------------------------------------------------
    virtual function void do_copy(uvm_object rhs);
        rdma_cqe rhs_;
        if (!$cast(rhs_, rhs)) begin
            `uvm_error("do_copy", "Cast failed")
            return;
        end
        super.do_copy(rhs);
        status = rhs_.status;
        opcode = rhs_.opcode;
        qp_num = rhs_.qp_num;
        wr_id = rhs_.wr_id;
        byte_len = rhs_.byte_len;
        immediate_data = rhs_.immediate_data;
        error_syndrome = rhs_.error_syndrome;
        src_qp = rhs_.src_qp;
        src_lid = rhs_.src_lid;
    endfunction
    
    virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        rdma_cqe rhs_;
        bit result;
        if (!$cast(rhs_, rhs)) return 0;
        result = super.do_compare(rhs, comparer) &&
                 (status == rhs_.status) &&
                 (opcode == rhs_.opcode) &&
                 (qp_num == rhs_.qp_num) &&
                 (wr_id == rhs_.wr_id) &&
                 (byte_len == rhs_.byte_len);
        return result;
    endfunction
    
    virtual function string convert2string();
        string s;
        s = $sformatf("CQE: Status=%s Opcode=%s QP=%0d WR_ID=%0d Len=%0d",
                      status.name(), opcode.name(), qp_num, wr_id, byte_len);
        if (status != WC_SUCCESS) begin
            s = {s, $sformatf(" Error=0x%08X", error_syndrome)};
        end
        return s;
    endfunction
    
    virtual function void do_print(uvm_printer printer);
        printer.m_string = convert2string();
    endfunction
    
endclass

`endif // RDMA_CQE_SV
