#include "cbus_mailbox_regs.h"

_Static_assert(CBUS_ABI_VERSION == UINT32_C(1), "ABI version");
_Static_assert(CBUS_INTR_BASE == UINT32_C(0x10002000), "interrupt base");
_Static_assert(CBUS_MBX_BASE == UINT32_C(0x10003000), "mailbox base");
_Static_assert(CBUS_MBX_FIFO_DEPTH == UINT32_C(8), "FIFO depth");
_Static_assert(CBUS_MBX_ENTRY_BITS == UINT32_C(32), "entry width");
_Static_assert(CBUS_MBX_H2C_HOST_PUSH_ADDR == UINT32_C(0x10003018),
               "H2C push address");
_Static_assert(CBUS_MBX_C2H_HOST_POP_ADDR == UINT32_C(0x1000303c),
               "C2H pop address");
_Static_assert(CBUS_EVENT_H2C_DOORBELL_MASK == UINT32_C(1),
               "H2C event mask");
_Static_assert(CBUS_EVENT_C2H_DOORBELL_MASK == UINT32_C(2),
               "C2H event mask");
_Static_assert(CBUS_INTR_CPU_PENDING_VALID_SOURCES_MASK == UINT32_C(0x00ff037d),
               "CPU valid source mask");
_Static_assert(CBUS_INTR_HOST_PENDING_VALID_SOURCES_MASK == UINT32_C(2),
               "host valid source mask");
_Static_assert(CBUS_ALIAS_HOST_DIAG_ACK_OFFSET == UINT32_C(0x1e),
               "last C-bus alias");

int main(void)
{
    return 0;
}
