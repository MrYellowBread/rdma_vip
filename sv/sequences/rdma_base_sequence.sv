//============================================================================
// RDMA VIP - Base Sequence
// Base class for all RDMA sequences
//============================================================================

`ifndef RDMA_BASE_SEQUENCE_SV
`define RDMA_BASE_SEQUENCE_SV

class rdma_base_sequence extends uvm_sequence #(rdma_transaction);
    `uvm_object_utils(rdma_base_sequence)
    
    // Configuration
    rdma_vip_cfg cfg;
    
    // Transaction count
    rand int num_transactions = 10;
    
    // QP context for this sequence
    rdma_qp_context qp_ctx;
    
    //----------------------------------------------------------------------------
    // Constraints
    //----------------------------------------------------------------------------
    constraint valid_num_transactions_c {
        num_transactions inside {[1:100]};
    }
    
    //----------------------------------------------------------------------------
    // Constructor
    //----------------------------------------------------------------------------
    function new(string name = "rdma_base_sequence");
        super.new(name);
    endfunction
    
    //----------------------------------------------------------------------------
    // Pre-body
    //----------------------------------------------------------------------------
    virtual task pre_body();
        if (starting_phase != null) begin
            starting_phase.raise_objection(this, "RDMA Base Sequence");
        end
        
        // Get configuration
        if (!uvm_config_db#(rdma_vip_cfg)::get(null, get_full_name(), "cfg", cfg)) begin
            cfg = new();
        end
        
        // Create and initialize QP context
        qp_ctx = new("qp_ctx");
        assert(qp_ctx.randomize() with {
            state == QP_STATE_RTS;
            qp_type == QP_TYPE_RC;
        });
    endtask
    
    //----------------------------------------------------------------------------
    // Body - to be overridden by derived classes
    //----------------------------------------------------------------------------
    virtual task body();
        `uvm_info("BASE_SEQ", "Base sequence body - should be overridden", UVM_LOW)
    endtask
    
    //----------------------------------------------------------------------------
    // Post-body
    //----------------------------------------------------------------------------
    virtual task post_body();
        if (starting_phase != null) begin
            starting_phase.drop_objection(this, "RDMA Base Sequence");
        end
    endtask
    
endclass

`endif // RDMA_BASE_SEQUENCE_SV
