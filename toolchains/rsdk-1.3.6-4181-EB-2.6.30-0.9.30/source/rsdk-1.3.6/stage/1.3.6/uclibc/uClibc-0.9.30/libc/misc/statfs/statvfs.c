/* Copyright (C) 1998, 2000 Free Software Foundation, Inc.
   This file is part of the GNU C Library.
   Contributed by Ulrich Drepper <drepper@cygnus.com>, 1998.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
   02111-1307 USA.  */

#include <features.h>
#include <errno.h>
#include <mntent.h>
#include <paths.h>
#include <string.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/statfs.h>
#include <sys/statvfs.h>

/* Experimentally off - libc_hidden_proto(memset) */
/* Experimentally off - libc_hidden_proto(strcmp) */
/* Experimentally off - libc_hidden_proto(strsep) */
libc_hidden_proto(setmntent)
libc_hidden_proto(getmntent_r)
libc_hidden_proto(endmntent)

extern __typeof(statfs) __libc_statfs;
libc_hidden_proto(__libc_statfs)
libc_hidden_proto(stat)

libc_hidden_proto(statvfs)
int statvfs (const char *file, struct statvfs *buf)
{
    struct statfs fsbuf;
    struct stat st;

    /* Get as much information as possible from the system.  */
    if (__libc_statfs (file, &fsbuf) < 0)
	return -1;

#define STAT(st) stat (file, st)
#include "internal_statvfs.c"

    /* We signal success if the statfs call succeeded.  */
    return 0;
}
libc_hidden_def(statvfs)