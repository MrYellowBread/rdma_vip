//============================================================================
// RDMA VIP - Atomic Extended Transport Header (AtomicETH)
// For ATOMIC operations (Compare-Swap, Fetch-Add)
//============================================================================

`ifndef RDMA_ATOMIC_ETH_SV
`define RDMA_ATOMIC_ETH_SV

class rdma_atomic_eth extends uvm_sequence_item;
    `uvm_object_utils(rdma_atomic_eth)
    
    // AtomicETH Fields
    rand bit [63:0] virtual_addr;   // Virtual Address
    rand bit [31:0] r_key;          // Remote Key
    rand bit [63:0] swap_data;      // Swap Data
    rand bit [63:0] compare_data;   // Compare Data (for CmpSwap)
    
    //----------------------------------------------------------------------------
    // Constraints
    //----------------------------------------------------------------------------
    constraint valid_r_key_c {
        r_key != 32'h0;
    }
    
    //----------------------------------------------------------------------------
    // Constructor
    //----------------------------------------------------------------------------
    function new(string name = "rdma_atomic_eth");
        super.new(name);
    endfunction
    
    //----------------------------------------------------------------------------
    // UVM Methods
    //----------------------------------------------------------------------------
    virtual function void do_copy(uvm_object rhs);
        rdma_atomic_eth rhs_;
        if (!$cast(rhs_, rhs)) begin
            `uvm_error("do_copy", "Cast failed")
            return;
        end
        super.do_copy(rhs);
        virtual_addr = rhs_.virtual_addr;
        r_key = rhs_.r_key;
        swap_data = rhs_.swap_data;
        compare_data = rhs_.compare_data;
    endfunction
    
    virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        rdma_atomic_eth rhs_;
        bit result;
        if (!$cast(rhs_, rhs)) return 0;
        result = super.do_compare(rhs, comparer) &&
                 (virtual_addr == rhs_.virtual_addr) &&
                 (r_key == rhs_.r_key) &&
                 (swap_data == rhs_.swap_data) &&
                 (compare_data == rhs_.compare_data);
        return result;
    endfunction
    
    virtual function string convert2string();
        string s;
        s = $sformatf("AtomicETH: VA=0x%016X R_Key=0x%08X Swap=0x%016X Compare=0x%016X",
                      virtual_addr, r_key, swap_data, compare_data);
        return s;
    endfunction
    
    virtual function void do_print(uvm_printer printer);
        printer.m_string = convert2string();
    endfunction
    
endclass

`endif // RDMA_ATOMIC_ETH_SV
