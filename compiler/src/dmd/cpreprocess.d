/**
 * Run the C preprocessor on a C source file.
 *
 * Specification: C11
 *
 * Copyright:   Copyright (C) 2022-2024 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/cpreprocess.d, _cpreprocess.d)
 * Documentation:  https://dlang.org/phobos/dmd_cpreprocess.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/cpreprocess.d
 */

module dmd.cpreprocess;

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

import dmd.errors;
import dmd.globals;
import dmd.link;
import dmd.location;
import dmd.target;
import dmd.vsoptions;

import dmd.common.outbuffer;

import dmd.root.array;
import dmd.root.filename;
import dmd.root.rmem;
import dmd.root.string;

// Use default for other versions
version (Posix)   version = runPreprocessor;
version (Windows) version = runPreprocessor;

/***************************************
 * Preprocess C file.
 * Params:
 *      csrcfile = C file to be preprocessed, with .c or .h extension
 *      importc_h = the path/file of importc.h
 *      loc = The source location where preprocess is requested from
 *      ifile = set to true if an output file was written
 *      defines = buffer to append any `#define` and `#undef` lines encountered to
 * Result:
 *      filename of preprocessed output
 */
extern (C++)
FileName preprocess(FileName csrcfile, const(char)* importc_h, ref const Loc loc, out bool ifile, ref OutBuffer defines)
{
    //printf("preprocess %s\n", csrcfile.toChars());
    version (runPreprocessor)
    {
        /*
           To get sppn.exe: http://ftp.digitalmars.com/sppn.zip
           To get the dmc C headers, dmc will need to be installed:
           http://ftp.digitalmars.com/Digital_Mars_C++/Patch/dm857c.zip
         */
        const(char)* tmpname = tmpnam(null);        // generate unique temporary file name for preprocessed output
        assert(tmpname);
        const(char)[] ifilename = tmpname[0 .. strlen(tmpname) + 1];
        ifilename = xarraydup(ifilename);
        const command = global.params.cpp ? toDString(global.params.cpp) : cppCommand();
        auto status = runPreprocessor(command, csrcfile.toString(), importc_h, global.params.cppswitches, ifilename, defines);
        if (status)
        {
            error(loc, "C preprocess command %.*s failed for file %s, exit status %d\n",
                cast(int)command.length, command.ptr, csrcfile.toChars(), status);
            fatal();
        }
        //printf("C preprocess succeeded %s\n", ifilename.ptr);
        ifile = true;
        return FileName(ifilename);
    }
    else
        return csrcfile;        // no-op
}


/***************************************
 * Find importc.h by looking along the path
 * Params:
 *      path = import path
 * Returns:
 *      importc.h file name, null if not found
 */
const(char)* findImportcH(const(char)*[] path)
{
    /* Look for "importc.h" by searching along import path.
     * It should be in the same place as "object.d"
     */
    foreach (entry; path)
    {
        auto f = FileName.combine(entry, "importc.h");
        if (FileName.exists(f) == 1)
        {
            return FileName.toAbsolute(f);
        }
        FileName.free(f);
    }
    return null;
}

/******************************************
 * Pick the C preprocessor program to run.
 */
private const(char)[] cppCommand()
{
    if (auto p = getenv("CPPCMD"))
        return toDString(p);

    version (Windows)
    {
        if (target.objectFormat() == Target.ObjectFormat.coff)
        {
            VSOptions vsopt;
            vsopt.initialize();
            auto path = vsopt.compilerPath(target.isX86_64);
            return toDString(path);
        }
        if (target.objectFormat() == Target.ObjectFormat.omf)
        {
            return "sppn.exe";
        }
        // Perhaps we are cross-compiling.
        return "cpp";
    }
    else version (OpenBSD)
    {
        // On OpenBSD, we need to use the actual binary /usr/libexec/cpp
        // rather than the shell script wrapper /usr/bin/cpp ...
        // Turns out the shell script doesn't really understand -o
        return "/usr/libexec/cpp";
    }
    else version (OSX)
    {
        return "clang";
    }
    else
    {
        return "cpp";
    }
}
