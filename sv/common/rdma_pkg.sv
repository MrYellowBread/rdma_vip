//============================================================================
// RDMA VIP - Package File
// Central package for RDMA VIP verification platform
//============================================================================

`ifndef RDMA_PKG_SV
`define RDMA_PKG_SV

package rdma_pkg;
    
    //============================================================================
    // UVM Import
    //============================================================================
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    
    //============================================================================
    // Common Definitions
    //============================================================================
    `include "sv/common/rdma_defines.sv"
    
    //============================================================================
    // Transaction Classes (UVM Sequence Items)
    //============================================================================
    `include "sv/transactions/rdma_reth.sv"
    `include "sv/transactions/rdma_aeth.sv"
    `include "sv/transactions/rdma_atomic_eth.sv"
    `include "sv/transactions/rdma_transaction.sv"
    `include "sv/transactions/rdma_packet.sv"
    `include "sv/transactions/rdma_qp_context.sv"
    `include "sv/transactions/rdma_cqe.sv"
    
    //============================================================================
    // Configuration Classes
    //============================================================================
    `include "sv/env/rdma_vip_cfg.sv"
    
    //============================================================================
    // Functional Models
    //============================================================================
    `include "sv/common/rdma_psn_manager.sv"
    `include "sv/common/rdma_mr_lookup.sv"
    `include "sv/common/rdma_dma_write_engine.sv"
    `include "sv/common/rdma_cqe_generator.sv"
    `include "sv/common/rdma_memory_model.sv"
    `include "sv/common/rdma_retry_handler.sv"
    
    //============================================================================
    // Verification Components
    //============================================================================
    `include "sv/common/rdma_scoreboard.sv"
    `include "sv/coverage/rdma_cov_model.sv"
    
    //============================================================================
    // Agents
    //============================================================================
    `include "sv/agents/rdma_requester_rx_agent.sv"
    `include "sv/agents/rdma_requester_tx_agent.sv"
    `include "sv/agents/rdma_responder_rx_agent.sv"
    
    //============================================================================
    // Environment
    //============================================================================
    `include "sv/env/rdma_vip_env.sv"
    
    //============================================================================
    // Sequences
    //============================================================================
    `include "sv/sequences/rdma_base_sequence.sv"
    `include "sv/sequences/rdma_write_sequence.sv"
    `include "sv/sequences/rdma_read_sequence.sv"
    `include "sv/sequences/rdma_init_qp_sequence.sv"
    `include "sv/sequences/rdma_virtual_sequence.sv"
    
    //============================================================================
    // Tests
    //============================================================================
    `include "sv/tests/rdma_base_test.sv"
    `include "sv/tests/rdma_write_test.sv"
    `include "sv/tests/rdma_read_test.sv"
    `include "sv/tests/rdma_concurrent_test.sv"
    `include "sv/tests/rdma_error_test.sv"
    
endpackage

`endif // RDMA_PKG_SV
