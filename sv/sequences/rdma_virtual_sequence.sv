//============================================================================
// RDMA VIP - Virtual Sequence
// Coordinates multiple sequences across agents
//============================================================================

`ifndef RDMA_VIRTUAL_SEQUENCE_SV
`define RDMA_VIRTUAL_SEQUENCE_SV

class rdma_virtual_sequence extends uvm_sequence;
    `uvm_object_utils(rdma_virtual_sequence)
    
    // Configuration
    rdma_vip_cfg cfg;
    
    // Sub-sequences
    rdma_write_sequence write_seq;
    rdma_read_sequence read_seq;
    rdma_atomic_sequence atomic_seq;
    
    // Transaction counts
    rand int num_writes = 5;
    rand int num_reads = 5;
    rand int num_atomics = 2;
    
    //----------------------------------------------------------------------------
    // Constraints
    //----------------------------------------------------------------------------
    constraint valid_counts_c {
        num_writes inside {[0:20]};
        num_reads inside {[0:20]};
        num_atomics inside {[0:10]};
    }
    
    //----------------------------------------------------------------------------
    // Constructor
    //----------------------------------------------------------------------------
    function new(string name = "rdma_virtual_sequence");
        super.new(name);
    endfunction
    
    //----------------------------------------------------------------------------
    // Pre-body
    //----------------------------------------------------------------------------
    virtual task pre_body();
        if (starting_phase != null) begin
            starting_phase.raise_objection(this, "RDMA Virtual Sequence");
        end
        
        // Get configuration
        if (!uvm_config_db#(rdma_vip_cfg)::get(null, get_full_name(), "cfg", cfg)) begin
            cfg = new();
        end
    endtask
    
    //----------------------------------------------------------------------------
    // Body - Coordinate all operations
    //----------------------------------------------------------------------------
    virtual task body();
        `uvm_info("VIRTUAL_SEQ", "Starting virtual sequence", UVM_MEDIUM)
        
        // Create sequences
        write_seq = rdma_write_sequence::type_id::create("write_seq");
        read_seq = rdma_read_sequence::type_id::create("read_seq");
        atomic_seq = rdma_atomic_sequence::type_id::create("atomic_seq");
        
        // Configure sequences
        write_seq.num_transactions = num_writes;
        read_seq.num_transactions = num_reads;
        atomic_seq.num_transactions = num_atomics;
        
        // Execute operations concurrently
        fork
            // WRITE operations
            if (num_writes > 0) begin
                `uvm_do_on(write_seq, p_sequencer)
            end
            
            // READ operations
            if (num_reads > 0) begin
                `uvm_do_on(read_seq, p_sequencer)
            end
            
            // ATOMIC operations
            if (num_atomics > 0) begin
                `uvm_do_on(atomic_seq, p_sequencer)
            end
        join
        
        // Wait for all operations to complete
        #1000ns;
        
        `uvm_info("VIRTUAL_SEQ", "Virtual sequence completed", UVM_MEDIUM)
    endtask
    
    //----------------------------------------------------------------------------
    // Post-body
    //----------------------------------------------------------------------------
    virtual task post_body();
        if (starting_phase != null) begin
            starting_phase.drop_objection(this, "RDMA Virtual Sequence");
        end
    endtask
    
endclass

`endif // RDMA_VIRTUAL_SEQUENCE_SV
