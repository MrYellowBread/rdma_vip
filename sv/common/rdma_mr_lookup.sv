//============================================================================
// RDMA VIP - Memory Region Lookup
// Validates memory keys and performs address translation
//============================================================================

`ifndef RDMA_MR_LOOKUP_SV
`define RDMA_MR_LOOKUP_SV

class rdma_mr_lookup extends uvm_component;
    `uvm_component_utils(rdma_mr_lookup)
    
    // Configuration
    rdma_vip_cfg cfg;
    
    // Memory Region structure
    typedef struct {
        bit [63:0] base_addr;
        bit [63:0] length;
        bit [31:0] l_key;
        bit [31:0] r_key;
        bit local_read;
        bit local_write;
        bit remote_read;
        bit remote_write;
        bit atomic;
        bit valid;
    } mr_entry_t;
    
    // MR lookup table indexed by L_Key
    mr_entry_t mr_table[int];
    
    // Statistics
    int lookups;
    int lookup_hits;
    int lookup_misses;
    int permission_violations;
    int address_violations;
    
    //----------------------------------------------------------------------------
    // Constructor
    //----------------------------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
        lookups = 0;
        lookup_hits = 0;
        lookup_misses = 0;
        permission_violations = 0;
        address_violations = 0;
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
    // Register a Memory Region
    //----------------------------------------------------------------------------
    function void register_mr(int l_key, bit [63:0] base_addr, bit [63:0] length,
                              bit [31:0] r_key,
                              bit l_read = 1, bit l_write = 1,
                              bit r_read = 1, bit r_write = 1, bit atomic = 1);
        mr_entry_t mr;
        mr.base_addr = base_addr;
        mr.length = length;
        mr.l_key = l_key;
        mr.r_key = r_key;
        mr.local_read = l_read;
        mr.local_write = l_write;
        mr.remote_read = r_read;
        mr.remote_write = r_write;
        mr.atomic = atomic;
        mr.valid = 1;
        mr_table[l_key] = mr;
        `uvm_info("MR_LOOKUP", $sformatf("Registered MR: L_Key=0x%08X R_Key=0x%08X Base=0x%016X Len=%0d",
                  l_key, r_key, base_addr, length), UVM_MEDIUM)
    endfunction
    
    //----------------------------------------------------------------------------
    // Unregister a Memory Region
    //----------------------------------------------------------------------------
    function void unregister_mr(int l_key);
        if (mr_table.exists(l_key)) begin
            mr_table[l_key].valid = 0;
            mr_table.delete(l_key);
            `uvm_info("MR_LOOKUP", $sformatf("Unregistered MR: L_Key=0x%08X", l_key), UVM_MEDIUM)
        end
    endfunction
    
    //----------------------------------------------------------------------------
    // Validate memory access using L_Key (local access)
    //----------------------------------------------------------------------------
    function bit validate_local_access(bit [31:0] l_key, bit [63:0] vaddr, int length,
                                       bit write_access);
        mr_entry_t mr;
        bit [63:0] end_addr;
        
        lookups++;
        
        if (!mr_table.exists(l_key)) begin
            lookup_misses++;
            `uvm_error("MR_LOOKUP", $sformatf("Invalid L_Key: 0x%08X", l_key))
            return 0;
        end
        
        mr = mr_table[l_key];
        lookup_hits++;
        
        if (!mr.valid) begin
            lookup_misses++;
            `uvm_error("MR_LOOKUP", $sformatf("MR not valid for L_Key: 0x%08X", l_key))
            return 0;
        end
        
        // Check permissions
        if (write_access && !mr.local_write) begin
            permission_violations++;
            `uvm_error("MR_LOOKUP", $sformatf("Local write permission denied for L_Key: 0x%08X", l_key))
            return 0;
        end
        
        if (!write_access && !mr.local_read) begin
            permission_violations++;
            `uvm_error("MR_LOOKUP", $sformatf("Local read permission denied for L_Key: 0x%08X", l_key))
            return 0;
        end
        
        // Check address range
        if (vaddr < mr.base_addr) begin
            address_violations++;
            `uvm_error("MR_LOOKUP", $sformatf("Address below MR base: vaddr=0x%016X < base=0x%016X",
                      vaddr, mr.base_addr))
            return 0;
        end
        
        end_addr = vaddr + length - 1;
        if (end_addr >= mr.base_addr + mr.length) begin
            address_violations++;
            `uvm_error("MR_LOOKUP", $sformatf("Address exceeds MR range: end=0x%016X >= limit=0x%016X",
                      end_addr, mr.base_addr + mr.length))
            return 0;
        end
        
        return 1;
    endfunction
    
    //----------------------------------------------------------------------------
    // Validate memory access using R_Key (remote access validation at responder)
    //----------------------------------------------------------------------------
    function bit validate_remote_access(bit [31:0] r_key, bit [63:0] vaddr, int length,
                                        bit write_access, bit atomic_access = 0);
        mr_entry_t mr;
        bit found = 0;
        int l_key;
        bit [63:0] end_addr;
        
        lookups++;
        
        // Find MR by R_Key
        foreach (mr_table[key]) begin
            if (mr_table[key].r_key == r_key && mr_table[key].valid) begin
                mr = mr_table[key];
                l_key = key;
                found = 1;
                break;
            end
        end
        
        if (!found) begin
            lookup_misses++;
            `uvm_error("MR_LOOKUP", $sformatf("Invalid R_Key: 0x%08X", r_key))
            return 0;
        end
        
        lookup_hits++;
        
        // Check permissions
        if (atomic_access && !mr.atomic) begin
            permission_violations++;
            `uvm_error("MR_LOOKUP", $sformatf("Atomic permission denied for R_Key: 0x%08X", r_key))
            return 0;
        end
        
        if (write_access && !mr.remote_write) begin
            permission_violations++;
            `uvm_error("MR_LOOKUP", $sformatf("Remote write permission denied for R_Key: 0x%08X", r_key))
            return 0;
        end
        
        if (!write_access && !atomic_access && !mr.remote_read) begin
            permission_violations++;
            `uvm_error("MR_LOOKUP", $sformatf("Remote read permission denied for R_Key: 0x%08X", r_key))
            return 0;
        end
        
        // Check address range
        if (vaddr < mr.base_addr) begin
            address_violations++;
            `uvm_error("MR_LOOKUP", $sformatf("Remote address below MR base: vaddr=0x%016X < base=0x%016X",
                      vaddr, mr.base_addr))
            return 0;
        end
        
        end_addr = vaddr + length - 1;
        if (end_addr >= mr.base_addr + mr.length) begin
            address_violations++;
            `uvm_error("MR_LOOKUP", $sformatf("Remote address exceeds MR range: end=0x%016X >= limit=0x%016X",
                      end_addr, mr.base_addr + mr.length))
            return 0;
        end
        
        return 1;
    endfunction
    
    //----------------------------------------------------------------------------
    // Simplified validation for requester_rx (used in driver)
    //----------------------------------------------------------------------------
    function bit validate(bit [31:0] r_key, bit [63:0] vaddr, int length,
                          bit [31:0] l_key, bit [63:0] mr_base, bit [63:0] mr_len);
        if (!cfg.enable_mem_protection) begin
            return 1;  // Skip validation if disabled
        end
        
        lookups++;
        
        // Check if L_Key matches
        if (!mr_table.exists(l_key)) begin
            lookup_misses++;
            return 0;
        end
        
        lookup_hits++;
        
        // Simple range check
        if (vaddr < mr_base) begin
            address_violations++;
            return 0;
        end
        
        if ((vaddr + length) > (mr_base + mr_len)) begin
            address_violations++;
            return 0;
        end
        
        return 1;
    endfunction
    
    //----------------------------------------------------------------------------
    // Calculate physical address from virtual address and MR base
    //----------------------------------------------------------------------------
    function bit [63:0] calculate_pa(bit [63:0] vaddr, bit [63:0] mr_base);
        // In this TLM model, PA = VA (simplified)
        // In real implementation, would use page table lookup
        return vaddr;
    endfunction
    
    //----------------------------------------------------------------------------
    // Get MR entry by L_Key
    //----------------------------------------------------------------------------
    function bit get_mr(int l_key, output mr_entry_t mr);
        if (mr_table.exists(l_key)) begin
            mr = mr_table[l_key];
            return 1;
        end
        return 0;
    endfunction
    
    //----------------------------------------------------------------------------
    // Get MR entry by R_Key
    //----------------------------------------------------------------------------
    function bit get_mr_by_rkey(bit [31:0] r_key, output mr_entry_t mr);
        foreach (mr_table[key]) begin
            if (mr_table[key].r_key == r_key && mr_table[key].valid) begin
                mr = mr_table[key];
                return 1;
            end
        end
        return 0;
    endfunction
    
    //----------------------------------------------------------------------------
    // Report Phase
    //----------------------------------------------------------------------------
    function void report_phase(uvm_phase phase);
        `uvm_info("MR_LOOKUP_REPORT", $sformatf("MR Statistics: Lookups=%0d Hits=%0d Misses=%0d Permission_Err=%0d Address_Err=%0d",
                  lookups, lookup_hits, lookup_misses, permission_violations, address_violations), UVM_LOW)
    endfunction
    
endclass

`endif // RDMA_MR_LOOKUP_SV
