#include "../../inc/system.h"

// 读取原始32位数据
// inline uint32_t __attribute__((always_inline)) 
// neorv32_cpu_load_unsigned_word(uint32_t addr) {
//     uint32_t reg_addr = addr;
//     uint32_t reg_data;
//     asm volatile ("lw %[da], 0(%[ad])" : [da] "=r" (reg_data) : [ad] "r" (reg_addr));
//     return reg_data;
// }

// // 写入原始32位数据
// inline void __attribute__((always_inline)) 
// neorv32_cpu_store_unsigned_word(uint32_t addr, uint32_t wdata) {
//     uint32_t reg_addr = addr;
//     uint32_t reg_data = wdata;
//     asm volatile ("sw %[da], 0(%[ad])" : : [da] "r" (reg_data), [ad] "r" (reg_addr));
// }

// 读取单个bit
bool neorv32_cpu_load_bit(uint32_t addr, uint8_t bit_position) {
    if (bit_position > 31) return false;
    uint32_t data = neorv32_cpu_load_unsigned_word(addr);
    return (data >> bit_position) & 0x1;
}

// 写入单个bit
void neorv32_cpu_store_bit(uint32_t addr, uint8_t bit_position, bool value) {
    if (bit_position > 31) return;
    
    uint32_t data = neorv32_cpu_load_unsigned_word(addr);
    if (value) {
        data |= (1 << bit_position);  // 设置bit
    } else {
        data &= ~(1 << bit_position); // 清除bit
    }
    neorv32_cpu_store_unsigned_word(addr, data);
}

// 读取多个连续bit
uint32_t neorv32_cpu_load_bits(uint32_t addr, uint8_t start_bit, uint8_t num_bits) {
    if (start_bit > 31 || num_bits > 32 || (start_bit + num_bits) > 32) {
        return 0;
    }
    
     // 添加内存屏障和volatile确保正确读取
     asm volatile ("" ::: "memory");
     volatile uint32_t data = neorv32_cpu_load_unsigned_word(addr);
     asm volatile ("" ::: "memory");
     
     // 使用无符号常量避免符号扩展问题
     uint32_t mask = (1UL << num_bits) - 1UL;
     return (data >> start_bit) & mask;
}

// 写入多个连续bit
void neorv32_cpu_store_bits(uint32_t addr, uint8_t start_bit, uint8_t num_bits, uint32_t value) {
    if (start_bit > 31 || num_bits > 32 || (start_bit + num_bits) > 32) {
        return;
    }
    
    uint32_t data = neorv32_cpu_load_unsigned_word(addr);
    uint32_t mask = ((1 << num_bits) - 1) << start_bit;
    
    // 清除目标位，然后设置新值
    data &= ~mask;
    data |= (value << start_bit) & mask;
    
    neorv32_cpu_store_unsigned_word(addr, data);
}

// 使用掩码读取bit
uint32_t neorv32_cpu_load_masked_bits(uint32_t addr, uint32_t bit_mask) {
    uint32_t data = neorv32_cpu_load_unsigned_word(addr);
    return data & bit_mask;
}

// 使用掩码写入bit
void neorv32_cpu_store_masked_bits(uint32_t addr, uint32_t bit_mask, uint32_t value) {
    uint32_t data = neorv32_cpu_load_unsigned_word(addr);
    
    // 清除掩码位，然后设置新值
    data &= ~bit_mask;
    data |= value & bit_mask;
    
    neorv32_cpu_store_unsigned_word(addr, data);
}

// 常用的预定义bit操作函数示例
bool neorv32_cpu_load_status_bit(uint32_t addr) {
    return neorv32_cpu_load_bit(addr, 7); // 假设状态位在第7位
}

void neorv32_cpu_store_status_bit(uint32_t addr, bool value) {
    neorv32_cpu_store_bit(addr, 7, value);
}

uint32_t neorv32_cpu_load_config_bits(uint32_t addr) {
    return neorv32_cpu_load_bits(addr, 3, 4); // 假设配置位在第3-6位
}

void neorv32_cpu_store_config_bits(uint32_t addr, uint32_t value) {
    neorv32_cpu_store_bits(addr, 3, 4, value);
}