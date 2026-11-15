/*
 * Copyright (c) 2026 Musicalista. All rights reserved.
 * Freestanding integer and boolean types for Darwin/XNU kernel build.
 */

#ifndef _J320M_TYPES_H_
#define _J320M_TYPES_H_

typedef signed char        int8_t;
typedef short              int16_t;
typedef int                int32_t;
typedef long long          int64_t;

typedef unsigned char      uint8_t;
typedef unsigned short     uint16_t;
typedef unsigned int       uint32_t;
typedef unsigned long long uint64_t;

typedef unsigned int       size_t;
typedef int                bool;
#define true               1
#define false              0

#define NULL               ((void *)0)

#endif /* _J320M_TYPES_H_ */
