//============================================================================
// RDMA VIP - Common Definitions
// RDMA Virtual IP with TLM Framework
// Based on RDMA VIP Design Document
//============================================================================

`ifndef RDMA_DEFINES_SV
`define RDMA_DEFINES_SV

//----------------------------------------------------------------------------
// RDMA Protocol Opcodes (InfiniBand Table 38)
//----------------------------------------------------------------------------
typedef enum bit [7:0] {
    // Reliable Connection (RC) Service Opcodes
    RC_SEND_FIRST               = 8'b0010_0000,
    RC_SEND_MIDDLE              = 8'b0010_0001,
    RC_SEND_LAST                = 8'b0010_0010,
    RC_SEND_LAST_WITH_IMM       = 8'b0010_0011,
    RC_SEND_ONLY                = 8'b0010_0100,
    RC_SEND_ONLY_WITH_IMM       = 8'b0010_0101,
    
    RC_RDMA_WRITE_FIRST         = 8'b0011_0000,
    RC_RDMA_WRITE_MIDDLE        = 8'b0011_0001,
    RC_RDMA_WRITE_LAST          = 8'b0011_0010,
    RC_RDMA_WRITE_LAST_WITH_IMM = 8'b0011_0011,
    RC_RDMA_WRITE_ONLY          = 8'b0011_0100,
    RC_RDMA_WRITE_ONLY_WITH_IMM = 8'b0011_0101,
    
    RC_RDMA_READ_REQUEST        = 8'b0011_0110,
    RC_RDMA_READ_RESPONSE_FIRST = 8'b0011_0111,
    RC_RDMA_READ_RESPONSE_MIDDLE= 8'b0011_1000,
    RC_RDMA_READ_RESPONSE_LAST  = 8'b0011_1001,
    RC_RDMA_READ_RESPONSE_ONLY  = 8'b0011_1010,
    
    RC_ATOMIC_CMP_SWP           = 8'b0011_1011,
    RC_ATOMIC_FETCH_ADD         = 8'b0011_1100,
    RC_ATOMIC_CMP_SWP_RESPONSE  = 8'b0011_1101,
    RC_ATOMIC_FETCH_ADD_RESPONSE= 8'b0011_1110,
    
    // Acknowledgments
    RC_ACK                      = 8'b1000_0001,
    RC_NAK                      = 8'b1000_0010,
    
    // Unreliable Connection (UC) - similar to RC without ACKs
    // Unreliable Datagram (UD) - connectionless
    
    // Invalid
    RC_INVALID                  = 8'b1111_1111
} rdma_opcode_t;

//----------------------------------------------------------------------------
// QP Service Types
//----------------------------------------------------------------------------
typedef enum bit [2:0] {
    QP_TYPE_RC = 3'b000,  // Reliable Connection
    QP_TYPE_UC = 3'b001,  // Unreliable Connection
    QP_TYPE_RD = 3'b010,  // Reliable Datagram
    QP_TYPE_UD = 3'b011,  // Unreliable Datagram
    QP_TYPE_RAW = 3'b100  // Raw Datagram
} qp_type_e;

//----------------------------------------------------------------------------
// QP States
//----------------------------------------------------------------------------
typedef enum bit [3:0] {
    QP_STATE_RESET     = 4'b0000,  // RST - Initial state, QP unusable
    QP_STATE_INIT      = 4'b0001,  // INIT - Can receive but not process messages
    QP_STATE_RTR       = 4'b0010,  // RTR - Receive Queue ready
    QP_STATE_RTS       = 4'b0011,  // RTS - Send Queue ready, can process WRs
    QP_STATE_SQERR     = 4'b0100,  // SQEr - Send Queue Error
    QP_STATE_ERR       = 4'b0101,  // ERR - Error state, stop processing WQEs
    QP_STATE_SQD       = 4'b0110   // SQD - Send Queue Drained
} qp_state_e;

//----------------------------------------------------------------------------
// Transaction States
//----------------------------------------------------------------------------
typedef enum bit [3:0] {
    TRAN_PENDING      = 4'b0000,
    TRAN_REQ_SENT     = 4'b0001,
    TRAN_RESP_RECV    = 4'b0010,
    TRAN_COMPLETED    = 4'b0011,
    TRAN_ERROR        = 4'b0100,
    TRAN_TIMEOUT      = 4'b0101,
    TRAN_RETRY        = 4'b0110
} trans_state_e;

//----------------------------------------------------------------------------
// Retry Modes
//----------------------------------------------------------------------------
typedef enum bit [1:0] {
    RETRY_DISABLED  = 2'b00,
    RETRY_GO_BACK_N = 2'b01,
    RETRY_SELECTIVE = 2'b10
} retry_mode_e;

//----------------------------------------------------------------------------
// Completion Queue Entry (CQE) Status
//----------------------------------------------------------------------------
typedef enum bit [7:0] {
    WC_SUCCESS          = 8'h00,
    WC_LOC_LEN_ERR      = 8'h01,
    WC_LOC_QP_OP_ERR    = 8'h02,
    WC_LOC_EEC_OP_ERR   = 8'h03,
    WC_LOC_PROT_ERR     = 8'h04,
    WC_WR_FLUSH_ERR     = 8'h05,
    WC_MW_BIND_ERR      = 8'h06,
    WC_BAD_RESP_ERR     = 8'h07,
    WC_LOC_ACCESS_ERR   = 8'h08,
    WC_REM_INV_REQ_ERR  = 8'h09,
    WC_REM_ACCESS_ERR   = 8'h0A,
    WC_REM_OP_ERR       = 8'h0B,
    WC_RETRY_EXC_ERR    = 8'h0C,
    WC_RNR_RETRY_EXC_ERR= 8'h0D,
    WC_LOC_RDD_VIOL_ERR = 8'h0E,
    WC_REM_INV_RD_REQ_ERR= 8'h0F,
    WC_REM_ABORT_ERR    = 8'h10,
    WC_INV_EECN_ERR     = 8'h11,
    WC_INV_EEC_STATE_ERR= 8'h12,
    WC_FATAL_ERR        = 8'h13,
    WC_RESP_TIMEOUT_ERR = 8'h14,
    WC_GENERAL_ERR      = 8'hFF
} wc_status_e;

//----------------------------------------------------------------------------
// AETH Syndrome Definitions
//----------------------------------------------------------------------------
typedef enum bit [4:0] {
    AETH_ACK = 5'b00000,      // ACK - Success
    AETH_RNR = 5'b00101,      // RNR NAK - Receiver Not Ready
    AETH_NAK_PSNT = 5'b00110, // NAK - Packet Sequence Number Error
    AETH_NAK_INVL = 5'b00111, // NAK - Invalid Request
    AETH_NAK_RMT_ACC = 5'b01000, // NAK - Remote Access Error
    AETH_NAK_RMT_OP  = 5'b01001, // NAK - Remote Operational Error
    AETH_NAK_INVL_RD = 5'b01010  // NAK - Invalid RD Request
} aeth_syndrome_e;

//----------------------------------------------------------------------------
// Common Macros
//----------------------------------------------------------------------------
`define RDMA_MAX_PSN 24'hFFFFFF
`define RDMA_PSN_MASK 24'hFFFFFF
`define RDMA_MAX_DMA_LEN 32'h7FFFFFFF

`endif // RDMA_DEFINES_SV
