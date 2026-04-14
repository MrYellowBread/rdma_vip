//============================================================================
// RDMA VIP - Packet Class
// Network packet representation
//============================================================================

`ifndef RDMA_PACKET_SV
`define RDMA_PACKET_SV

class rdma_packet extends uvm_sequence_item;
    `uvm_object_utils(rdma_packet)
    
    // Header fields
    rand rdma_opcode_t    opcode;
    rand bit [23:0]       psn;
    rand int              qp_num;
    rand int              dest_qp_num;
    rand bit [15:0]       pkey;
    
    // RETH fields (for WRITE/READ)
    rand bit [63:0]       virtual_addr;
    rand bit [31:0]       r_key;
    rand int              length;
    
    // AETH fields (for responses)
    rand bit [7:0]        syndrome;
    rand bit [23:0]       msn;
    
    // Payload
    rand byte             payload[];
    
    // Metadata
    bit                   is_response;
    bit                   is_last;
    
    function new(string name = "rdma_packet");
        super.new(name);
    endfunction
    
    constraint valid_payload_c {
        payload.size() == length;
    }
    
    function void from_transaction(rdma_transaction txn);
        opcode = txn.opcode;
        psn = txn.start_psn;
        qp_num = txn.local_qpn;
        dest_qp_num = txn.remote_qpn;
        length = txn.length;
        virtual_addr = txn.remote_vaddr;
        r_key = txn.r_key;
        
        if (txn.data_payload.size() > 0) begin
            payload = new[txn.data_payload.size()];
            foreach (txn.data_payload[i]) begin
                payload[i] = txn.data_payload[i];
            end
        end
    endfunction
    
    function bit is_read_response();
        return opcode inside {RC_RDMA_READ_RESPONSE_ONLY, RC_RDMA_READ_RESPONSE_FIRST,
                              RC_RDMA_READ_RESPONSE_MIDDLE, RC_RDMA_READ_RESPONSE_LAST};
    endfunction
    
    function bit is_last_packet();
        return opcode inside {RC_RDMA_READ_RESPONSE_LAST, RC_RDMA_READ_RESPONSE_ONLY,
                              RC_SEND_LAST, RC_SEND_ONLY, RC_SEND_ONLY_WITH_IMM,
                              RC_RDMA_WRITE_LAST, RC_RDMA_WRITE_ONLY, RC_RDMA_WRITE_ONLY_WITH_IMM};
    endfunction
    
    virtual function string convert2string();
        string s;
        s = $sformatf("PKT: %s PSN=%0d QP=%0d->%0d Len=%0d", 
                      opcode.name(), psn, qp_num, dest_qp_num, length);
        return s;
    endfunction
    
endclass

`endif // RDMA_PACKET_SV
