#                       ASMLIB.MAKE                        2008-07-17 Agner Fog

# Makefile for ASMLIB function library. See asmlib.txt for a description

# The following tools are required for building this library package:
# Microsoft nmake or other make utility
# Microsoft assembler ml.exe and ml64.exe
# Object file converter objconv.exe (www.agner.org/optimize)
# Winzip command line version (www.winzip.com) or other zip utility

libpath64="C:\apps\dev\Microsoft Visual Studio 2008\VC\lib\amd64"

# Main target is zip file
# Using wzzip, which is the command line version of Winzip (www.winzip.com)
asmlib.zip: alibcof32.lib alibcof32o.lib alibcof64.lib alibcof64o.lib \
  alibomf32.lib alibomf32o.lib \
  alibelf32.a alibelf32o.a alibelf32p.a alibelf32op.a \
  alibelf64.a alibelf64o.a \
  alibmac32.a alibmac32o.a alibmac32p.a alibmac32op.a \
  alibmac64.a alibmac64o.a \
  alibd32.dll alibd32.lib alibd64.dll alibd64.lib \
  asmlib.h asmlibran.h asmlib-instructions.pdf asmlibSrc.zip
  wzzip $@ $?

# Make zip archive of source code
asmlibSrc.zip: makeasmlib.bat asmlib.make \
  instrset32.asm instrset64.asm procname32.asm procname64.asm \
  rdtsc32.asm rdtsc64.asm round32.asm round64.asm serialize32.asm serialize64.asm \
  mersenne32.asm mersenne64.asm mother32.asm mother64.asm randomah.asi \
  alibd32.asm alibd32.def alibd32.exp alibd64.asm alibd64.def alibd64.exp \
  memcpy32.asm memmove32.asm memcpy64.asm memmove64.asm \
  memset32.asm memset64.asm strlen32.asm strlen64.asm \
  strcpy32.asm strcpy64.asm strcat32.asm strcat64.asm \
  testalib.cpp
  wzzip $@ $?

# Build each library version:

# 32 bit COFF library
alibcof32.lib: instrset32.obj32 procname32.obj32 rdtsc32.obj32 round32.obj32 \
  serialize32.obj32 mersenne32.obj32 mother32.obj32 \
  memcpy32.obj32 memmove32.obj32 memset32.obj32 \
  strlen32.obj32 strcpy32.obj32 strcat32.obj32
  objconv -fcof32 -wex -lib $@ $?

# 32 bit ELF library, position independent
alibelf32p.a: instrset32.o32pic procname32.o32pic rdtsc32.o32pic round32.o32pic \
  serialize32.o32pic mersenne32.o32pic mother32.o32pic \
  memcpy32.o32pic memmove32.o32pic memset32.o32pic \
  strlen32.o32pic strcpy32.o32pic strcat32.o32pic
  objconv -felf32 -nu -wex -lib $@ $?

# 64 bit COFF library Windows
alibcof64.lib: instrset64.obj64 procname64.obj64 rdtsc64.obj64 round64.obj64 \
  serialize64.obj64 mersenne64.obj64 mother64.obj64 \
  memcpy64.obj64 memmove64.obj64 memset64.obj64 \
  strlen64.obj64 strcpy64.obj64 strcat64.obj64
  objconv -fcof64 -wex -lib $@ $?

# 64 bit ELF library Unix
alibelf64.a: instrset64.o64 procname64.o64 rdtsc64.o64 round64.o64 \
  serialize64.o64 mersenne64.o64 mother64.o64 \
  memcpy64.o64 memmove64.o64 memset64.o64 \
  strlen64.o64 strcpy64.o64 strcat64.o64
  objconv -felf64 -nu -wex -wd1029 -lib $@ $?

# Convert these libraries to other versions:

# 32 bit COFF library, override version
alibcof32o.lib: alibcof32.lib
  objconv -fcof32 -np:?OVR_:_ -wex $** $@

# 32 bit OMF library
alibomf32.lib: alibcof32.lib
  objconv -fomf32 -nu -wex $** $@

# 32 bit OMF library, override version
alibomf32o.lib: alibcof32o.lib
  objconv -fomf32 -nu -wex $** $@

# 32 bit ELF library, position dependent
alibelf32.a: alibcof32.lib
  objconv -felf32 -nu -wex alibcof32.lib $@

# 32 bit ELF library, override, position dependent
alibelf32o.a: alibelf32.a
  objconv -felf32 -np:?OVR_: -wex $** $@

# 32 bit ELF library, override, position independent
alibelf32op.a: alibelf32p.a
  objconv -felf32 -np:?OVR_: -wex $** $@

# 32 bit Mach-O library, position dependent
alibmac32.a: alibelf32.a
  objconv -fmac32 -nu -wex -wd1050 $** $@

# 32 bit Mach-O library, position independent
alibmac32p.a: alibelf32p.a
  objconv -fmac32 -nu -wex $** $@

# 32 bit Mach-O library, override
alibmac32o.a: alibelf32o.a
  objconv -fmac32 -nu -wex -wd1050 $** $@

# 32 bit Mach-O library, override, position independent
alibmac32op.a: alibelf32op.a
  objconv -fmac32 -nu -wex $** $@

# Make 64 bit COFF library, override
alibcof64o.lib: alibcof64.lib
  objconv -fcof64 -np:?OVR_: -wex $** $@

# 64 bit ELF library, override
alibelf64o.a: alibelf64.a
  objconv -felf64 -np:?OVR_: -wex -wd1029 $** $@

# 64 bit Mach-O library
alibmac64.a: alibelf64.a
  objconv -fmac64 -nu -wex $** $@

# 64 bit Mach-O library, override
alibmac64o.a: alibelf64o.a
  objconv -fmac64 -nu -wex $** $@

# Convert 32 bit COFF library to DLL
alibd32.dll: alibcof32.lib alibd32.obj32 alibd32.def
  link /DLL /DEF:alibd32.def /SUBSYSTEM:WINDOWS alibd32.obj32 alibcof32.lib

# Convert 64 bit COFF library to DLL
alibd64.dll: alibcof64.lib alibd64.def alibd64.obj64
  link /DLL /DEF:alibd64.def /SUBSYSTEM:WINDOWS /LIBPATH:$(libpath64) alibd64.obj64 alibcof64.lib libcmt.lib

# Generic rules for assembling

# Generic rule for assembling 32-bit code
.asm.obj32:
  ML /c /Cx /W3 /coff /Fl /Fo$*.obj32 $<

# Generic rule for assembling 32-bit code, position-independent and converting to elf
.asm.o32pic:
  ML /c /Cx /W3 /coff /DPOSITIONINDEPENDENT /Fo$*.obj32pic $<
  objconv -felf32 -nu $*.obj32pic $@

# Generic rule for assembling 64-bit code for Windows
.asm.obj64:
  ML64 /c /Cx /W3 /DWINDOWS /Fl /Fo$*.obj64 $<

# Generic rule for assembling 64-bit code for Linux, BSD, Mac
.asm.o64:
  ML64 /c /Cx /W3 /DUNIX /Fl /Fo$*.o64 $<
