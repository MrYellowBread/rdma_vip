//============================================================================
// RDMA VIP - RDMA Extended Transport Header (RETH)
// For RDMA WRITE and READ operations
//============================================================================

`ifndef RDMA_RETH_SV
`define RDMA_RETH_SV

class rdma_reth extends uvm_sequence_item;
    `uvm_object_utils(rdma_reth)
    
    // RETH Fields
    rand bit [63:0] virtual_addr;   // Virtual Address (64-bit)
    rand bit [31:0] r_key;          // Remote Key (32-bit)
    rand bit [31:0] dma_length;     // DMA Length (32-bit)
    
    //----------------------------------------------------------------------------
    // Constraints
    //----------------------------------------------------------------------------
    constraint valid_dma_length_c {
        dma_length <= `RDMA_MAX_DMA_LEN;
    }
    
    constraint valid_r_key_c {
        r_key != 32'h0;  // R_Key must be non-zero for valid operations
    }
    
    //----------------------------------------------------------------------------
    // Constructor
    //----------------------------------------------------------------------------
    function new(string name = "rdma_reth");
        super.new(name);
    endfunction
    
    //----------------------------------------------------------------------------
    // UVM Methods
    //----------------------------------------------------------------------------
    virtual function void do_copy(uvm_object rhs);
        rdma_reth rhs_;
        if (!$cast(rhs_, rhs)) begin
            `uvm_error("do_copy", "Cast failed")
            return;
        end
        super.do_copy(rhs);
        virtual_addr = rhs_.virtual_addr;
        r_key = rhs_.r_key;
        dma_length = rhs_.dma_length;
    endfunction
    
    virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        rdma_reth rhs_;
        bit result;
        if (!$cast(rhs_, rhs)) return 0;
        result = super.do_compare(rhs, comparer) &&
                 (virtual_addr == rhs_.virtual_addr) &&
                 (r_key == rhs_.r_key) &&
                 (dma_length == rhs_.dma_length);
        return result;
    endfunction
    
    virtual function string convert2string();
        string s;
        s = $sformatf("RETH: VA=0x%016X R_Key=0x%08X Len=%0d",
                      virtual_addr, r_key, dma_length);
        return s;
    endfunction
    
    virtual function void do_print(uvm_printer printer);
        printer.m_string = convert2string();
    endfunction
    
    //----------------------------------------------------------------------------
    // Pack/Unpack for TLM
    //----------------------------------------------------------------------------
    virtual function int pack_bytes(ref byte bytes[]);
        bytes = new[16];  // 16 bytes total
        // Pack virtual_addr (8 bytes)
        bytes[0]  = virtual_addr[63:56];
        bytes[1]  = virtual_addr[55:48];
        bytes[2]  = virtual_addr[47:40];
        bytes[3]  = virtual_addr[39:32];
        bytes[4]  = virtual_addr[31:24];
        bytes[5]  = virtual_addr[23:16];
        bytes[6]  = virtual_addr[15:8];
        bytes[7]  = virtual_addr[7:0];
        // Pack r_key (4 bytes)
        bytes[8]  = r_key[31:24];
        bytes[9]  = r_key[23:16];
        bytes[10] = r_key[15:8];
        bytes[11] = r_key[7:0];
        // Pack dma_length (4 bytes)
        bytes[12] = dma_length[31:24];
        bytes[13] = dma_length[23:16];
        bytes[14] = dma_length[15:8];
        bytes[15] = dma_length[7:0];
        return 16;
    endfunction
    
    virtual function int unpack_bytes(const ref byte bytes[]);
        if (bytes.size() < 16) return 0;
        // Unpack virtual_addr
        virtual_addr = {bytes[0], bytes[1], bytes[2], bytes[3],
                        bytes[4], bytes[5], bytes[6], bytes[7]};
        // Unpack r_key
        r_key = {bytes[8], bytes[9], bytes[10], bytes[11]};
        // Unpack dma_length
        dma_length = {bytes[12], bytes[13], bytes[14], bytes[15]};
        return 16;
    endfunction
    
endclass

`endif // RDMA_RETH_SV
