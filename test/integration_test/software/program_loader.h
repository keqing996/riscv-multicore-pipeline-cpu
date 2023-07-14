#pragma once

#include <vector>
#include <cstdint>
#include <fstream>
#include <stdexcept>
#include <cstring>

class ProgramLoader {
public:
    static std::vector<uint32_t> load_binary(const std::string& bin_path) {
        std::ifstream file(bin_path, std::ios::binary | std::ios::ate);
        if (!file.is_open()) {
            throw std::runtime_error("Failed to open binary file: " + bin_path);
        }
        
        std::streamsize size = file.tellg();
        file.seekg(0, std::ios::beg);
        
        std::vector<uint8_t> buffer(size);
        if (!file.read(reinterpret_cast<char*>(buffer.data()), size)) {
            throw std::runtime_error("Failed to read binary file: " + bin_path);
        }
        
        // Pad to 4-byte boundary
        while (buffer.size() % 4 != 0) {
            buffer.push_back(0);
        }
        
        // Convert to uint32_t array (little-endian)
        std::vector<uint32_t> program;
        program.reserve(buffer.size() / 4);
        
        for (size_t i = 0; i < buffer.size(); i += 4) {
            uint32_t word = 
                static_cast<uint32_t>(buffer[i]) |
                (static_cast<uint32_t>(buffer[i + 1]) << 8) |
                (static_cast<uint32_t>(buffer[i + 2]) << 16) |
                (static_cast<uint32_t>(buffer[i + 3]) << 24);
            program.push_back(word);
        }
        
        return program;
    }
};
