#include "tb_base.h"
#include <cstdlib>
#include <ctime>

namespace tb_util {
    // Initialize random seed (call once at program start)
    void init_random() {
        srand(time(nullptr));
    }
}
