rem           MakeAsmlib.bat                   2008-06-02 Agner Fog

rem  Make function library from assembly source with multiple
rem  versions for different operating systems using objconv.


rem  Set path to assembler and objconv:
rem  You need to modify this path to fit your installation
set path=C:\Program Files (x86)\Microsoft Visual Studio 10.0\VC\bin;C:\Program Files (x86)\Microsoft Visual Studio 10.0\Common7\IDE;C:\Program Files (x86)\Microsoft Visual Studio 10.0\VC\bin\x86_amd64;C:\Program Files\Microsoft SDKs\Windows\v7.1\Bin\x64;%path%

rem  Make everything according to makefile asmlib.make
nmake /Fasmlib.make

rem wzzip asmlibbak.zip asmlib.zip asmlib-instructions.doc *.cpp

pause