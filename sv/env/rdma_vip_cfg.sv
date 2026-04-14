//============================================================================
// RDMA VIP - Configuration Object
// Central hub for VIP behavior control
//============================================================================

`ifndef RDMA_VIP_CFG_SV
`define RDMA_VIP_CFG_SV

class rdma_vip_cfg extends uvm_object;
    `uvm_object_utils(rdma_vip_cfg)
    
    // Global and functional switches
    rand bit    is_active = 1;                    // 0: Passive monitor mode
    rand bit    enable_psn_check = 1;             // Enable PSN sequence check
    rand bit    enable_mem_protection = 1;        // Enable memory protection (R_Key/L_Key)
    rand bit    error_injection_enable = 0;       // Global error injection switch
    rand bit    cov_enable = 1;                   // Enable functional coverage
    rand int    verbosity_level = UVM_MEDIUM;     // Global report verbosity
    
    // Connection and protocol parameters
    rand qp_type_e   default_qp_type = QP_TYPE_RC;
    rand int         default_pmtu = 1024;         // Default path MTU (bytes)
    rand int         default_rnr_retry_cnt = 7;   // Default RNR retry count
    
    // Agent configurations
    rdma_requester_tx_cfg  req_tx_cfg;
    rdma_responder_rx_cfg  resp_rx_cfg;
    rdma_requester_rx_cfg  req_rx_cfg;
    
    // Retry and flow control policy
    rand retry_mode_e  retry_mode = RETRY_GO_BACK_N;
    rand int           ack_delay_cycles;          // ACK/NACK delay (cycles)
    rand int           dma_latency_cycles;        // DMA operation latency
    
    //----------------------------------------------------------------------------
    // Constraints
    //----------------------------------------------------------------------------
    constraint valid_cfg_c {
        default_pmtu inside {256, 512, 1024, 2048, 4096};
        ack_delay_cycles inside {[0:100]};
        dma_latency_cycles inside {[1:50]};
    }
    
    //----------------------------------------------------------------------------
    // Constructor
    //----------------------------------------------------------------------------
    function new(string name = "rdma_vip_cfg");
        super.new(name);
        // Create sub-configurations
        req_tx_cfg = new("req_tx_cfg");
        resp_rx_cfg = new("resp_rx_cfg");
        req_rx_cfg = new("req_rx_cfg");
    endfunction
    
    //----------------------------------------------------------------------------
    // Get configuration for printing
    //----------------------------------------------------------------------------
    virtual function string sprint();
        string s;
        s = $sformatf("RDMA VIP Config:\n");
        s = {s, $sformatf("  is_active: %b\n", is_active)};
        s = {s, $sformatf("  enable_psn_check: %b\n", enable_psn_check)};
        s = {s, $sformatf("  enable_mem_protection: %b\n", enable_mem_protection)};
        s = {s, $sformatf("  error_injection_enable: %b\n", error_injection_enable)};
        s = {s, $sformatf("  cov_enable: %b\n", cov_enable)};
        s = {s, $sformatf("  default_qp_type: %s\n", default_qp_type.name())};
        s = {s, $sformatf("  default_pmtu: %0d\n", default_pmtu)};
        s = {s, $sformatf("  retry_mode: %s\n", retry_mode.name())};
        s = {s, $sformatf("  ack_delay_cycles: %0d\n", ack_delay_cycles)};
        s = {s, $sformatf("  dma_latency_cycles: %0d\n", dma_latency_cycles)};
        return s;
    endfunction
    
endclass

//----------------------------------------------------------------------------
// Sub-configuration classes
//----------------------------------------------------------------------------

class rdma_requester_tx_cfg extends uvm_object;
    `uvm_object_utils(rdma_requester_tx_cfg)
    
    rand bit    enable_retry = 1;
    rand int    retry_timeout_cycles = 1000;
    rand int    max_retries = 7;
    
    function new(string name = "rdma_requester_tx_cfg");
        super.new(name);
    endfunction
endclass

class rdma_responder_rx_cfg extends uvm_object;
    `uvm_object_utils(rdma_responder_rx_cfg)
    
    rand bit    enable_dma_model = 1;
    rand int    dma_delay_cycles = 0;
    rand bit    generate_ack = 1;
    
    function new(string name = "rdma_responder_rx_cfg");
        super.new(name);
    endfunction
endclass

class rdma_requester_rx_cfg extends uvm_object;
    `uvm_object_utils(rdma_requester_rx_cfg)
    
    rand bit    enable_psn_check = 1;
    rand bit    enable_mem_protection = 1;
    rand bit    generate_cqe = 1;
    
    function new(string name = "rdma_requester_rx_cfg");
        super.new(name);
    endfunction
endclass

`endif // RDMA_VIP_CFG_SV
