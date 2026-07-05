#include "tb_base.h"
#include <algorithm>
#include <cerrno>
#include <cstdlib>
#include <limits>
#include <random>
#include <string>

namespace tb_util {
    namespace {
        constexpr uint32_t kDefaultSeed = 0xC0DE2026u;

        uint32_t parse_seed_from_env() {
            const char* seed_env = std::getenv("TEST_SEED");
            if (seed_env == nullptr || seed_env[0] == '\0') {
                return kDefaultSeed;
            }

            errno = 0;
            char* end = nullptr;
            unsigned long long parsed = std::strtoull(seed_env, &end, 0);
            if (errno != 0 || end == seed_env || *end != '\0' ||
                parsed > std::numeric_limits<uint32_t>::max()) {
                std::cerr << "Invalid TEST_SEED='" << seed_env
                          << "', using default TEST_SEED=0x"
                          << std::hex << kDefaultSeed << std::dec << std::endl;
                return kDefaultSeed;
            }

            return static_cast<uint32_t>(parsed);
        }

        uint32_t& seed_storage() {
            static uint32_t seed = parse_seed_from_env();
            return seed;
        }

        std::mt19937& rng_storage() {
            static std::mt19937 rng(seed_storage());
            return rng;
        }

        void print_seed_once() {
            static bool printed = false;
            if (!printed) {
                std::cout << "TEST_SEED=0x" << std::hex << seed_storage()
                          << std::dec << std::endl;
                printed = true;
            }
        }
    }

    uint32_t random_seed() {
        print_seed_once();
        return seed_storage();
    }

    void init_random() {
        print_seed_once();
        rng_storage().seed(seed_storage());
    }

    uint32_t random_uint32() {
        print_seed_once();
        return rng_storage()();
    }

    uint32_t random_range(uint32_t min, uint32_t max) {
        print_seed_once();
        if (min > max) {
            std::swap(min, max);
        }
        std::uniform_int_distribution<uint32_t> dist(min, max);
        return dist(rng_storage());
    }
}
