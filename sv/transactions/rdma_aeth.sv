//============================================================================
// RDMA VIP - Acknowledge Extended Transport Header (AETH)
// For ACK/NAK and completion status
//============================================================================

`ifndef RDMA_AETH_SV
`define RDMA_AETH_SV

class rdma_aeth extends uvm_sequence_item;
    `uvm_object_utils(rdma_aeth)
    
    // AETH Fields
    rand bit [7:0] syndrome;        // Contains ACK/NAK code
    rand bit [23:0] msn;            // Message Sequence Number
    
    // Derived fields
    bit is_ack;
    bit is_nak;
    bit [4:0] syndrome_code;
    
    //----------------------------------------------------------------------------
    // Constraints
    //----------------------------------------------------------------------------
    constraint valid_syndrome_c {
        syndrome inside {[0:255]};
    }
    
    //----------------------------------------------------------------------------
    // Constructor
    //----------------------------------------------------------------------------
    function new(string name = "rdma_aeth");
        super.new(name);
    endfunction
    
    //----------------------------------------------------------------------------
    // Post-randomize to derive fields
    //----------------------------------------------------------------------------
    function void post_randomize();
        syndrome_code = syndrome[7:3];
        is_ack = (syndrome_code == AETH_ACK);
        is_nak = !is_ack;
    endfunction
    
    //----------------------------------------------------------------------------
    // Check if this is a successful ACK
    //----------------------------------------------------------------------------
    function bit is_success();
        return is_ack;
    endfunction
    
    //----------------------------------------------------------------------------
    // Get status code
    //----------------------------------------------------------------------------
    function aeth_syndrome_e get_status();
        return aeth_syndrome_e'(syndrome_code);
    endfunction
    
    //----------------------------------------------------------------------------
    // UVM Methods
    //----------------------------------------------------------------------------
    virtual function void do_copy(uvm_object rhs);
        rdma_aeth rhs_;
        if (!$cast(rhs_, rhs)) begin
            `uvm_error("do_copy", "Cast failed")
            return;
        end
        super.do_copy(rhs);
        syndrome = rhs_.syndrome;
        msn = rhs_.msn;
        is_ack = rhs_.is_ack;
        is_nak = rhs_.is_nak;
        syndrome_code = rhs_.syndrome_code;
    endfunction
    
    virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        rdma_aeth rhs_;
        bit result;
        if (!$cast(rhs_, rhs)) return 0;
        result = super.do_compare(rhs, comparer) &&
                 (syndrome == rhs_.syndrome) &&
                 (msn == rhs_.msn);
        return result;
    endfunction
    
    virtual function string convert2string();
        string s;
        string status_str;
        
        case (syndrome_code)
            AETH_ACK: status_str = "ACK";
            AETH_RNR: status_str = "RNR_NAK";
            AETH_NAK_PSNT: status_str = "NAK_PSNT";
            AETH_NAK_INVL: status_str = "NAK_INVL";
            AETH_NAK_RMT_ACC: status_str = "NAK_RMT_ACC";
            AETH_NAK_RMT_OP: status_str = "NAK_RMT_OP";
            AETH_NAK_INVL_RD: status_str = "NAK_INVL_RD";
            default: status_str = $sformatf("UNKNOWN(0x%02X)", syndrome_code);
        endcase
        
        s = $sformatf("AETH: Syndrome=0x%02X(%s) MSN=0x%06X",
                      syndrome, status_str, msn);
        return s;
    endfunction
    
    virtual function void do_print(uvm_printer printer);
        printer.m_string = convert2string();
    endfunction
    
endclass

`endif // RDMA_AETH_SV
