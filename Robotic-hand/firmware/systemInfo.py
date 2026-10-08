import machine
import os
import gc
import sys
import micropython

def getUid():
    # 获取唯一ID (通常是MAC地址的字节形式)
    device_id = machine.unique_id()
    print("Unique ID (bytes):", device_id)

    # 转换为更易读的十六进制字符串（推荐用于服务端识别）
    hex_id = ''.join(['%02x' % b for b in device_id])
    print("Unique ID (hex):", hex_id)
    return hex_id
    
 
def print_system_info():
    """打印ESP32-S3的系统信息"""
    
    print("\n" + "="*40)
    print("        ESP32-S3 系统信息")
    print("="*40)
    
    # 1. MicroPython版本信息
    print("\n-- MicroPython 版本 --")
    print("版本:", sys.implementation.version)
    print("编译日期:", sys.version)
    
    # 获取唯一ID (通常是MAC地址的字节形式)
    device_id = machine.unique_id()
    print("Unique ID (bytes):", device_id)

    # 转换为更易读的十六进制字符串（推荐用于服务端识别）
    hex_id = ''.join(['%02x' % b for b in device_id])
    print("Unique ID (hex):", hex_id)
    
    
    # 2. 内存信息
    print("\n-- 内存状态 --")
    gc.collect()  # 强制垃圾回收
    free_ram = gc.mem_free()
    allocated_ram = gc.mem_alloc()
    total_ram = free_ram + allocated_ram
    
    print("SRAM可用: {:.2f} KB".format(free_ram / 1024))
    print("SRAM已用: {:.2f} KB".format(allocated_ram / 1024))
    print("SRAM总计: {:.2f} KB".format(total_ram / 1024))
    
    # 检查PSRAM（如果可用）
    try:
        # 尝试分配PSRAM
        import esp
        if hasattr(esp, 'psram_size'):
            psram_size = esp.psram_size()
            if psram_size > 0:
                print("PSRAM大小: {:.2f} KB".format(psram_size / 1024))
    except:
        pass
    
    # 3. 闪存信息
    print("\n-- 闪存信息 --")
    try:
        flash_size = esp.flash_size()
        print("闪存总大小: {:.2f} MB".format(flash_size / (1024 * 1024)))
    except:
        flash_size = 0
    
    # 4. 文件系统信息
    print("\n-- 文件系统 --")
    try:
        fs_stat = os.statvfs('/')
        block_size = fs_stat[0]
        total_blocks = fs_stat[2]
        free_blocks = fs_stat[3]
        
        total_flash = (block_size * total_blocks) 
        free_flash = (block_size * free_blocks)
        used_flash = total_flash - free_flash
        
        print("文件系统总空间: {:.2f} KB".format(total_flash / 1024))
        print("文件系统已用: {:.2f} KB".format(used_flash / 1024))
        print("文件系统可用: {:.2f} KB".format(free_flash / 1024))
        print("使用率: {:.1f}%".format((used_flash / total_flash) * 100))
    except Exception as e:
        print("文件系统信息获取失败:", e)
    
    # 5. CPU信息
    print("\n-- CPU 信息 --")
    try:
        cpu_freq = machine.freq()
        print("CPU频率: {:.2f} MHz".format(cpu_freq / 1000000))
    except:
        pass
    
    # 6. 芯片ID
    print("\n-- 芯片标识 --")
    try:
        unique_id = machine.unique_id()
        print("芯片ID:", ''.join('{:02x}'.format(b) for b in unique_id))
    except:
        pass