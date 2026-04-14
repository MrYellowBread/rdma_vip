//============================================================================
// RDMA VIP - DMA Write Engine
// Simulates DMA write operations to local memory
//============================================================================

`ifndef RDMA_DMA_WRITE_ENGINE_SV
`define RDMA_DMA_WRITE_ENGINE_SV

class rdma_dma_write_engine extends uvm_component;
    `uvm_component_utils(rdma_dma_write_engine)
    
    // Configuration
    rdma_vip_cfg cfg;
    
    // Memory model - simplified byte-addressable memory
    byte memory[int];  // Indexed by 64-bit address (split into chunks)
    
    // Statistics
    int writes_completed;
    int bytes_written;
    int write_errors;
    
    // Latency modeling
    int current_latency;
    
    //----------------------------------------------------------------------------
    // Constructor
    //----------------------------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
        writes_completed = 0;
        bytes_written = 0;
        write_errors = 0;
        current_latency = 0;
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
    // Write data to memory at physical address
    // Returns 1 on success, 0 on failure
    //----------------------------------------------------------------------------
    function bit write(bit [63:0] pa, const ref byte data[]);
        int len = data.size();
        bit [63:0] addr;
        int i;
        
        if (len == 0) begin
            `uvm_warning("DMA_ENGINE", "Write called with zero-length data")
            return 1;  // Nothing to write is not an error
        end
        
        // Simulate DMA latency
        if (cfg.dma_latency_cycles > 0) begin
            current_latency = cfg.dma_latency_cycles;
        end
        
        // Write data byte by byte
        for (i = 0; i < len; i++) begin
            addr = pa + i;
            memory[addr] = data[i];
        end
        
        writes_completed++;
        bytes_written += len;
        
        `uvm_info("DMA_ENGINE", $sformatf("DMA Write: PA=0x%016X Len=%0d (total writes=%0d, bytes=%0d)",
                  pa, len, writes_completed, bytes_written), UVM_HIGH)
        
        return 1;
    endfunction
    
    //----------------------------------------------------------------------------
    // Read data from memory at physical address
    //----------------------------------------------------------------------------
    function bit read(bit [63:0] pa, int len, output byte data[]);
        bit [63:0] addr;
        int i;
        
        data = new[len];
        
        for (i = 0; i < len; i++) begin
            addr = pa + i;
            if (memory.exists(addr)) begin
                data[i] = memory[addr];
            end else begin
                data[i] = 0;  // Uninitialized memory reads as 0
            end
        end
        
        `uvm_info("DMA_ENGINE", $sformatf("DMA Read: PA=0x%016X Len=%0d", pa, len), UVM_HIGH)
        
        return 1;
    endfunction
    
    //----------------------------------------------------------------------------
    // Write with scatter-gather support
    //----------------------------------------------------------------------------
    function bit write_scatter(bit [63:0] pa[], const ref byte data[][]);
        int num_regions = pa.size();
        int total_len = 0;
        int i;
        bit success = 1;
        
        if (num_regions != data.size()) begin
            `uvm_error("DMA_ENGINE", "Scatter-gather size mismatch: pa.size() != data.size()")
            return 0;
        end
        
        for (i = 0; i < num_regions; i++) begin
            if (!write(pa[i], data[i])) begin
                success = 0;
                write_errors++;
            end
            total_len += data[i].size();
        end
        
        `uvm_info("DMA_ENGINE", $sformatf("DMA Scatter Write: %0d regions, total=%0d bytes",
                  num_regions, total_len), UVM_MEDIUM)
        
        return success;
    endfunction
    
    //----------------------------------------------------------------------------
    // Zero memory region
    //----------------------------------------------------------------------------
    function void zero_memory(bit [63:0] pa, int len);
        bit [63:0] addr;
        int i;
        
        for (i = 0; i < len; i++) begin
            addr = pa + i;
            memory[addr] = 0;
        end
        
        `uvm_info("DMA_ENGINE", $sformatf("Zeroed memory: PA=0x%016X Len=%0d", pa, len), UVM_HIGH)
    endfunction
    
    //----------------------------------------------------------------------------
    // Compare memory with expected data
    //----------------------------------------------------------------------------
    function bit compare_memory(bit [63:0] pa, const ref byte expected[]);
        bit [63:0] addr;
        byte actual;
        int i;
        int len = expected.size();
        bit match = 1;
        
        for (i = 0; i < len; i++) begin
            addr = pa + i;
            if (memory.exists(addr)) begin
                actual = memory[addr];
            end else begin
                actual = 0;
            end
            
            if (actual !== expected[i]) begin
                match = 0;
                `uvm_error("DMA_ENGINE", $sformatf("Memory mismatch at 0x%016X: expected=0x%02X actual=0x%02X",
                          addr, expected[i], actual))
            end
        end
        
        return match;
    endfunction
    
    //----------------------------------------------------------------------------
    // Get memory contents as hex string (for debugging)
    //----------------------------------------------------------------------------
    function string get_memory_hex(bit [63:0] pa, int len);
        string s;
        bit [63:0] addr;
        int i;
        byte b;
        
        s = "";
        for (i = 0; i < len && i < 64; i++) begin  // Limit to 64 bytes
            addr = pa + i;
            if (memory.exists(addr)) begin
                b = memory[addr];
            end else begin
                b = 0;
            end
            s = {s, $sformatf("%02X", b)};
            if (i % 16 == 15) s = {s, " "};
        end
        
        if (len > 64) begin
            s = {s, "..."};
        end
        
        return s;
    endfunction
    
    //----------------------------------------------------------------------------
    // Clear all memory
    //----------------------------------------------------------------------------
    function void clear_memory();
        memory.delete();
        writes_completed = 0;
        bytes_written = 0;
        write_errors = 0;
        `uvm_info("DMA_ENGINE", "Memory cleared", UVM_MEDIUM)
    endfunction
    
    //----------------------------------------------------------------------------
    // Report Phase
    //----------------------------------------------------------------------------
    function void report_phase(uvm_phase phase);
        `uvm_info("DMA_ENGINE_REPORT", $sformatf("DMA Statistics: Writes=%0d Bytes=%0d Errors=%0d UniqueAddrs=%0d",
                  writes_completed, bytes_written, write_errors, memory.num()), UVM_LOW)
    endfunction
    
endclass

`endif // RDMA_DMA_WRITE_ENGINE_SV
