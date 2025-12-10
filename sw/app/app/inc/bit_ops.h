#ifndef BIT_OPS_H
#define BIT_OPS_H

#include <stdint.h>
#include <stdbool.h>

// 读取原始32位数据
// uint32_t neorv32_cpu_load_unsigned_word(uint32_t addr);

// // 写入原始32位数据
// void neorv32_cpu_store_unsigned_word(uint32_t addr, uint32_t wdata);

// 读取单个bit
bool neorv32_cpu_load_bit(uint32_t addr, uint8_t bit_position);

// 写入单个bit
void neorv32_cpu_store_bit(uint32_t addr, uint8_t bit_position, bool value);

// 读取多个连续bit
uint32_t neorv32_cpu_load_bits(uint32_t addr, uint8_t start_bit, uint8_t num_bits);

// 写入多个连续bit
void neorv32_cpu_store_bits(uint32_t addr, uint8_t start_bit, uint8_t num_bits, uint32_t value);

// 使用掩码读取bit
uint32_t neorv32_cpu_load_masked_bits(uint32_t addr, uint32_t bit_mask);

// 使用掩码写入bit
void neorv32_cpu_store_masked_bits(uint32_t addr, uint32_t bit_mask, uint32_t value);

// 常用的预定义bit操作函数示例
bool neorv32_cpu_load_status_bit(uint32_t addr);
void neorv32_cpu_store_status_bit(uint32_t addr, bool value);
uint32_t neorv32_cpu_load_config_bits(uint32_t addr);
void neorv32_cpu_store_config_bits(uint32_t addr, uint32_t value);

#endif // BIT_OPS_H