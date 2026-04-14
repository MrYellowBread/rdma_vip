//============================================================================
// RDMA VIP - Memory Model
// Simulates physical memory for DMA operations
//============================================================================

`ifndef RDMA_MEMORY_MODEL_SV
`define RDMA_MEMORY_MODEL_SV

class rdma_memory_model extends uvm_component;
    `uvm_component_utils(rdma_memory_model)
    
    // Memory storage - associative array for sparse allocation
    // Index: physical address >> 12 (page aligned)
    // Value: 4KB page data
    byte memory_pages[bit [63:0]][];
    
    // Page size (4KB)
    localparam int PAGE_SIZE = 4096;
    localparam int PAGE_SHIFT = 12;
    
    // Memory statistics
    int total_pages_allocated;
    int total_bytes_allocated;
    int total_reads;
    int total_writes;
    
    //----------------------------------------------------------------------------
    // Constructor
    //----------------------------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
        total_pages_allocated = 0;
        total_bytes_allocated = 0;
        total_reads = 0;
        total_writes = 0;
    endfunction
    
    //----------------------------------------------------------------------------
    // Write data to memory
    //----------------------------------------------------------------------------
    virtual function bit write(bit [63:0] pa, byte data[]);
        bit [63:0] page_addr;
        int offset;
        int page_idx;
        int i;
        
        if (data.size() == 0) begin
            `uvm_warning("MEM", "Write called with empty data")
            return 1;
        end
        
        for (i = 0; i < data.size(); i++) begin
            // Calculate page address and offset
            page_addr = ((pa + i) >> PAGE_SHIFT) << PAGE_SHIFT;
            offset = (pa + i) & (PAGE_SIZE - 1);
            
            // Allocate page if not exists
            if (!memory_pages.exists(page_addr)) begin
                memory_pages[page_addr] = new[PAGE_SIZE];
                total_pages_allocated++;
                total_bytes_allocated += PAGE_SIZE;
                `uvm_info("MEM", $sformatf("Allocated page at 0x%016X", page_addr), UVM_HIGH)
            end
            
            // Write byte
            memory_pages[page_addr][offset] = data[i];
        end
        
        total_writes++;
        `uvm_info("MEM", $sformatf("Wrote %0d bytes to PA=0x%016X", data.size(), pa), UVM_HIGH)
        return 1;
    endfunction
    
    //----------------------------------------------------------------------------
    // Read data from memory
    //----------------------------------------------------------------------------
    virtual function bit read(bit [63:0] pa, int length, ref byte data[]);
        bit [63:0] page_addr;
        int offset;
        int i;
        
        data = new[length];
        
        for (i = 0; i < length; i++) begin
            // Calculate page address and offset
            page_addr = ((pa + i) >> PAGE_SHIFT) << PAGE_SHIFT;
            offset = (pa + i) & (PAGE_SIZE - 1);
            
            // Check if page exists
            if (!memory_pages.exists(page_addr)) begin
                `uvm_warning("MEM", $sformatf("Reading from unallocated page at PA=0x%016X", page_addr))
                data[i] = 8'h00;  // Return zero for unallocated memory
            end else begin
                data[i] = memory_pages[page_addr][offset];
            end
        end
        
        total_reads++;
        `uvm_info("MEM", $sformatf("Read %0d bytes from PA=0x%016X", length, pa), UVM_HIGH)
        return 1;
    endfunction
    
    //----------------------------------------------------------------------------
    // Compare data with memory contents
    //----------------------------------------------------------------------------
    virtual function bit compare(bit [63:0] pa, byte expected_data[]);
        byte actual_data[];
        int i;
        bit match;
        
        if (!read(pa, expected_data.size(), actual_data)) begin
            return 0;
        end
        
        match = 1;
        for (i = 0; i < expected_data.size(); i++) begin
            if (actual_data[i] !== expected_data[i]) begin
                `uvm_error("MEM", $sformatf("Mismatch at PA+0x%04X: Expected=0x%02X Actual=0x%02X",
                          i, expected_data[i], actual_data[i]))
                match = 0;
            end
        end
        
        return match;
    endfunction
    
    //----------------------------------------------------------------------------
    // Zero-fill a memory region
    //----------------------------------------------------------------------------
    virtual function void zero_fill(bit [63:0] pa, int length);
        byte zeros[];
        zeros = new[length];
        foreach (zeros[i]) zeros[i] = 0;
        write(pa, zeros);
    endfunction
    
    //----------------------------------------------------------------------------
    // Dump memory contents (for debug)
    //----------------------------------------------------------------------------
    virtual function void dump(bit [63:0] pa, int length);
        byte data[];
        int i;
        string line;
        
        if (!read(pa, length, data)) return;
        
        $display("=== Memory Dump @ 0x%016X (%0d bytes) ===", pa, length);
        for (i = 0; i < length; i += 16) begin
            line = $sformatf("%08X: ", pa + i);
            for (int j = 0; j < 16 && (i + j) < length; j++) begin
                line = {line, $sformatf("%02X ", data[i + j])};
            end
            $display("%s", line);
        end
        $display("===========================================");
    endfunction
    
    //----------------------------------------------------------------------------
    // Get memory statistics
    //----------------------------------------------------------------------------
    virtual function void get_stats(output int pages, output int bytes, output int reads, output int writes);
        pages = total_pages_allocated;
        bytes = total_bytes_allocated;
        reads = total_reads;
        writes = total_writes;
    endfunction
    
    //----------------------------------------------------------------------------
    // Clear all memory
    //----------------------------------------------------------------------------
    virtual function void clear();
        memory_pages.delete();
        total_pages_allocated = 0;
        total_bytes_allocated = 0;
        `uvm_info("MEM", "Memory cleared", UVM_MEDIUM)
    endfunction
    
    //----------------------------------------------------------------------------
    // Report Phase
    //----------------------------------------------------------------------------
    function void report_phase(uvm_phase phase);
        `uvm_info("MEM_REPORT", $sformatf("Memory Statistics: Pages=%0d Bytes=%0d Reads=%0d Writes=%0d",
                  total_pages_allocated, total_bytes_allocated, total_reads, total_writes), UVM_LOW)
    endfunction
    
endclass

`endif // RDMA_MEMORY_MODEL_SV
