/*
  Implementation of noDVal functions.
  Since they are inline, but sometimes the linker expects them.
*/

#include "noDVal.h"

double MKGetNoDVal(void)
{
    union {double d; int i[2];} u;
    u.i[0] = _MK_NANHI;
    u.i[1] = _MK_NANLO;
    return u.d;
}

int MKIsNoDVal(double value)
{
    union {double d; int i[2];} u;
    u.d = value;
    return (u.i[0] == _MK_NANHI); /* Don't bother to check low bits. */
}