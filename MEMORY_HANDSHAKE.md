# Core、BRAM 与 Cache 握手说明

本文解释 Core 与指令/数据存储器之间的请求、响应和流水线停顿。当前 `sim_imem`、`sim_dmem` 模拟同步一拍 BRAM；未来 I-Cache、D-Cache 使用同一组接口。

## 1. Ready/Valid 的基本规则

每个通道都由发送方提供 `valid`，接收方提供 `ready`：

```text
fire = valid && ready
```

只有时钟上升沿出现 `fire`，一次传输才完成。

- `valid=1`：发送方提供的内容有效。
- `ready=1`：接收方当前有空间接收。
- `valid=1, ready=0`：尚未传输，发送方必须保持 `valid` 和数据不变。
- `ready=1, valid=0`：接收方空闲，但当前没有数据。

`ready` 不表示“数据已经返回”。例如 `imem_req_ready=1` 只表示存储器接受 PC 请求，真正的指令由之后的 `imem_rsp_valid` 表示。

## 2. 请求与响应是两个独立通道

```text
Core                              Memory/Cache
 req_valid + req_addr  --------->
            req_ready  <---------

            rsp_valid  <---------
 rsp_ready             --------->
            rsp_data   <---------
```

请求握手和响应握手发生在不同周期。当前仿真 BRAM 在请求握手后的下一周期产生响应，并使用一个响应寄存器保存数据：

```systemverilog
req_ready = !rsp_valid || rsp_ready;
```

含义是：响应槽为空时可以接受请求；旧响应将在本周期被接收时，也可以同拍接受下一笔请求。

## 3. IF 与 IMEM

`if_stage` 保存三类状态：

- `pc_q`：下一次请求的 PC。
- `request_q`：已经被 IMEM 接受、正在等待响应的 PC 和预测元数据。
- `buffer_q`：响应已经回来，但 D1 暂时不能接收的指令。

正常命中时序：

```text
周期 N：   imem_req_valid && imem_req_ready，保存 request_q
周期 N+1：imem_rsp_valid && imem_rsp_ready，指令直通 D1 或进入 buffer_q
```

`out_ready` 是 D1 对 IF 输出的接收能力，`imem_rsp_ready` 是 IF 对 IMEM 响应的接收能力，两者不是同一个信号。当 D1 暂停而 `buffer_q` 为空时，IF 仍可接收一次响应并保存；buffer 已满时则拉低 `imem_rsp_ready`。IF 还可以保留一笔未完成请求，因此暂停期间最多保存“一条 buffer 指令 + 一条 Cache 尚未交付的响应”。

redirect 后，buffer 中的旧路径指令立即失效。已经接受但尚未返回的请求无法凭空取消，因此 `request_killed_q` 会记住它；迟到响应仍进行握手，但不会输出到 D1。未来 I-Cache miss 只会延长等待时间，不改变 IF 的处理原则。

## 4. MEM、WB 与 DMEM

MEM 负责地址、store 字节通道和请求握手。load 请求被接受后，PC、rd、地址低位、访问宽度等元数据进入 `MEM/WB`；数据在下一周期由 WB 接收。

```text
周期 N：   load 位于 MEM，dmem_req fire
周期 N+1：load 位于 WB，dmem_rsp fire，完成扩展、写回和 WB 前递
```

因此 Cache hit 不产生全局停顿。紧随 load 的相关指令在 D2 停一拍，随后在 EX 使用 WB 前递：

```text
        N       N+1       N+2
load    EX      MEM       WB
use     D2      bubble    EX（WB forward）
```

两种等待需要区别：

- `mem_request_stall`：请求还没有被 DMEM/Cache 接受，EX/MEM 必须保持请求内容。
- `wb_wait`：load 请求已经被接受，但响应尚未回来。MEM/WB 保存 load 元数据，整条顺序流水线等待。

未来 D-Cache 命中时，响应恰好在 load 到达 WB 时出现；miss 时，Cache 可以先接受请求，再执行 refill，此时只通过 `wb_wait` 延长等待。对于没有重排序缓冲区的顺序核，miss 时停止退休是必要行为。

当前 store 在请求被接受后即可进入 WB，不单独等待返回数据。这要求 D-Cache 在拉高 `req_ready` 后负责保存并最终完成该写请求，并在处理阻塞式 miss 时拉低后续请求的 `req_ready`。若未来需要总线错误上报或更严格的精确异常，应再增加 store completion/ack 或正式的 store buffer。

## 5. FPGA Cache 的实际结构

FPGA 可以综合真实 Cache：Data array 通常放在 BRAM，Tag、valid、dirty 可放在 BRAM 或 LUTRAM，控制器负责比较、替换和 refill。

```text
请求 → 读取 Tag/Data
          ├─ hit  → 下一拍响应
          └─ miss → 选择 victim → 必要时写回 → 下级存储器读取 → 填充 → 响应
```

Cache 容量确实受 BRAM 数量限制，但“读取不到”不是地址越界，而是对应 Cache line 的 Tag 不匹配。miss 必须有下一级存储器，例如 DDR、AXI RAM 或更大的片上存储器。若程序和数据本身就在一拍 BRAM 中，增加 Cache 通常不会提升性能，但仍可用于验证 Cache RTL。

当前接口按顺序处理响应，适合第一版阻塞式 Cache。若以后允许多个未完成 miss，则必须增加 transaction ID、MSHR，并重新设计冒险和顺序提交。

## 6. 检查波形时关注什么

1. 当 `req_valid && !req_ready` 时，请求地址必须保持不变。
2. 当 `rsp_valid && !rsp_ready` 时，返回数据必须保持不变。
3. IF redirect 后，旧响应可以 fire，但 `out_packet.valid` 必须为 0。
4. 普通 load hit 后的无关指令应连续退休。
5. load-use 应恰好出现一个 bubble。
6. miss 时应保持 MEM/WB 中的 load，而不是重复发送同一个请求。
