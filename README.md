# RDMA VIP - RDMA Verification IP with TLM Framework

基于TLM（事务级建模）的RDMA（远程直接内存访问）虚拟IP验证平台。

## 项目概述

本项目实现了一个完整的RDMA协议虚拟IP（VIP），用于验证RDMA控制器的设计。基于InfiniBand规范，支持RC（可靠连接）服务类型。

### 核心特性

- **完整的事务级建模(TLM)**：使用UVM TLM进行快速协议验证
- **RC服务支持**：可靠连接服务，包含ACK/NAK机制
- **PSN管理**：包序列号管理，支持乱序检测和重传
- **内存保护**：基于R_Key/L_Key的内存区域权限检查
- **DMA引擎**：TLM级DMA写入模型，支持AXI4接口
- **CQE生成**：完成队列条目生成和管理
- **覆盖率收集**：全面的功能覆盖率模型

## 架构设计

```
┌─────────────────────────────────────────────────────────────┐
│                    RDMA VIP Environment                      │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌─────────────────┐                 │
│  │ Requester TX    │───>│ Responder RX    │                 │
│  │ Agent           │    │ Agent           │                 │
│  └─────────────────┘    └─────────────────┘                 │
│           │                       │                         │
│           │                       │                         │
│           v                       v                         │
│  ┌─────────────────┐    ┌─────────────────┐                 │
│  │ Requester RX    │<───│ Responder TX    │                 │
│  │ Agent           │    │ (Response Gen)  │                 │
│  └─────────────────┘    └─────────────────┘                 │
│           │                                                 │
│           v                                                 │
│  ┌─────────────────┐                                       │
│  │ Scoreboard &    │                                       │
│  │ Coverage Model  │                                       │
│  └─────────────────┘                                       │
└─────────────────────────────────────────────────────────────┘
```

## 支持的RDMA操作

| 操作类型 | 描述 | 状态 |
|---------|------|------|
| SEND | 发送操作 | ✅ 已实现 |
| RDMA WRITE | 远程内存写入 | ✅ 已实现 |
| RDMA READ | 远程内存读取 | ✅ 已实现 |
| ATOMIC | 原子操作(CmpSwap/FetchAdd) | ✅ 已实现 |

## 目录结构

```
rdma_vip/
├── docs/
│   └── rdma_vip.pdf          # 设计文档
├── sv/
│   ├── agents/               # Agent实现
│   │   ├── rdma_requester_rx_agent.sv
│   │   ├── rdma_requester_tx_agent.sv
│   │   └── rdma_responder_rx_agent.sv
│   ├── common/               # 通用功能模型
│   │   ├── rdma_defines.sv   # 全局定义
│   │   ├── rdma_psn_manager.sv
│   │   ├── rdma_mr_lookup.sv
│   │   ├── rdma_dma_write_engine.sv
│   │   ├── rdma_cqe_generator.sv
│   │   ├── rdma_scoreboard.sv
│   │   └── rdma_pkg.sv       # 包文件
│   ├── coverage/             # 覆盖率模型
│   │   └── rdma_cov_model.sv
│   ├── env/                  # 环境配置
│   │   ├── rdma_vip_env.sv
│   │   └── rdma_vip_cfg.sv
│   ├── sequences/            # 测试序列
│   │   ├── rdma_base_sequence.sv
│   │   ├── rdma_write_sequence.sv
│   │   ├── rdma_read_sequence.sv
│   │   ├── rdma_init_qp_sequence.sv
│   │   └── rdma_virtual_sequence.sv
│   ├── tests/                # 测试用例
│   │   ├── rdma_base_test.sv
│   │   ├── rdma_write_test.sv
│   │   ├── rdma_read_test.sv
│   │   ├── rdma_concurrent_test.sv
│   │   └── rdma_error_test.sv
│   └── transactions/         # 事务类
│       ├── rdma_transaction.sv
│       ├── rdma_packet.sv
│       ├── rdma_qp_context.sv
│       ├── rdma_cqe.sv
│       ├── rdma_reth.sv
│       ├── rdma_aeth.sv
│       └── rdma_atomic_eth.sv
└── README.md
```

## 核心组件说明

### 1. PSN Manager (`rdma_psn_manager`)

包序列号管理器，负责：
- PSN初始化和跟踪
- 乱序检测
- 重复包检测
- 重传管理（Go-back-N）
- PSN环绕处理

### 2. MR Lookup (`rdma_mr_lookup`)

内存区域查找和验证：
- R_Key/L_Key验证
- 地址范围检查
- 权限验证（local_write, remote_write, remote_read）
- 虚拟地址到物理地址转换

### 3. DMA Write Engine (`rdma_dma_write_engine`)

DMA写入引擎：
- TLM级DMA事务生成
- Scatter-Gather列表支持
- AXI4接口适配
- 可配置延迟模型

### 4. CQE Generator (`rdma_cqe_generator`)

完成队列条目生成器：
- CQE生成和管理
- wr_id跟踪
- 错误状态映射
- 每个QP独立的完成队列

### 5. Scoreboard (`rdma_scoreboard`)

验证记分板：
- 端到端事务检查
- CQE验证
- 数据完整性检查
- 统计报告

### 6. Coverage Model (`rdma_cov_model`)

功能覆盖率模型：
- 操作类型覆盖率
- PSN序列覆盖率
- 错误场景覆盖率
- 数据长度覆盖率

## 使用指南

### 基本测试示例

```systemverilog
// 创建环境
rdma_vip_env env;
env = rdma_vip_env::type_id::create("env", this);

// 配置参数
rdma_vip_cfg cfg = new();
cfg.enable_psn_check = 1;
cfg.enable_mem_protection = 1;
cfg.retry_mode = RETRY_GO_BACK_N;
cfg.default_pmtu = 1024;
uvm_config_db#(rdma_vip_cfg)::set(this, "*", "cfg", cfg);

// 启动测试
phase.raise_objection(this);
virtual_sequence vseq = new();
vseq.start(null);
phase.drop_objection(this);
```

### 支持的测试场景

1. **基本写入测试** (`rdma_write_test`): 测试RDMA WRITE操作
2. **读取测试** (`rdma_read_test`): 测试RDMA READ操作
3. **并发测试** (`rdma_concurrent_test`): 多操作并发执行
4. **错误测试** (`rdma_error_test`): 错误注入和恢复测试

## 配置参数

| 参数 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| is_active | bit | 1 | Agent模式(1=主动,0=被动) |
| enable_psn_check | bit | 1 | 启用PSN顺序检查 |
| enable_mem_protection | bit | 1 | 启用内存保护 |
| error_injection_enable | bit | 0 | 启用错误注入 |
| cov_enable | bit | 1 | 启用覆盖率收集 |
| retry_mode | enum | GO_BACK_N | 重传模式 |
| default_pmtu | int | 1024 | 默认路径MTU |

## QP状态机

```
┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐
│  RESET  │───>│  INIT   │───>│   RTR   │───>│   RTS   │
│  (RST)  │    │ (INIT)  │    │  (RTR)  │    │  (RTS)  │
└─────────┘    └─────────┘    └─────────┘    └────┬────┘
      ▲                                            │
      │                                            │
      └────────────────────────────────────────────┘
                  (错误恢复路径: RST→INIT→RTR→RTS)
```

## RDMA操作类型

### SEND操作
- 请求端发送数据到响应端
- 响应端接收后生成ACK
- 支持立即数

### RDMA WRITE
- 直接写入远程内存
- 需要有效的R_Key和虚拟地址
- 可携带立即数

### RDMA READ
- 从远程内存读取数据
- 返回Read Response包
- 数据通过DMA写入本地内存

### ATOMIC操作
- Compare-and-Swap: 比较并交换
- Fetch-and-Add: 获取并增加
- 8字节原子操作

## 错误处理

### 错误类型
1. **本地错误**: 内存访问错误、长度错误
2. **远程错误**: R_Key错误、权限错误
3. **传输错误**: 超时、丢包

### 错误恢复
- Go-back-N重传机制
- PSN状态跟踪
- 重试次数限制
- QP状态机错误恢复

## 技术规范

### 基于的规范
- InfiniBand Architecture Specification
- RDMA over Converged Ethernet (RoCE)
- iWARP (RDMA over TCP)

### 支持的数据结构
- Base Transport Header (BTH)
- RDMA Extended Transport Header (RETH)
- Atomic Extended Transport Header (AtomicETH)
- ACK Extended Transport Header (AETH)

## 许可证

本项目用于IC设计验证和教育目的。

## 作者

- OpenClaw Agent
- Based on RDMA VIP Design Document

## 更新历史

- 2025-04-14: 初始版本，完成核心功能实现
  - PSN Manager
  - MR Lookup
  - DMA Write Engine
  - CQE Generator
  - Scoreboard
  - Coverage Model
  - Test Sequences
