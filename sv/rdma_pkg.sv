//============================================================================
// RDMA VIP - SystemVerilog Package
// Main package file for RDMA Verification IP
//============================================================================

`ifndef RDMA_PKG_SV
`define RDMA_PKG_SV

package rdma_pkg;
    
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    
    //------------------------------------------------------------------------
    // Common Definitions
    //------------------------------------------------------------------------
    `include "common/rdma_defines.sv"
    
    //------------------------------------------------------------------------
    // Transaction Classes (TLM Objects)
    //------------------------------------------------------------------------
    `include "transactions/rdma_reth.sv"
    `include "transactions/rdma_aeth.sv"
    `include "transactions/rdma_atomic_eth.sv"
    `include "transactions/rdma_transaction.sv"
    `include "transactions/rdma_packet.sv"
    `include "transactions/rdma_qp_context.sv"
    `include "transactions/rdma_cqe.sv"
    
    //------------------------------------------------------------------------
    // Common Functional Models
    //------------------------------------------------------------------------
    `include "common/rdma_psn_manager.sv"
    `include "common/rdma_mr_lookup.sv"
    `include "common/rdma_dma_write_engine.sv"
    `include "common/rdma_cqe_generator.sv"
    
    //------------------------------------------------------------------------
    // Configuration
    //------------------------------------------------------------------------
    `include "env/rdma_vip_cfg.sv"
    
    //------------------------------------------------------------------------
    // Agents
    //------------------------------------------------------------------------
    `include "agents/rdma_requester_tx_agent.sv"
    `include "agents/rdma_requester_rx_agent.sv"
    `include "agents/rdma_responder_rx_agent.sv"
    
    //------------------------------------------------------------------------
    // Verification Components
    //------------------------------------------------------------------------
    `include "env/rdma_scoreboard.sv"
    `include "coverage/rdma_cov_model.sv"
    
    //------------------------------------------------------------------------
    // Environment
    //------------------------------------------------------------------------
    `include "env/rdma_vip_env.sv"
    
    //------------------------------------------------------------------------
    // Sequences
    //------------------------------------------------------------------------
    `include "sequences/rdma_base_sequence.sv"
    `include "sequences/rdma_write_sequence.sv"
    `include "sequences/rdma_read_sequence.sv"
    `include "sequences/rdma_atomic_sequence.sv"
    `include "sequences/rdma_virtual_sequence.sv"
    
    //------------------------------------------------------------------------
    // Tests
    //------------------------------------------------------------------------
    `include "tests/rdma_base_test.sv"
    `include "tests/rdma_write_test.sv"
    `include "tests/rdma_read_test.sv"
    `include "tests/rdma_atomic_test.sv"
    `include "tests/rdma_sanity_test.sv"
    
endpackage : rdma_pkg

`endif // RDMA_PKG_SV
